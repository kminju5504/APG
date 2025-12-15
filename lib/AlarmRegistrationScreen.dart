import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'alarm_service.dart';

class AlarmRegistrationScreen extends StatefulWidget {
  const AlarmRegistrationScreen({super.key});

  @override
  State<AlarmRegistrationScreen> createState() => _AlarmRegistrationScreenState();
}

class _AlarmRegistrationScreenState extends State<AlarmRegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();

  String _selectedCycle = "매일";
  String _selectedSnooze = "사용 안 함";
  
  // 🆕 약통 슬롯 선택 (1, 2, 3번)
  int _selectedSlot = 1;

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _pickCycle() {
    showModalBottomSheet(
      context: context,
      builder: (_) => _buildSelectSheet(
        title: "주기 선택",
        selected: _selectedCycle,
        options: ["매일", "평일", "주말", "월수금", "화목토", "한 번만"],
        onSelect: (value) {
          setState(() => _selectedCycle = value);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _pickSnooze() {
    showModalBottomSheet(
      context: context,
      builder: (_) => _buildSelectSheet(
        title: "다시 알림",
        selected: _selectedSnooze,
        options: ["사용 안 함", "5분 후", "10분 후", "30분 후"],
        onSelect: (value) {
          setState(() => _selectedSnooze = value);
          Navigator.pop(context);
        },
      ),
    );
  }

  // 🆕 약통 슬롯 선택
  void _pickSlot() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        height: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "약통 칸 선택",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "약을 넣을 약통 칸을 선택하세요",
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const Divider(),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSlotButton(1),
                  _buildSlotButton(2),
                  _buildSlotButton(3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotButton(int slotNumber) {
    final isSelected = _selectedSlot == slotNumber;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedSlot = slotNumber);
        Navigator.pop(context);
      },
      child: Container(
        width: 90,
        height: 120,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD32F2F) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFD32F2F) : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFD32F2F).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication,
              size: 40,
              color: isSelected ? Colors.white : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              "$slotNumber번 칸",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  // 저장 함수
  Future<void> _saveAlarm() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('약 이름을 입력해주세요!')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 고유 알람 ID 생성
      final alarmId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Firestore에 저장 (슬롯 정보 포함!)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('alarms')
          .add({
        'alarmId': alarmId,
        'drugName': _nameController.text,
        'hour': _selectedTime.hour,
        'minute': _selectedTime.minute,
        'cycle': _selectedCycle,
        'snooze': _selectedSnooze,
        'slotNumber': _selectedSlot,  // 🆕 약통 슬롯 번호!
        'isTaken': false,             // 🆕 복용 여부
        'lastTakenDate': null,        // 🆕 마지막 복용 날짜
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 알림 예약 (+ 10분 후 재알림도 함께 예약!)
      await AlarmService.scheduleAlarm(
        id: alarmId,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        title: "💊 약 복용 시간입니다",
        body: "${_nameController.text} - $_selectedSlot번 약통에서 꺼내 드세요!",
        slotNumber: _selectedSlot,  // 🆕 슬롯 번호 전달 → 10분 후 재알림 예약됨!
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_nameController.text} 알림이 $_selectedSlot번 약통에 등록되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print("에러 발생: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장 실패 ㅠㅠ'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildSelectSheet({
    required String title,
    required String selected,
    required List<String> options,
    required Function(String) onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 350,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (_, index) {
                final option = options[index];
                return ListTile(
                  title: Text(option),
                  trailing: option == selected
                      ? const Icon(Icons.check, color: Colors.red)
                      : null,
                  onTap: () => onSelect(option),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String timeString =
        "${_selectedTime.period == DayPeriod.am ? '오전' : '오후'} ${_selectedTime.hourOfPeriod}:${_selectedTime.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD32F2F),
        centerTitle: true,
        title: const Text('APG', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("알리미 등록",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),

            // 약 이름 입력
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: "등록할 약 이름 :",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // 🆕 약통 슬롯 선택 (강조!)
            GestureDetector(
              onTap: _pickSlot,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD32F2F), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.medication, color: Color(0xFFD32F2F)),
                        const SizedBox(width: 10),
                        const Text(
                          "약통 칸 선택",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD32F2F),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "$_selectedSlot번 칸",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // 시간 입력
            GestureDetector(
              onTap: _pickTime,
              child: _buildMenuItem("시간 입력", highlightText: timeString),
            ),
            const SizedBox(height: 10),

            // 주기 설정
            GestureDetector(
              onTap: _pickCycle,
              child: _buildMenuItem("주기 설정", highlightText: _selectedCycle),
            ),
            const SizedBox(height: 10),

            // 다시 알림
            GestureDetector(
              onTap: _pickSnooze,
              child: _buildMenuItem("다시 알림", highlightText: _selectedSnooze),
            ),

            const SizedBox(height: 30),

            // 등록 미리보기
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "💊 ${_nameController.text.isEmpty ? '약 이름' : _nameController.text}\n"
                      "⏰ $timeString $_selectedCycle\n"
                      "📦 $_selectedSlot번 약통에 넣어주세요!",
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // 등록 버튼
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saveAlarm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  "등록 완료하기",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title, {String? highlightText}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Row(
            children: [
              if (highlightText != null)
                Text(
                  highlightText,
                  style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold),
                ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }
}
