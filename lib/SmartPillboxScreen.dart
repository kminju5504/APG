import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart'; // 로그아웃 시 이동할 화면
import 'BluetoothScanScreen.dart'; // 다음 화면(스캔 화면)

class SmartPillboxScreen extends StatelessWidget {
  const SmartPillboxScreen({super.key});

  // 로그아웃 함수
  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // 배경 연한 회색
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C), // 진한 빨강
        title: const Text('APG', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false, // 뒤로가기 없애기 (탭 화면이므로)
        actions: [
          TextButton(
            onPressed: () => _logout(context),
            child: const Text("로그아웃", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. 알약 아이콘
            Transform.rotate(
              angle: -0.5,
              child: Image.asset(
                'assets/image/pill_icon.png', // 이미지 경로 확인
                width: 100,
                height: 100,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.medication, size: 100, color: Color(0xFFFFD600));
                },
              ),
            ),
            const SizedBox(height: 30),

            // 2. 안내 텍스트
            const Text(
              "블루투스 약통 연결",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 15),
            const Text(
              "약통은 휴대폰과 근처에 두고\n아래 버튼을 터치하신 후 약통과 연결하세요.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 50),

            // 3. [스마트약통 연결] 버튼
            SizedBox(
              width: 180,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  // 버튼 누르면 스캔 화면으로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BluetoothScanScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFEF9A9A), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                ),
                child: const Text(
                  "스마트약통 연결",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}