import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'alarm_service.dart';

class AlarmListScreen extends StatelessWidget {
  const AlarmListScreen({super.key});

  // 삭제 기능
  void _deleteAlarm(BuildContext context, String docId, int? alarmId, int slotNumber) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("삭제 확인"),
        content: const Text("정말 이 알림을 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                // Firestore에서 삭제
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('alarms')
                    .doc(docId)
                    .delete();

                // 예약된 알람도 취소
                if (alarmId != null) {
                  await AlarmService.cancelAlarm(alarmId);
                }

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

  // 슬롯 색상
  Color _getSlotColor(int slot) {
    switch (slot) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.orange;
      default:
        return Colors.grey;
    }
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
              "💊 알리미 목록",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),

          // 슬롯별 범례
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildSlotLegend(1, Colors.blue),
                const SizedBox(width: 12),
                _buildSlotLegend(2, Colors.green),
                const SizedBox(width: 12),
                _buildSlotLegend(3, Colors.orange),
              ],
            ),
          ),
          const SizedBox(height: 10),

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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.alarm_off, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text("등록된 알림이 없습니다."),
                        const SizedBox(height: 8),
                        Text(
                          "알림등록 탭에서 약 알림을 추가하세요",
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var alarm = doc.data() as Map<String, dynamic>;
                    String docId = doc.id;

                    String drugName = alarm['drugName'] ?? '약 이름 없음';
                    int hour = alarm['hour'] ?? 0;
                    int minute = alarm['minute'] ?? 0;
                    int slotNumber = alarm['slotNumber'] ?? 0;  // 🆕 슬롯 번호
                    int? alarmId = alarm['alarmId'];
                    String cycle = alarm['cycle'] ?? '매일';
                    bool isTaken = alarm['isTaken'] ?? false;

                    String amPm = hour < 12 ? '오전' : '오후';
                    int displayHour = hour > 12 ? hour - 12 : hour;
                    if (displayHour == 0) displayHour = 12;
                    String minStr = minute.toString().padLeft(2, '0');

                    Color slotColor = _getSlotColor(slotNumber);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                        // 왼쪽에 슬롯 색상 바
                        border: Border(
                          left: BorderSide(
                            color: slotColor,
                            width: 4,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // 슬롯 번호 아이콘
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: slotColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.medication, color: slotColor, size: 24),
                                  Text(
                                    "$slotNumber번",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: slotColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // 약 정보
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          drugName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // 복용 상태 뱃지
                                      if (isTaken)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Text(
                                            "복용완료",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        "$cycle $amPm $displayHour:$minStr",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.inventory_2_outlined, size: 16, color: slotColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        "$slotNumber번 약통에 보관",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: slotColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // 삭제 버튼
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteAlarm(context, docId, alarmId, slotNumber),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildSlotLegend(int slot, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            "$slot번 칸",
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
