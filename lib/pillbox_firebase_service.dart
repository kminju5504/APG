  import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'alarm_service.dart';

/// Firebase Realtime Database와 연동하는 약통 서비스
class PillboxFirebaseService {
  static final PillboxFirebaseService _instance = PillboxFirebaseService._internal();
  factory PillboxFirebaseService() => _instance;
  PillboxFirebaseService._internal();

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('pillbox');

  // 슬롯 상태
  List<PillboxSlot> slots = [
    PillboxSlot(slotNumber: 1),
    PillboxSlot(slotNumber: 2),
    PillboxSlot(slotNumber: 3),
  ];

  // 스트림 컨트롤러
  final StreamController<List<PillboxSlot>> _slotController = 
      StreamController<List<PillboxSlot>>.broadcast();
  Stream<List<PillboxSlot>> get slotStream => _slotController.stream;

  // 복용 감지 스트림
  final StreamController<int> _pillTakenController = StreamController<int>.broadcast();
  Stream<int> get pillTakenStream => _pillTakenController.stream;

  StreamSubscription? _subscription;
  bool _isListening = false;

  /// Firebase Realtime Database 실시간 구독 시작
  void startListening() {
    if (_isListening) return;
    _isListening = true;

    print("🔥 [Firebase] Realtime Database 구독 시작");

    _subscription = _dbRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        _parseData(event.snapshot.value as Map<dynamic, dynamic>);
      }
    }, onError: (error) {
      print("❌ [Firebase] 에러: $error");
    });
  }

  /// 데이터 파싱
  void _parseData(Map<dynamic, dynamic> data) {
    try {
      for (int i = 1; i <= 3; i++) {
        final slotData = data['slot$i'];
        if (slotData != null) {
          final prevSlot = slots[i - 1];
          
          slots[i - 1] = PillboxSlot(
            slotNumber: i,
            hasPill: slotData['hasPill'] ?? false,
            isLidClosed: slotData['isLidClosed'] ?? true,
            pillText: slotData['pill'] ?? 'empty',
            lidText: slotData['lid'] ?? 'closed',
            lastTakenTime: slotData['lastTakenTime'],
            takenNow: slotData['takenNow'] ?? false,
          );

          // 복용 감지!
          if (slots[i - 1].takenNow && !prevSlot.takenNow) {
            print("💊 [Firebase] 슬롯 $i 약 복용 감지!");
            _pillTakenController.add(i);
            _onPillTaken(i);
          }
        }
      }

      _slotController.add(List.from(slots));
    } catch (e) {
      print("❌ [Firebase] 파싱 에러: $e");
    }
  }

  /// 약 복용 시 호출
  void _onPillTaken(int slotNumber) {
    print("✅ [Firebase] 슬롯 $slotNumber 약 복용 완료 처리");
    // 여기서 알람 취소 등 추가 로직 가능
  }

  /// 특정 슬롯 데이터 한 번 읽기
  Future<PillboxSlot?> getSlotData(int slotNumber) async {
    try {
      final snapshot = await _dbRef.child('slot$slotNumber').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        return PillboxSlot(
          slotNumber: slotNumber,
          hasPill: data['hasPill'] ?? false,
          isLidClosed: data['isLidClosed'] ?? true,
          pillText: data['pill'] ?? 'empty',
          lidText: data['lid'] ?? 'closed',
          lastTakenTime: data['lastTakenTime'],
          takenNow: data['takenNow'] ?? false,
        );
      }
    } catch (e) {
      print("❌ [Firebase] 읽기 에러: $e");
    }
    return null;
  }

  /// 모든 슬롯 데이터 한 번 읽기
  Future<List<PillboxSlot>> getAllSlots() async {
    List<PillboxSlot> result = [];
    for (int i = 1; i <= 3; i++) {
      final slot = await getSlotData(i);
      if (slot != null) {
        result.add(slot);
      }
    }
    return result;
  }

  /// 마지막 복용 시간 초기화
  Future<void> resetLastTakenTime(int slotNumber) async {
    try {
      await _dbRef.child('slot$slotNumber/lastTakenTime').remove();
      print("🔄 [Firebase] 슬롯 $slotNumber 복용 기록 리셋");
    } catch (e) {
      print("❌ [Firebase] 리셋 에러: $e");
    }
  }

  /// 구독 중지
  void stopListening() {
    _subscription?.cancel();
    _isListening = false;
    print("🔥 [Firebase] Realtime Database 구독 중지");
  }

  void dispose() {
    stopListening();
    _slotController.close();
    _pillTakenController.close();
  }
}

/// 약통 슬롯 데이터 모델
class PillboxSlot {
  final int slotNumber;
  final bool hasPill;           // 약 유무
  final bool isLidClosed;       // 뚜껑 닫힘 여부
  final String pillText;        // "present" / "empty"
  final String lidText;         // "closed" / "open"
  final String? lastTakenTime;  // 마지막 복용 시간
  final bool takenNow;          // 방금 복용했는지

  PillboxSlot({
    required this.slotNumber,
    this.hasPill = false,
    this.isLidClosed = true,
    this.pillText = 'empty',
    this.lidText = 'closed',
    this.lastTakenTime,
    this.takenNow = false,
  });

  @override
  String toString() {
    return 'Slot$slotNumber(pill: $pillText, lid: $lidText, lastTaken: $lastTakenTime)';
  }
}

