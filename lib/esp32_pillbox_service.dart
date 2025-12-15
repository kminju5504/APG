import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// ESP32 약통과 통신하기 위한 서비스 클래스
class ESP32PillboxService {
  // ============================================================
  // 🔧 ESP32 펌웨어 UUID (Nordic UART Service)
  // ============================================================
  
  // ESP32 BLE 서비스 UUID
  static const String SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  
  // ESP32 BLE 특성 UUID
  static const String CHARACTERISTIC_TX_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";  // ESP32 → App (Notify)
  static const String CHARACTERISTIC_RX_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";  // App → ESP32 (Write)

  // ============================================================
  // 📡 약통 제어 명령어 (ESP32 펌웨어와 동일하게 설정)
  // ============================================================
  static const String CMD_LED_ON = "LED_ON";           // LED 켜기
  static const String CMD_LED_OFF = "LED_OFF";         // LED 끄기
  static const String CMD_ALARM_ON = "ALARM_ON";       // 알람(부저) 켜기
  static const String CMD_ALARM_OFF = "ALARM_OFF";     // 알람(부저) 끄기
  static const String CMD_MOTOR_OPEN = "MOTOR_OPEN";   // 약통 뚜껑 열기 (서보모터)
  static const String CMD_MOTOR_CLOSE = "MOTOR_CLOSE"; // 약통 뚜껑 닫기
  static const String CMD_GET_STATUS = "GET_STATUS";   // 약통 상태 요청
  static const String CMD_PILL_TAKEN = "PILL_TAKEN";   // 약 복용 확인

  // 연결된 기기
  BluetoothDevice? _device;
  
  // 쓰기/읽기용 특성
  BluetoothCharacteristic? _txCharacteristic;
  BluetoothCharacteristic? _rxCharacteristic;
  
  // 연결 상태
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // 수신 데이터 스트림
  final StreamController<String> _dataController = StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataController.stream;

  // 연결 상태 스트림
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  StreamSubscription? _connectionSubscription;
  StreamSubscription? _notifySubscription;

  /// ESP32 기기에 연결
  Future<bool> connect(BluetoothDevice device) async {
    try {
      _device = device;
      
      print("🔗 [ESP32] 연결 시도: ${device.platformName}");
      
      // 연결
      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );
      
      // 연결 상태 모니터링
      _connectionSubscription = device.connectionState.listen((state) {
        _isConnected = (state == BluetoothConnectionState.connected);
        _connectionController.add(_isConnected);
        print("🔗 [ESP32] 연결 상태: $state");
        
        if (!_isConnected) {
          _cleanup();
        }
      });

      // 서비스 탐색
      bool servicesFound = await _discoverServices();
      
      if (servicesFound) {
        _isConnected = true;
        _connectionController.add(true);
        print("✅ [ESP32] 연결 성공!");
        return true;
      } else {
        print("❌ [ESP32] 서비스를 찾을 수 없습니다.");
        await disconnect();
        return false;
      }
    } catch (e) {
      print("❌ [ESP32] 연결 실패: $e");
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// 서비스 및 특성 탐색
  Future<bool> _discoverServices() async {
    if (_device == null) return false;

    try {
      print("🔍 [ESP32] 서비스 탐색 중...");
      
      List<BluetoothService> services = await _device!.discoverServices();
      
      for (var service in services) {
        print("📦 [ESP32] 서비스 발견: ${service.uuid}");
        
        // ESP32 서비스 UUID 확인
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          print("✅ [ESP32] 약통 서비스 찾음!");
          
          for (var char in service.characteristics) {
            print("  📝 특성: ${char.uuid}");
            print("     - Write: ${char.properties.write}");
            print("     - WriteNoResp: ${char.properties.writeWithoutResponse}");
            print("     - Notify: ${char.properties.notify}");
            print("     - Read: ${char.properties.read}");
            
            // TX 특성 (앱 → ESP32)
            if (char.uuid.toString().toLowerCase() == CHARACTERISTIC_RX_UUID.toLowerCase()) {
              if (char.properties.write || char.properties.writeWithoutResponse) {
                _rxCharacteristic = char;
                print("✅ [ESP32] RX 특성 설정 완료 (쓰기용)");
              }
            }
            
            // RX 특성 (ESP32 → 앱)
            if (char.uuid.toString().toLowerCase() == CHARACTERISTIC_TX_UUID.toLowerCase()) {
              if (char.properties.notify || char.properties.read) {
                _txCharacteristic = char;
                await _setupNotification(char);
                print("✅ [ESP32] TX 특성 설정 완료 (알림용)");
              }
            }
          }
        }
      }

      // 만약 지정된 서비스를 못 찾았으면, 모든 쓰기/알림 가능한 특성 사용
      if (_rxCharacteristic == null || _txCharacteristic == null) {
        print("⚠️ [ESP32] 지정된 UUID 서비스를 찾지 못함. 범용 특성 탐색...");
        
        for (var service in services) {
          for (var char in service.characteristics) {
            if (_rxCharacteristic == null && 
                (char.properties.write || char.properties.writeWithoutResponse)) {
              _rxCharacteristic = char;
              print("📝 [ESP32] 범용 RX 특성 사용: ${char.uuid}");
            }
            
            if (_txCharacteristic == null && char.properties.notify) {
              _txCharacteristic = char;
              await _setupNotification(char);
              print("📝 [ESP32] 범용 TX 특성 사용: ${char.uuid}");
            }
          }
        }
      }

      return _rxCharacteristic != null;
    } catch (e) {
      print("❌ [ESP32] 서비스 탐색 실패: $e");
      return false;
    }
  }

