import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // DB 사용
import 'package:firebase_auth/firebase_auth.dart';     // 사용자 정보 사용
import 'AlarmRegistrationScreen.dart'; // 등록 화면 파일
import 'AlarmListScreen.dart';         // 방금 만든 목록 화면 파일

class MainPage extends StatelessWidget {
  final Function(int)? onTabSelected;

  const MainPage({super.key, this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // 1. 로그인이 안 되어 있으면 -> 그냥 빈 화면 보여주기
    if (user == null) {
      return _buildEmptyState(context);
    }

    // 2. 파이어베이스 감시 시작! (데이터가 변하면 화면도 바뀜)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('alarms')
          .snapshots(),
      builder: (context, snapshot) {
        // 로딩 중이면 뱅글뱅글
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
        }

        // 3. [중요] 데이터가 있으면 -> 목록 화면(AlarmListScreen)을 보여줌!
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          return const AlarmListScreen();
        }

        // 4. 데이터가 없으면 -> 빈 화면(알약 아이콘 + 버튼)을 보여줌
        return _buildEmptyState(context);
      },
    );
  }

  // [빈 화면 디자인] 데이터가 없을 때 보여줄 화면 (알약 아이콘 + 알림 등록 버튼)
  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 알약 이미지
              Transform.rotate(
                angle: -0.5,
                child: Image.asset(
                  'assets/image/pill_icon.png',
                  width: 100,
                  height: 100,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.medication, size: 100, color: Color(0xFFFFD600));
                  },
                ),
              ),
              const SizedBox(height: 40),

              // 안내 멘트
              const Text(
                "복용 시간을 놓치지 않게\n나만을 위한 알림을 설정해 드립니다.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.5),
              ),
              const SizedBox(height: 20),
              const Text("아래 버튼을 터치하신 후 알림을 등록하세요.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 60),

              // 알림 등록 버튼
              SizedBox(
                width: 160,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    // 버튼 누르면 등록 화면으로 이동
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AlarmRegistrationScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  ),
                  child: const Text("알림 등록", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}