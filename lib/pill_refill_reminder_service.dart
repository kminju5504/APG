import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'alarm_service.dart';
import 'bluetooth_manager.dart';

/// 약 리필 리마인더 서비스
/// 알람 시간 2시간 전에 해당 슬롯이 비어있으면 알림!
class PillRefillReminderService {
  static final PillRefillReminderService _instance = PillRefillReminderService._internal();
  factory PillRefillReminderService() => _instance;
  PillRefillReminderService._internal();

  Timer? _checkTimer;
  final BluetoothManager _bluetoothManager = BluetoothManager();

  // 리마인더 전 시간 (2시간 = 120분)
  static const int reminderMinutesBefore = 120;

  /// 서비스 시작 (앱 시작 시 호출)
  void start() {
    print("⏰ [RefillReminder] 서비스 시작!");
    
    // 5분마다 체크
    _checkTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkAndNotify();
    });
    
    // 시작 시 바로 한 번 체크
    _checkAndNotify();
  }

  /// 서비스 중지
  void stop() {
    _checkTimer?.cancel();
    print("⏰ [RefillReminder] 서비스 중지");
  }

  /// 알람 체크 및 알림 전송
  Future<void> _checkAndNotify() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("⏰ [RefillReminder] 로그인 안 됨, 스킵");
        return;
      }

      // Firestore에서 알람 목록 가져오기
      final alarms = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('alarms')
          .where('isEnabled', isEqualTo: true)
          .get();

      if (alarms.docs.isEmpty) {
        print("⏰ [RefillReminder] 등록된 알람 없음");
        return;
      }

      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();

      for (var doc in alarms.docs) {
        final data = doc.data();
        final int hour = data['hour'] ?? 0;
        final int minute = data['minute'] ?? 0;
        final int slotNumber = data['slotNumber'] ?? 0;
        final String medicineName = data['medicineName'] ?? '약';

        if (slotNumber < 1 || slotNumber > 3) continue;

        // 오늘 알람 시간 계산
        DateTime alarmTime = DateTime(now.year, now.month, now.day, hour, minute);
        
        // 알람 시간 2시간 전 계산
        DateTime reminderTime = alarmTime.subtract(Duration(minutes: reminderMinutesBefore));

        // 현재 시간이 리마인더 시간 범위인지 확인 (±5분)
        final diffMinutes = now.difference(reminderTime).inMinutes;
        if (diffMinutes < 0 || diffMinutes > 10) continue;

        // 오늘 이미 알림 보냈는지 확인
        final todayKey = 'refill_reminder_${slotNumber}_${now.year}_${now.month}_${now.day}';
        if (prefs.getBool(todayKey) == true) {
          print("⏰ [RefillReminder] 슬롯$slotNumber 오늘 이미 알림 보냄");
          continue;
        }

        // 해당 슬롯이 비어있는지 확인
        final slot = _bluetoothManager.slots[slotNumber - 1];
        if (slot.hasPill) {
          print("⏰ [RefillReminder] 슬롯$slotNumber 약 있음, 알림 불필요");
          continue;
        }

        // 🔔 알림 전송!
        print("⏰ [RefillReminder] 슬롯$slotNumber 비어있음! 알림 전송");
        
        await AlarmService.scheduleAlarm(
          id: 9000 + slotNumber,  // 리필 알림용 ID
          hour: now.hour,
          minute: now.minute,
          title: "💊 약 넣어주세요!",
          body: "$slotNumber번 칸에 '$medicineName' 약을 넣어주세요. ${hour}시 ${minute}분에 복용 예정입니다.",
        );

        // 오늘 알림 보냈다고 저장
        await prefs.setBool(todayKey, true);
        
        print("✅ [RefillReminder] 슬롯$slotNumber 리필 알림 전송 완료!");
      }
    } catch (e) {
      print("❌ [RefillReminder] 에러: $e");
    }
  }

  /// 수동으로 체크 (테스트용)
  Future<void> checkNow() async {
    await _checkAndNotify();
  }

  void dispose() {
    stop();
  }
}

