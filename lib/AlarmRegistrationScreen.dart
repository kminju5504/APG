import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 데이터베이스
import 'package:firebase_auth/firebase_auth.dart';     // 사용자 정보

class AlarmRegistrationScreen extends StatefulWidget {
  const AlarmRegistrationScreen({super.key});

  @override
  State<AlarmRegistrationScreen> createState() => _AlarmRegistrationScreenState();
}

class _AlarmRegistrationScreenState extends State<AlarmRegistrationScreen> {
  // 1. 입력값을 저장할 변수들
  final TextEditingController _nameController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now(); // 기본 시간: 현재 시간

  // 2. 시간 선택 함수 (시계 위젯 띄우기)
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

  // 3. 파이어베이스에 저장하는 함수
  Future<void> _saveAlarm() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('약 이름을 입력해주세요!')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 'users' -> '내UID' -> 'alarms' 라는 보관함에 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('alarms')
          .add({
        'drugName': _nameController.text, // 약 이름
        'hour': _selectedTime.hour,       // 시간 (시)
        'minute': _selectedTime.minute,   // 시간 (분)
        'cycle': '매일',                  // 주기는 일단 '매일'로 고정 (나중에 기능 추가 가능)
        'createdAt': FieldValue.serverTimestamp(), // 등록 시간
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('알림이 등록되었습니다!')));
      Navigator.pop(context); // 저장 후 뒤로 가기
    } catch (e) {
      print("에러 발생: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장 실패 ㅠㅠ')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 시간을 "오전 8:30" 형태로 변환
    final String timeString = "${_selectedTime.period == DayPeriod.am ? '오전' : '오후'} ${_selectedTime.hourOfPeriod}:${_selectedTime.minute.toString().padLeft(2, '0')}";

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
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text("알리미 등록", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),

              // 약 이름 입력
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: "등록할 약 이름 :",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 시간 입력 버튼 (누르면 시계 뜸)
              GestureDetector(
                onTap: _pickTime,
                child: _buildMenuItem("시간 입력", highlightText: timeString),
              ),
              const SizedBox(height: 10),

              // 주기 설정 (일단 모양만)
              _buildMenuItem("주기 설정", highlightText: "매일"),
              const SizedBox(height: 10),

              // 다시 알림 (일단 모양만)
              _buildMenuItem("다시 알림", highlightText: "사용 안 함"),

              const SizedBox(height: 60),

              // 등록 버튼
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _saveAlarm, // 저장 함수 실행
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("등록 완료하기", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 메뉴 아이템 위젯 (오른쪽에 선택된 값이 보이도록 수정함)
  Widget _buildMenuItem(String title, {String? highlightText}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Row(
            children: [
              if (highlightText != null)
                Text(highlightText, style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }
}