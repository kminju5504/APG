#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <Preferences.h>

#define SERVICE_UUID        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

BLECharacteristic* pCharacteristic;
bool bleConnected = false;
Preferences preferences;

// 센서 핀
const int REED_1 = 26;
const int REED_2 = 25;
const int REED_3 = 18;
const int IR_1 = 32;
const int IR_2 = 35;
const int IR_3 = 34;

// 복용 감지 상태 머신
// 0: IDLE, 1: 약O+닫힘, 2: 약O+열림, 3: 약X+열림, 4: 복용완료
enum TakeState { STATE_IDLE=0, STATE_PILL_CLOSED=1, STATE_PILL_OPEN=2, STATE_EMPTY_OPEN=3, STATE_TAKEN=4 };

TakeState slotState[3] = {STATE_IDLE, STATE_IDLE, STATE_IDLE};
bool takenFlag[3] = {false, false, false};

int takenCount1 = 0, takenCount2 = 0, takenCount3 = 0;
unsigned long lastTakenTime1 = 0, lastTakenTime2 = 0, lastTakenTime3 = 0;
bool pendingSync = false;

String lidToText(int v) { return (v == LOW) ? "closed" : "open"; }
String pillToText(int v) { return (v == LOW) ? "present" : "empty"; }
bool hasPill(int v) { return (v == LOW); }
bool isLidClosed(int v) { return (v == LOW); }

String stateToText(TakeState s) {
  switch(s) {
    case STATE_IDLE: return "IDLE";
    case STATE_PILL_CLOSED: return "약O닫힘";
    case STATE_PILL_OPEN: return "약O열림";
    case STATE_EMPTY_OPEN: return "약X열림";
    case STATE_TAKEN: return "복용!";
    default: return "???";
  }
}

void loadSavedData() {
  preferences.begin("pillbox", false);
  takenCount1 = preferences.getInt("taken1", 0);
  takenCount2 = preferences.getInt("taken2", 0);
  takenCount3 = preferences.getInt("taken3", 0);
  lastTakenTime1 = preferences.getULong("time1", 0);
  lastTakenTime2 = preferences.getULong("time2", 0);
  lastTakenTime3 = preferences.getULong("time3", 0);
  pendingSync = preferences.getBool("pending", false);
  preferences.end();
  Serial.printf("저장된 기록: 슬롯1=%d, 슬롯2=%d, 슬롯3=%d\n", takenCount1, takenCount2, takenCount3);
}

void saveTakenRecord(int slot) {
  preferences.begin("pillbox", false);
  if (slot == 1) { takenCount1++; lastTakenTime1 = millis(); preferences.putInt("taken1", takenCount1); preferences.putULong("time1", lastTakenTime1); }
  else if (slot == 2) { takenCount2++; lastTakenTime2 = millis(); preferences.putInt("taken2", takenCount2); preferences.putULong("time2", lastTakenTime2); }
  else if (slot == 3) { takenCount3++; lastTakenTime3 = millis(); preferences.putInt("taken3", takenCount3); preferences.putULong("time3", lastTakenTime3); }
  preferences.putBool("pending", true);
  pendingSync = true;
  preferences.end();
  Serial.printf("저장: 슬롯%d 복용! (총 %d회)\n", slot, slot==1?takenCount1:(slot==2?takenCount2:takenCount3));
}

