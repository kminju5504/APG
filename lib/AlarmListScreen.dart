import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlarmListScreen extends StatelessWidget {
  const AlarmListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // 배경색 (연한 회색)
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 제목
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              "알리미 목록",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87
              ),
            ),
          ),

          // 파이어베이스 데이터 가져오기
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('alarms')
                  .orderBy('createdAt', descending: true) // 최신순 정렬
                  .snapshots(),
              builder: (context, snapshot) {
                // 데이터가 로딩 중일 때
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 혹시 데이터가 비었을 때 (MainPage에서 처리하지만 혹시 몰라 추가)
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("등록된 알림이 없습니다."));
                }

                final alarms = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: alarms.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    var alarm = alarms[index];
                    String drugName = alarm['drugName'];
                    int hour = alarm['hour'];
                    int minute = alarm['minute'];

                    // 시간 예쁘게 표시하기 (오전/오후)
                    String amPm = hour < 12 ? '오전' : '오후';
                    int displayHour = hour > 12 ? hour - 12 : hour;
                    if (displayHour == 0) displayHour = 12;
                    String minStr = minute.toString().padLeft(2, '0');

                    // 리스트 카드 디자인
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // [왼쪽] 시계 아이콘
                          Column(
                            children: [
                              const Icon(Icons.access_alarm, color: Color(0xFFD32F2F), size: 35),
                              const SizedBox(height: 4),
                              const Text("알리미 끄기", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(width: 20),

                          // [오른쪽] 약 정보 텍스트
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "아침  -  $drugName", // 예시로 '아침' 고정
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "🕒 알림 시간 : 매일 $amPm $displayHour : $minStr",
                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}