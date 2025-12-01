import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlarmListScreen extends StatelessWidget {
  const AlarmListScreen({super.key});

  // [삭제 기능 함수]
  void _deleteAlarm(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("삭제 확인"),
        content: const Text("정말 이 알림을 삭제하시겠습니까?"),
        actions: [
          // 1. 취소 버튼
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),

          // 2. 삭제 버튼
          TextButton(
            onPressed: () async {
              // (1) 일단 팝업창부터 먼저 닫기! (반응 속도 UP)
              Navigator.of(ctx).pop();
              // (2) 그 다음 Firebase에서 삭제
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('alarms')
                    .doc(docId)
                    .delete();

                // (3) 삭제 다 되면 하단에 메시지 띄우기
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('삭제되었습니다.')),
                  );
                }
              }
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              "알리미 목록",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('alarms')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("등록된 알림이 없습니다."));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var alarm = doc.data() as Map<String, dynamic>;
                    String docId = doc.id; // 문서 ID

                    String drugName = alarm['drugName'] ?? '약 이름 없음';
                    int hour = alarm['hour'] ?? 0;
                    int minute = alarm['minute'] ?? 0;

                    String amPm = hour < 12 ? '오전' : '오후';
                    int displayHour = hour > 12 ? hour - 12 : hour;
                    if (displayHour == 0) displayHour = 12;
                    String minStr = minute.toString().padLeft(2, '0');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16), // 내부 여백
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, // 양 끝으로 벌리기
                        children: [
                          // [왼쪽 덩어리: 아이콘 + 텍스트]
                          Expanded(
                            child: Row(
                              children: [
                                // 시계 아이콘
                                Column(
                                  children: [
                                    const Icon(Icons.access_alarm, color: Color(0xFFD32F2F), size: 35),
                                    const SizedBox(height: 4),
                                    const Text("알리미", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(width: 16),

                                // 텍스트 정보
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "아침  -  $drugName",
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis, // 글자 길면 ... 처리
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "매일 $amPm $displayHour:$minStr",
                                        style: const TextStyle(fontSize: 15, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // [오른쪽 덩어리: 삭제 버튼]
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.red.shade50, // 연한 빨간 배경
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                _deleteAlarm(context, docId);
                              },
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