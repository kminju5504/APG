import 'package:flutter/material.dart';
import 'dart:developer';
import 'mainpage.dart';
import 'AlarmRegistrationScreen.dart';
import 'AlarmListScreen.dart';       // import는 잘 되어있음
import 'SmartPillboxScreen.dart';    // import는 잘 되어있음

// PlaceholderScreen 클래스는 이제 안 쓰지만, 혹시 모르니 남겨둡니다.
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: const TextStyle(fontSize: 24, color: Colors.grey)),
    );
  }
}

class TabbarPage extends StatefulWidget {
  const TabbarPage({super.key});

  @override
  State<TabbarPage> createState() => _TabbarPageState();
}

class _TabbarPageState extends State<TabbarPage> {
  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();

    // ▼▼▼ [여기가 문제였습니다! 이렇게 고치세요] ▼▼▼
    _widgetOptions = <Widget>[
      // 0. Home
      MainPage(onTabSelected: _onItemTapped),

      // 1. 알림 등록 (버튼 누르면 화면 이동하므로, 탭 자체는 빈 화면 둬도 됨)
      const PlaceholderScreen(title: '알림 등록 탭'),

      // 2. [수정됨] 복용 목록 -> AlarmListScreen 연결!
      const AlarmListScreen(),

      // 3. [수정됨] 약통 등록 -> SmartPillboxScreen 연결!
      const SmartPillboxScreen(),
    ];
  }

  void _onItemTapped(int index) {
    log("탭 선택됨: Index $index", name: 'UI_EVENT');

    // 알림 등록(Index 1)은 탭 이동이 아니라 '화면 띄우기'
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AlarmRegistrationScreen(),
        ),
      );
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 상단 바 (AppBar)
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('APG', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 15.0),
            child: Icon(Icons.notifications_none, size: 28),
          ),
        ],
      ),

      // 선택된 탭의 화면 보여주기
      body: _widgetOptions.elementAt(_selectedIndex),

      // 하단 탭바
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: '알림등록'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '복용목록'),
          BottomNavigationBarItem(icon: Icon(Icons.person_pin_outlined), label: '약통등록'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFB71C1C),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}