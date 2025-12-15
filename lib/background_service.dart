import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

/// 백그라운드 서비스 관리
class BackgroundBleService {
  
  /// 서비스 초기화
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,  // 자동 시작 안 함 (수동으로 시작)
        isForegroundMode: true,
        notificationChannelId: 'apg_background',
        initialNotificationTitle: 'APG 약통',
        initialNotificationContent: '연결 준비 중...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
    
    print("🔄 [BackgroundService] 초기화 완료");
  }

  /// 서비스 시작
  static Future<void> startService() async {
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
      print("🔄 [BackgroundService] 서비스 시작됨");
    }
  }

  /// 서비스 중지
  static void stopService() {
    final service = FlutterBackgroundService();
    service.invoke("stopService");
    print("🔄 [BackgroundService] 서비스 중지됨");
  }

  /// 알림 업데이트
  static void updateNotification(String title, String content) {
    final service = FlutterBackgroundService();
    service.invoke("updateNotification", {
      "title": title,
      "content": content,
    });
  }
}

/// iOS 백그라운드
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  return true;
}

/// 백그라운드 서비스 시작
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // 서비스 중지 핸들러
  service.on('stopService').listen((event) {
    service.stopSelf();
    print("🛑 [BackgroundService] 서비스 종료");
  });

  // 알림 업데이트 핸들러 (Android만)
  service.on('updateNotification').listen((event) {
    if (event != null && service is AndroidServiceInstance) {
      final title = event['title'] ?? 'APG 약통';
      final content = event['content'] ?? '';
      
      service.setForegroundNotificationInfo(
        title: title,
        content: content,
      );
    }
  });

  // 서비스 실행 중 표시 (Android만)
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "APG 약통",
      content: "백그라운드에서 연결 유지 중...",
    );
  }

  print("✅ [BackgroundService] 백그라운드 서비스 시작됨");
}
