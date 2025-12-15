import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'alarm_service.dart';

/// 알람 기록 화면
class AlarmHistoryScreen extends StatefulWidget {
  const AlarmHistoryScreen({super.key});

  @override
  State<AlarmHistoryScreen> createState() => _AlarmHistoryScreenState();
}

class _AlarmHistoryScreenState extends State<AlarmHistoryScreen> {
  List<AlarmHistory> _histories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistories();
  }

  Future<void> _loadHistories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('alarm_history')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      setState(() {
        _histories = snapshot.docs.map((doc) {
          final data = doc.data();
          return AlarmHistory(
            id: doc.id,
            type: data['type'] ?? 'alarm',
            title: data['title'] ?? '알람',
            message: data['message'] ?? '',
            slotNumber: data['slotNumber'] ?? 0,
            timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            isTaken: data['isTaken'] ?? false,
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print("알람 기록 로드 실패: $e");
      setState(() => _isLoading = false);
    }
  }

  /// 🗑️ 전체 삭제 + 배지 초기화
  Future<void> _clearAllHistories() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("전체 삭제"),
        content: const Text("모든 알람 기록을 삭제하고\n앱 아이콘 배지도 초기화할까요?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("삭제", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      
      // 알람 기록 삭제 + 배지 초기화
      await AlarmService.clearAllAlarmHistory();
      await AlarmService.clearBadge();
      
      setState(() {
        _histories = [];
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모든 알람 기록이 삭제되었습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD32F2F),
        title: const Text('알람 기록', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // 🗑️ 전체 삭제 + 배지 초기화 버튼
          if (_histories.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              tooltip: '전체 삭제 및 배지 초기화',
              onPressed: _clearAllHistories,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
          : _histories.isEmpty
              ? _buildEmptyState()
              : _buildHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "알람 기록이 없습니다",
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            "알람이 울리면 여기에 기록됩니다",
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    // 날짜별로 그룹화
    Map<String, List<AlarmHistory>> grouped = {};
    for (var history in _histories) {
      final dateKey = "${history.timestamp.year}-${history.timestamp.month.toString().padLeft(2, '0')}-${history.timestamp.day.toString().padLeft(2, '0')}";
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(history);
    }

    return RefreshIndicator(
      onRefresh: _loadHistories,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: grouped.keys.length,
        itemBuilder: (context, index) {
          final dateKey = grouped.keys.elementAt(index);
          final items = grouped[dateKey]!;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 날짜 헤더
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _formatDateHeader(dateKey),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFFD32F2F),
                  ),
                ),
              ),
              // 해당 날짜의 알람들
              ...items.map((history) => _buildHistoryCard(history)),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  String _formatDateHeader(String dateKey) {
    final parts = dateKey.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return "오늘";
    } else if (date == yesterday) {
      return "어제";
    } else {
      return "${date.month}월 ${date.day}일";
    }
  }

  Widget _buildHistoryCard(AlarmHistory history) {
    IconData icon;
    Color iconColor;

    switch (history.type) {
      case 'taken':
        icon = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case 'reminder':
        icon = Icons.notifications_active;
        iconColor = Colors.orange;
        break;
      case 'missed':
        icon = Icons.warning;
        iconColor = Colors.red;
        break;
      default:
        icon = Icons.notifications;
        iconColor = const Color(0xFFD32F2F);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          history.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(history.message),
            const SizedBox(height: 4),
            Text(
              "${history.timestamp.hour.toString().padLeft(2, '0')}:${history.timestamp.minute.toString().padLeft(2, '0')}",
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        trailing: history.slotNumber > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${history.slotNumber}번",
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              )
            : null,
      ),
    );
  }
}

class AlarmHistory {
  final String id;
  final String type;  // 'alarm', 'taken', 'reminder', 'missed'
  final String title;
  final String message;
  final int slotNumber;
  final DateTime timestamp;
  final bool isTaken;

  AlarmHistory({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.slotNumber,
    required this.timestamp,
    required this.isTaken,
  });
}