// 상태 머신: 약O닫힘 -> 약O열림 -> 약X열림 -> 약X닫힘(복용!)
void updateTakeState(int idx, bool pill, bool lidClosed) {
  TakeState prev = slotState[idx];
  TakeState next = prev;
  
  switch(prev) {
    case STATE_IDLE:
      if (pill && lidClosed) next = STATE_PILL_CLOSED;
      break;
    case STATE_PILL_CLOSED:
      if (pill && !lidClosed) next = STATE_PILL_OPEN;
      else if (!pill) next = STATE_IDLE;
      break;
    case STATE_PILL_OPEN:
      if (!pill && !lidClosed) next = STATE_EMPTY_OPEN;
      else if (pill && lidClosed) next = STATE_PILL_CLOSED;
      break;
    case STATE_EMPTY_OPEN:
      if (!pill && lidClosed) {
        next = STATE_TAKEN;
        takenFlag[idx] = true;
        Serial.printf("슬롯%d 복용 완료! (정확한 순서 감지)\n", idx+1);
      }
      else if (pill) next = STATE_PILL_OPEN;
      break;
    case STATE_TAKEN:
      if (pill && lidClosed) next = STATE_PILL_CLOSED;
      else next = STATE_IDLE;
      break;
  }
  
  if (prev != next) {
    Serial.printf("슬롯%d: %s -> %s\n", idx+1, stateToText(prev).c_str(), stateToText(next).c_str());
  }
  slotState[idx] = next;
}

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    bleConnected = true;
    Serial.println("앱 연결됨!");
  }
  void onDisconnect(BLEServer* pServer) override {
    bleConnected = false;
    Serial.println("앱 연결 끊김");
    pServer->startAdvertising();
  }
};

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n=== APG Pillbox v2.0 ===");
  Serial.println("복용 감지 순서:");
  Serial.println("1.약O+닫힘 -> 2.약O+열림 -> 3.약X+열림 -> 4.약X+닫힘(복용!)\n");
  
  loadSavedData();
  
  pinMode(REED_1, INPUT_PULLUP);
  pinMode(REED_2, INPUT_PULLUP);
  pinMode(REED_3, INPUT_PULLUP);
  pinMode(IR_1, INPUT);
  pinMode(IR_2, INPUT);
  pinMode(IR_3, INPUT);

  BLEDevice::init("APG_Pillbox");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();
  pServer->getAdvertising()->start();
  Serial.println("BLE 준비 완료!\n");
}

void loop() {
  takenFlag[0] = takenFlag[1] = takenFlag[2] = false;
  
  int r1 = digitalRead(REED_1), r2 = digitalRead(REED_2), r3 = digitalRead(REED_3);
  int ir1 = digitalRead(IR_1), ir2 = digitalRead(IR_2), ir3 = digitalRead(IR_3);

  bool pill1 = hasPill(ir1), pill2 = hasPill(ir2), pill3 = hasPill(ir3);
  bool lid1 = isLidClosed(r1), lid2 = isLidClosed(r2), lid3 = isLidClosed(r3);

  updateTakeState(0, pill1, lid1);
  updateTakeState(1, pill2, lid2);
  updateTakeState(2, pill3, lid3);

  if (takenFlag[0]) saveTakenRecord(1);
  if (takenFlag[1]) saveTakenRecord(2);
  if (takenFlag[2]) saveTakenRecord(3);

  String lidStr1 = lidToText(r1), lidStr2 = lidToText(r2), lidStr3 = lidToText(r3);
  String pillStr1 = pillToText(ir1), pillStr2 = pillToText(ir2), pillStr3 = pillToText(ir3);

  String bleMsg = "1:" + pillStr1 + "," + lidStr1 + "," + String(takenFlag[0]?1:0) + "," + String(takenCount1) + ";" +
                  "2:" + pillStr2 + "," + lidStr2 + "," + String(takenFlag[1]?1:0) + "," + String(takenCount2) + ";" +
                  "3:" + pillStr3 + "," + lidStr3 + "," + String(takenFlag[2]?1:0) + "," + String(takenCount3) + ";" +
                  "sync:" + String(pendingSync?"pending":"done");

  pCharacteristic->setValue(bleMsg.c_str());
  pCharacteristic->notify();

  static unsigned long lastPrint = 0;
  if (millis() - lastPrint > 2000) {
    Serial.println("-----------------------------------");
    Serial.printf("BLE: %s | 복용: %d/%d/%d\n", bleConnected?"연결":"대기", takenCount1, takenCount2, takenCount3);
    Serial.printf("슬롯1: %s %s [%s]\n", pill1?"약O":"약X", lid1?"닫힘":"열림", stateToText(slotState[0]).c_str());
    Serial.printf("슬롯2: %s %s [%s]\n", pill2?"약O":"약X", lid2?"닫힘":"열림", stateToText(slotState[1]).c_str());
    Serial.printf("슬롯3: %s %s [%s]\n", pill3?"약O":"약X", lid3?"닫힘":"열림", stateToText(slotState[2]).c_str());
    Serial.println("-----------------------------------\n");
    lastPrint = millis();
  }

  delay(100);
}
