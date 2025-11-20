import 'package:clean_apg_app/TabBarPage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_screen.dart'; // 로그인 화면
// import 'AlarmRegistrationScreen.dart'; // 메인 화면이 WelcomeScreen으로 시작하므로 주석 처리

void main() async {
  print("1. main() 함수 시작");

  try {
    // 1. Flutter 엔진이 위젯과 채널을 준비할 때까지 대기
    WidgetsFlutterBinding.ensureInitialized();
    print("2. WidgetsFlutterBinding 초기화 완료");

    // 2. Firebase 프로젝트를 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("3. Firebase.initializeApp 성공!"); // <--- 이 메시지가 뜨는지 반드시 확인

    runApp(const MyApp());
    print("4. runApp 호출 완료");

  } catch (e) {
    // 초기화 실패 시 모든 Firebase 기능이 작동하지 않습니다.
    print("🚨🚨🚨 FATAL ERROR: Firebase 초기화 실패! 🚨🚨🚨");
    print("오류 내용: $e");
    // 초기화 실패 시에도 앱이 멈추지 않도록 에러 화면을 띄웁니다.
    runApp(ErrorApp(errorMessage: "Firebase 초기화 실패: $e"));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'APG App',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),

      home: const WelcomeScreen(),
    );
  }
}

// 초기화 실패 시 보여줄 임시 에러 화면
class ErrorApp extends StatelessWidget {
  final String errorMessage;
  const ErrorApp({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "앱 오류 발생: ${errorMessage}\n\n[해결 방법]\n1. 'flutter clean' 실행\n2. 'flutter pub get' 실행\n3. 'flutter run' 재시도",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

// 고객님께서 제공해주신 WelcomeScreen 위젯 (로그인 화면으로 이동 로직 추가)
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 상단 여백 확보
              const Spacer(flex: 2),

              // 1. 중앙 알약 아이콘
              Transform.rotate(
                angle: -0.5, // 회전 각도 (취향에 따라 조절: -0.5 ~ -0.7 추천)
                child: Image.asset(
                  'assets/image/pill_icon.png', // 1. 여기에 이미지 파일 경로
                  width: 150, // 2. 이미지 크기 (조절 가능)
                  height: 150,
                  fit: BoxFit.contain, // 비율 유지하면서 크기 맞춤

                  // [중요] 혹시라도 이미지가 안 뜰 경우를 대비한 안전장치 (기존 아이콘 보여줌)
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(width: 4)
                      ),
                      child: const Icon(Icons.medication, size: 100, color: Color(0xFFFFC107)),
                    );
                  },
                ),
              ),

              const SizedBox(height: 40), // 아래 여백
              // 2. 슬로건 텍스트
              const Text(
                "약챙기고 ah~pill good~!",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFA93226), // 붉은 갈색 텍스트
                ),
              ),

              const Spacer(flex: 2),

              // 3. 로그인 버튼
              SizedBox(
                width: double.infinity, // 가로 꽉 채우기
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    // [핵심] 로그인 버튼 클릭 시 LoginScreen으로 이동
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C), // 짙은 빨간색 배경
                    foregroundColor: Colors.white, // 글자색
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8), // 둥근 모서리
                    ),
                  ),
                  child: const Text(
                    "로그인",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 4. 하단 로고 (APG)
              const Text(
                "APG",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFA93226), // 붉은 갈색
                ),
              ),

              const SizedBox(height: 20), // 하단 안전 여백
            ],
          ),
        ),
      ),
    );
  }
}