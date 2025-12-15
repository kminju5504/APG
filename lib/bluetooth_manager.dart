import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'alarm_service.dart';
import 'background_service.dart';

/// 블루투스 연결 관리 서비스 (싱글톤)
/// BLE로 받은 데이터를 Firebase에 자동 업로드!
class BluetoothManager {
  static final BluetoothManager _instance = BluetoothManager._internal();
  factory BluetoothManager() => _instance;
  BluetoothManager._internal();

  // 저장 키
  static const String _keyDeviceId = 'connected_device_id';
  static const String _keyDeviceName = 'connected_device_name';

  // 연결된 기기
  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  // BLE 특성
  BluetoothCharacteristic? _txCharacteristic;

  // 연결 상태
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // 🔥 Firebase Realtime Database 참조
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('pillbox');

  // 약통 슬롯 상태
  List<PillSlotStatus> slots = [
    PillSlotStatus(slotNumber: 1),
    PillSlotStatus(slotNumber: 2),
    PillSlotStatus(slotNumber: 3),
  ];

  // 마지막 복용 시간
  String? _lastTakenTime1;
  String? _lastTakenTime2;
  String? _lastTakenTime3;

  // 스트림 컨트롤러
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  final StreamController<List<PillSlotStatus>> _slotController = StreamController<List<PillSlotStatus>>.broadcast();
  Stream<List<PillSlotStatus>> get slotStream => _slotController.stream;

  // 구독
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _notifySubscription;

  // 알람 후 약 복용 확인 관련 (슬롯별)
  Map<int, Timer?> _pillCheckTimers = {};
  Map<int, bool> _pillTakenAfterAlarm = {1: false, 2: false, 3: false};

  // Firebase 업로드 타이머
  Timer? _firebaseUploadTimer;

  /// 저장된 기기에 자동 연결 시도
  Future<bool> autoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(_keyDeviceId);
    final deviceName = prefs.getString(_keyDeviceName);

    if (deviceId == null) {
      print("🔗 [BluetoothManager] 저장된 기기 없음");
      return false;
    }

    print("🔗 [BluetoothManager] 자동 연결 시도: $deviceName ($deviceId)");

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      
      await for (final results in FlutterBluePlus.scanResults) {
        for (final result in results) {
          if (result.device.remoteId.toString() == deviceId) {
            await FlutterBluePlus.stopScan();
            return await connect(result.device);
          }
        }
      }
      
