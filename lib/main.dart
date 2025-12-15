import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'alarm_service.dart';
import 'bluetooth_manager.dart';
import 'pill_refill_reminder_service.dart';
import 'background_service.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'TabBarPage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("🚀 main() 진입");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print("🔥 Firebase 초기화 완료");

  // 알림 서비스 초기화
  await AlarmService.initializeNotification();

  // 알림 권한 요청 (Android 13+, iOS)
  await AlarmService.requestAllPermissions();

  // 🔄 백그라운드 BLE 서비스 초기화
  await BackgroundBleService.initializeService();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final BluetoothManager _bluetoothManager = BluetoothManager();
  final PillRefillReminderService _refillReminder = PillRefillReminderService();

  @override
  void initState() {
    super.initState();
    // 로그인 후 블루투스 자동 연결 시도 및 리필 리마인더 시작
    _initServices();
  }

  Future<void> _initServices() async {
    // 잠시 대기 후 서비스 시작 (앱 초기화 완료 대기)
    await Future.delayed(const Duration(seconds: 2));
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      print("🔗 [Main] 블루투스 자동 연결 시도...");
      await _bluetoothManager.autoConnect();
      
      // 🔔 약 리필 리마인더 서비스 시작!
      _refillReminder.start();
      print("⏰ [Main] 리필 리마인더 서비스 시작!");
    }
  }

  @override
  void dispose() {
    _refillReminder.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        primaryColor: const Color(0xFFB71C1C),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const TabbarPage();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