  /// 알림(Notification) 설정
  Future<void> _setupNotification(BluetoothCharacteristic characteristic) async {
    try {
      await characteristic.setNotifyValue(true);
      
      _notifySubscription = characteristic.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          String data = utf8.decode(value, allowMalformed: true);
          print("📩 [ESP32] 수신: $data");
          _dataController.add(data);
        }
      });
      
      print("✅ [ESP32] 알림 설정 완료");
    } catch (e) {
      print("❌ [ESP32] 알림 설정 실패: $e");
    }
  }

  /// 데이터 전송
  Future<bool> sendCommand(String command) async {
    if (_rxCharacteristic == null) {
      print("❌ [ESP32] 쓰기 특성이 없습니다.");
      return false;
    }

    try {
      List<int> bytes = utf8.encode(command);
      
      if (_rxCharacteristic!.properties.writeWithoutResponse) {
        await _rxCharacteristic!.write(bytes, withoutResponse: true);
      } else {
        await _rxCharacteristic!.write(bytes);
      }
      
      print("📤 [ESP32] 전송: $command");
      return true;
    } catch (e) {
      print("❌ [ESP32] 전송 실패: $e");
      return false;
    }
  }

  // ============================================================
  // 🎮 약통 제어 함수들
  // ============================================================

  /// LED 켜기
  Future<bool> turnOnLED() async {
    return await sendCommand(CMD_LED_ON);
  }

  /// LED 끄기
  Future<bool> turnOffLED() async {
    return await sendCommand(CMD_LED_OFF);
  }

  /// 알람(부저) 켜기
  Future<bool> turnOnAlarm() async {
    return await sendCommand(CMD_ALARM_ON);
  }

  /// 알람(부저) 끄기
  Future<bool> turnOffAlarm() async {
    return await sendCommand(CMD_ALARM_OFF);
  }

  /// 약통 뚜껑 열기
  Future<bool> openPillbox() async {
    return await sendCommand(CMD_MOTOR_OPEN);
  }

  /// 약통 뚜껑 닫기
  Future<bool> closePillbox() async {
    return await sendCommand(CMD_MOTOR_CLOSE);
  }

  /// 약통 상태 확인
  Future<bool> getStatus() async {
    return await sendCommand(CMD_GET_STATUS);
  }

  /// 약 복용 확인 전송
  Future<bool> confirmPillTaken() async {
    return await sendCommand(CMD_PILL_TAKEN);
  }

  /// 연결 해제
  Future<void> disconnect() async {
    try {
      _cleanup();
      await _device?.disconnect();
      print("🔌 [ESP32] 연결 해제");
    } catch (e) {
      print("❌ [ESP32] 연결 해제 실패: $e");
    }
  }

  void _cleanup() {
    _connectionSubscription?.cancel();
    _notifySubscription?.cancel();
    _txCharacteristic = null;
    _rxCharacteristic = null;
    _isConnected = false;
  }

  void dispose() {
    _cleanup();
    _dataController.close();
    _connectionController.close();
  }
}