      await FlutterBluePlus.stopScan();
      print("❌ [BluetoothManager] 저장된 기기를 찾을 수 없음");
      return false;
    } catch (e) {
      print("❌ [BluetoothManager] 자동 연결 실패: $e");
      return false;
    }
  }

  /// 기기 연결
  Future<bool> connect(BluetoothDevice device) async {
    try {
      print("🔗 [BluetoothManager] 연결 시도: ${device.platformName}");

      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;

      // 연결 상태 모니터링
      _connectionSubscription = device.connectionState.listen((state) {
        _isConnected = (state == BluetoothConnectionState.connected);
        _connectionController.add(_isConnected);

        if (!_isConnected) {
          print("⚠️ [BluetoothManager] 연결 끊김, 재연결 시도...");
          BackgroundBleService.updateNotification(
            "APG 약통 연결 끊김 ⚠️",
            "재연결 시도 중...",
          );
          _cleanup();
          Future.delayed(const Duration(seconds: 3), () => autoConnect());
        }
      });

      // 서비스 탐색
      await _discoverServices(device);

      // 연결 정보 저장
      await _saveDeviceInfo(device);

      _isConnected = true;
      _connectionController.add(true);

      // 🔥 Firebase 업로드 시작 (2초마다)
      _startFirebaseUpload();

      // 🔄 백그라운드 서비스 시작 + 알림 업데이트
      await BackgroundBleService.startService();
      BackgroundBleService.updateNotification(
        "APG 약통 연결됨 ✅",
        "실시간 모니터링 중...",
      );

      print("✅ [BluetoothManager] 연결 성공!");
      return true;
    } catch (e) {
      print("❌ [BluetoothManager] 연결 실패: $e");
      return false;
    }
  }

  /// 서비스 탐색 및 알림 설정
  Future<void> _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();

    for (var service in services) {
      for (var char in service.characteristics) {
        if (char.properties.notify) {
          _txCharacteristic = char;
          await _setupNotification(char);
        }
      }
    }
  }

  /// 알림 설정
  Future<void> _setupNotification(BluetoothCharacteristic char) async {
    await char.setNotifyValue(true);

    _notifySubscription = char.lastValueStream.listen((value) {
      if (value.isNotEmpty) {
        String data = utf8.decode(value, allowMalformed: true).trim();
        _parseESP32Data(data);
      }
    });
  }

  /// ESP32 데이터 파싱
  void _parseESP32Data(String data) {
    try {
      List<String> slotData = data.split(';');
      List<PillSlotStatus> previousSlots = List.from(slots);

      for (var slot in slotData) {
        var parts = slot.split(':');
        if (parts.length == 2) {
          int slotNum = int.tryParse(parts[0]) ?? 0;
          var values = parts[1].split(',');

          if (slotNum >= 1 && slotNum <= 3 && values.length >= 2) {
            bool hasPill = values[0].trim() == "present";
            bool isLidClosed = values[1].trim() == "closed";
            bool takenNow = values.length > 2 && values[2].trim() == "1";
            int takenCount = values.length > 3 ? (int.tryParse(values[3].trim()) ?? 0) : 0;

            slots[slotNum - 1] = PillSlotStatus(
              slotNumber: slotNum,
              hasPill: hasPill,
              isLidClosed: isLidClosed,
              takenNow: takenNow,
              takenCount: takenCount,
            );

            // 🔔 복용 감지 - ESP32의 상태 머신 결과(takenNow)만 신뢰!
            // (뚜껑 닫힌 상태에서 약 상태만 바뀌는 것은 센서 오류일 수 있으므로 무시)
            // ESP32 복용 조건: 약O+닫힘 → 약O+열림 → 약X+열림 → 약X+닫힘 순서로 진행되어야 함
            if (takenNow) {
              String now = _formatDateTime(DateTime.now());
              print("💊 [BluetoothManager] ${slotNum}번 칸 약 복용 감지! (ESP32 확인) 시간: $now");
              
              // 해당 슬롯 복용 완료 표시
              _pillTakenAfterAlarm[slotNum] = true;
              
              // 마지막 복용 시간 저장 (뚜껑 닫았을 때만!)
              if (slotNum == 1) _lastTakenTime1 = now;
              if (slotNum == 2) _lastTakenTime2 = now;
              if (slotNum == 3) _lastTakenTime3 = now;
              
              // Firestore에 복용 기록 업데이트
              _updateTakenStatus(slotNum);
              
              // 📋 알람 기록 저장!
              AlarmService.saveAlarmHistory(
                type: 'taken',
                title: '💊 약 복용 완료',
                message: '$slotNum번 슬롯에서 약을 복용했습니다.',
                slotNumber: slotNum,
                isTaken: true,
              );
            }
          }
        }
      }

      _slotController.add(List.from(slots));
    } catch (e) {
      print("⚠️ [BluetoothManager] 데이터 파싱 오류: $e");
    }
  }

  /// 🔥 Firebase 업로드 시작
  void _startFirebaseUpload() {
    _firebaseUploadTimer?.cancel();
    
    // 2초마다 Firebase에 업로드
    _firebaseUploadTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isConnected) {
        _uploadToFirebase();
      }
    });
    
    print("🔥 [BluetoothManager] Firebase 자동 업로드 시작!");
  }

  /// 🔥 Firebase에 데이터 업로드
  Future<void> _uploadToFirebase() async {
    try {
      Map<String, dynamic> slot1Data = {
        'pill': slots[0].hasPill ? 'present' : 'empty',
        'lid': slots[0].isLidClosed ? 'closed' : 'open',
        'hasPill': slots[0].hasPill,
        'isLidClosed': slots[0].isLidClosed,
        'takenNow': slots[0].takenNow,
        'takenCount': slots[0].takenCount,  // 오프라인 복용 횟수 동기화!
      };
      if (_lastTakenTime1 != null) slot1Data['lastTakenTime'] = _lastTakenTime1;

      Map<String, dynamic> slot2Data = {
        'pill': slots[1].hasPill ? 'present' : 'empty',
        'lid': slots[1].isLidClosed ? 'closed' : 'open',
        'hasPill': slots[1].hasPill,
        'isLidClosed': slots[1].isLidClosed,
        'takenNow': slots[1].takenNow,
        'takenCount': slots[1].takenCount,  // 오프라인 복용 횟수 동기화!
      };
      if (_lastTakenTime2 != null) slot2Data['lastTakenTime'] = _lastTakenTime2;

      Map<String, dynamic> slot3Data = {
        'pill': slots[2].hasPill ? 'present' : 'empty',
        'lid': slots[2].isLidClosed ? 'closed' : 'open',
        'hasPill': slots[2].hasPill,
        'isLidClosed': slots[2].isLidClosed,
        'takenNow': slots[2].takenNow,
        'takenCount': slots[2].takenCount,  // 오프라인 복용 횟수 동기화!
      };
      if (_lastTakenTime3 != null) slot3Data['lastTakenTime'] = _lastTakenTime3;

      await _dbRef.update({
        'slot1': slot1Data,
        'slot2': slot2Data,
        'slot3': slot3Data,
        'lastUpdate': ServerValue.timestamp,
        'status': 'online',
      });
      
      print("🔥 [BluetoothManager] Firebase 업로드 ✅");
    } catch (e) {
      print("🔥 [BluetoothManager] Firebase 업로드 실패: $e");
    }
  }

  /// 날짜/시간 포맷
  String _formatDateTime(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
           "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
  }

  /// 알람 발생 시 호출 (슬롯 번호, 약 이름 전달)
  void onAlarmTriggered({required int slotNumber, String medicineName = '약'}) {
    if (slotNumber < 1 || slotNumber > 3) return;
    
    // 해당 슬롯 복용 상태 초기화
    _pillTakenAfterAlarm[slotNumber] = false;

    print("⏰ [BluetoothManager] ${slotNumber}번 슬롯 알람 발생! 10분 후 복용 확인 예정");

    // 기존 타이머 취소
    _pillCheckTimers[slotNumber]?.cancel();

    // 10분 후 복용 확인
    _pillCheckTimers[slotNumber] = Timer(const Duration(minutes: 10), () {
      _checkPillTaken(slotNumber: slotNumber, medicineName: medicineName);
    });
  }

  /// 약 복용 확인 및 재알림
  Future<void> _checkPillTaken({required int slotNumber, String medicineName = '약'}) async {
    // 해당 슬롯 약 복용 여부 확인
    if (_pillTakenAfterAlarm[slotNumber] != true) {
      print("⚠️ [BluetoothManager] ${slotNumber}번 슬롯 약 복용 미확인! 재알림 발송");

      await AlarmService.scheduleAlarm(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        hour: DateTime.now().hour,
        minute: DateTime.now().minute,
        title: "💊 약 복용 알림 (재알림)",
        body: "$medicineName - ${slotNumber}번 약통에서 약을 아직 안 드셨어요!",
      );
    } else {
      print("✅ [BluetoothManager] ${slotNumber}번 슬롯 약 복용 확인됨!");
    }
  }

  /// 📝 복용 상태 업데이트 (Firestore)
  Future<void> _updateTakenStatus(int slotNumber) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Firestore에서 해당 슬롯의 알람들 가져오기
      final alarms = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('alarms')
          .where('slotNumber', isEqualTo: slotNumber)
          .get();

      // Firestore에 복용 기록 업데이트
      for (var doc in alarms.docs) {
        await doc.reference.update({
          'isTaken': true,
          'lastTakenDate': FieldValue.serverTimestamp(),
        });
      }

      print("✅ [BluetoothManager] ${slotNumber}번 슬롯 복용 완료 기록됨!");
    } catch (e) {
      print("❌ [BluetoothManager] 복용 상태 업데이트 실패: $e");
    }
  }

  /// 연결 정보 저장
  Future<void> _saveDeviceInfo(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceId, device.remoteId.toString());
    await prefs.setString(_keyDeviceName, device.platformName);
    print("💾 [BluetoothManager] 기기 정보 저장: ${device.platformName}");
  }

  /// 연결 해제 (수동)
  Future<void> disconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDeviceId);
      await prefs.remove(_keyDeviceName);

      // Firebase에 오프라인 상태 업로드
      try {
        await _dbRef.update({'status': 'offline'});
      } catch (_) {}

      // 🔄 백그라운드 서비스 중지
      BackgroundBleService.stopService();

      _cleanup();
      await _connectedDevice?.disconnect();
      _connectedDevice = null;

      _isConnected = false;
      _connectionController.add(false);

      print("🔌 [BluetoothManager] 연결 해제 완료");
    } catch (e) {
      print("❌ [BluetoothManager] 연결 해제 실패: $e");
    }
  }

  void _cleanup() {
    _connectionSubscription?.cancel();
    _notifySubscription?.cancel();
    _pillCheckTimers.forEach((_, timer) => timer?.cancel());
    _pillCheckTimers.clear();
    _firebaseUploadTimer?.cancel();
    _txCharacteristic = null;
  }

  /// 저장된 기기 정보 확인
  Future<String?> getSavedDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceName);
  }

  void dispose() {
    _cleanup();
    _connectionController.close();
    _slotController.close();
  }
}

/// 약통 슬롯 상태
class PillSlotStatus {
  final int slotNumber;
  final bool hasPill;
  final bool isLidClosed;
  final bool takenNow;
  final int takenCount;  // 오프라인에서 저장된 복용 횟수

  PillSlotStatus({
    required this.slotNumber,
    this.hasPill = false,
    this.isLidClosed = true,
    this.takenNow = false,
    this.takenCount = 0,
  });
}
