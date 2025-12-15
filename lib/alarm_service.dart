import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 전역 플러그인 (어디서든 접근 가능)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

class AlarmService {
  // 이미 초기화했는지 여부 (중복 초기화 방지)
  static bool _initialized = false;

  /// 초기화 (앱 시작 시 main.dart에서 한 번만 호출)
  static Future<void> initializeNotification() async {
    if (_initialized) {
      // 이미 초기화됐으면 그냥 리턴
      return;
    }

    try {
      print("🔔 [AlarmService] initializeNotification() 시작");

      // 타임존 초기화
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

      const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS에서 알림 권한 요청
      const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // 알림 플러그인 초기화
      await flutterLocalNotificationsPlugin.initialize(settings);

      _initialized = true;
      print("✅ [AlarmService] 알림 초기화 완료");
    } catch (e, s) {
      // 여기서 에러를 잡지 않으면 main 쪽에서 뻗어버리면서 흰화면 가능
      print("❌ [AlarmService] 알림 초기화 중 에러: $e");
      print(s);
    }
  }

  /// 🔐 알림 권한 요청 (Android 13+ 필수)
  static Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      // Android 13 이상에서 알림 권한 요청
      final status = await Permission.notification.request();
      print("🔔 [AlarmService] 알림 권한 상태: $status");

      if (status.isGranted) {
        print("✅ [AlarmService] 알림 권한 허용됨");
        return true;
      } else if (status.isPermanentlyDenied) {
        print("❌ [AlarmService] 알림 권한 영구 거부됨 - 설정에서 직접 허용 필요");
        return false;
      } else {
        print("❌ [AlarmService] 알림 권한 거부됨");
        return false;
      }
    } else if (Platform.isIOS) {
      // iOS는 초기화 시 권한 요청됨
      return true;
    }
    return true;
  }

  /// 🔐 정확한 알람 권한 확인 (Android 12+)
  static Future<bool> checkExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // Android 12 이상에서 정확한 알람 권한 확인
        final canSchedule = await androidPlugin.canScheduleExactNotifications();
        print("🔔 [AlarmService] 정확한 알람 예약 가능: $canSchedule");

        if (canSchedule != true) {
          // 권한이 없으면 요청
          final granted = await androidPlugin.requestExactAlarmsPermission();
          print("🔔 [AlarmService] 정확한 알람 권한 요청 결과: $granted");
          return granted ?? false;
        }
        return canSchedule ?? false;
      }
    }
    return true;
  }

  /// 🔐 모든 필요한 권한 요청
  static Future<bool> requestAllPermissions() async {
    print("🔔 [AlarmService] 모든 권한 요청 시작");

    final notificationGranted = await requestNotificationPermission();
    final exactAlarmGranted = await checkExactAlarmPermission();

    print("🔔 [AlarmService] 알림 권한: $notificationGranted, 정확한 알람 권한: $exactAlarmGranted");

    return notificationGranted && exactAlarmGranted;
  }

  /// 🔔 알람 한 개 예약 (매일 같은 시간 반복)
  static Future<void> scheduleAlarm({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    int? slotNumber,  // 약통 슬롯 번호 (참고용)
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    // 오늘 알람 시간
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // 이미 지난 시간이면 → 내일
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    print(
        "🔔 [AlarmService] 알람 예약: id=$id, time=${scheduled.toString()}, title=$title");

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'apg_channel',
          'APG 알림',
          channelDescription: '약 복용 알림 채널',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      // ⬇ 매일 같은 시각에 반복
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 특정 알람 취소
  static Future<void> cancelAlarm(int id) async {
    print("🧹 [AlarmService] 알람 취소 id=$id");
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  /// 전부 다 취소
  static Future<void> cancelAllAlarms() async {
    print("🧹 [AlarmService] 모든 알람 취소");
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// 🔔 앱 아이콘 배지 초기화 (알림 배지 숫자 제거)
  static Future<void> clearBadge() async {
    try {
      // 모든 알림 초기화 (배지 포함)
      await flutterLocalNotificationsPlugin.cancelAll();
      print("🧹 [AlarmService] 앱 배지 초기화 완료");
    } catch (e) {
      print("❌ [AlarmService] 배지 초기화 실패: $e");
    }
  }

  /// 🧹 모든 알람 기록 삭제
  static Future<void> clearAllAlarmHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('alarm_history');

      final snapshot = await collection.get();
      
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      print("🧹 [AlarmService] 모든 알람 기록 삭제 완료");
    } catch (e) {
      print("❌ [AlarmService] 알람 기록 삭제 실패: $e");
    }
  }

  /// 📋 알람 기록 저장
  static Future<void> saveAlarmHistory({
    required String type,  // 'alarm', 'taken', 'reminder', 'missed'
    required String title,
    required String message,
    int slotNumber = 0,
    bool isTaken = false,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('alarm_history')
          .add({
        'type': type,
        'title': title,
        'message': message,
        'slotNumber': slotNumber,
        'timestamp': FieldValue.serverTimestamp(),
        'isTaken': isTaken,
      });

      print("📋 [AlarmService] 알람 기록 저장: $type - $title");
    } catch (e) {
      print("❌ [AlarmService] 알람 기록 저장 실패: $e");
    }
  }
}
