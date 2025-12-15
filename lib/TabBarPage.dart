import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'mainpage.dart';
import 'AlarmRegistrationScreen.dart';
import 'AlarmListScreen.dart';
import 'SmartPillboxScreen.dart';
import 'pillbox_status_screen.dart';
import 'login_screen.dart';
import 'bluetooth_manager.dart';
import 'alarm_history_screen.dart';

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
  
  final BluetoothManager _bluetoothManager = BluetoothManager();
  bool _isBluetoothConnected = false;
  String? _connectedDeviceName;
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();

    // 5개 탭 화면
    _widgetOptions = <Widget>[
      // 0. Home
      MainPage(onTabSelected: _onItemTapped),
      
      // 1. 알림 등록 (버튼 누르면 화면 이동)
      const PlaceholderScreen(title: '알림 등록 탭'),
      
      // 2. 🆕 약통 상태 (실시간 모니터링)
      const PillboxStatusScreen(),
      
      // 3. 복용 목록
      const AlarmListScreen(),
      
      // 4. 약통 연결
      const SmartPillboxScreen(),
    ];

    // 블루투스 연결 상태 모니터링
    _connectionSubscription = _bluetoothManager.connectionStream.listen((isConnected) {
      setState(() {
        _isBluetoothConnected = isConnected;
      });
    });

    _checkBluetoothStatus();
  }

  Future<void> _checkBluetoothStatus() async {
    _isBluetoothConnected = _bluetoothManager.isConnected;
    _connectedDeviceName = await _bluetoothManager.getSavedDeviceName();
    setState(() {});
  }

  // 🔌 블루투스 연결 해제
  Future<void> _disconnectBluetooth() async {
    final shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('블루투스 연결 해제'),
        content: Text('${_connectedDeviceName ?? "약통"}과의 연결을 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('연결 해제', style: TextStyle(color: Color(0xFFD32F2F))),
          ),
        ],
      ),
    );

    if (shouldDisconnect == true) {
      await _bluetoothManager.disconnect();
      setState(() {
        _isBluetoothConnected = false;
        _connectedDeviceName = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('블루투스 연결이 해제되었습니다.')),
        );
      }
    }
  }

  // 🔓 로그아웃 함수
  Future<void> _signOut() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃', style: TextStyle(color: Color(0xFFD32F2F))),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        await FirebaseAuth.instance.signOut();
        log("로그아웃 성공", name: 'AUTH');

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        log("로그아웃 실패: $e", name: 'AUTH');
      }
    }
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
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('APG', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        
        // 왼쪽: 블루투스 연결 상태
        leading: _isBluetoothConnected
            ? IconButton(
                icon: const Icon(Icons.bluetooth_connected, color: Colors.greenAccent),
                tooltip: '블루투스 연결됨 (터치하여 해제)',
                onPressed: _disconnectBluetooth,
              )
            : IconButton(
                icon: const Icon(Icons.bluetooth_disabled, color: Colors.white54),
                tooltip: '블루투스 연결 안됨',
                onPressed: () {
                  setState(() {
                    _selectedIndex = 4; // 약통연결 탭으로 이동
                  });
                },
              ),
        
        actions: [
          // 블루투스 상태 텍스트
          if (_isBluetoothConnected)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "연결됨",
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // 📋 알람 기록 버튼
          IconButton(
            icon: const Icon(Icons.history, size: 26),
            tooltip: '알람 기록',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AlarmHistoryScreen()),
              );
            },
          ),
          
          // 로그아웃 버튼
          IconButton(
            icon: const Icon(Icons.logout, size: 26),
            tooltip: '로그아웃',
            onPressed: _signOut,
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: _widgetOptions.elementAt(_selectedIndex),

      // 5개 탭 바
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          // 0. Home
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          
          // 1. 알림등록
          const BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: '알림등록',
          ),
          
          // 2. 🆕 약통상태 (연결 시 초록 점)
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.monitor_heart),
                if (_isBluetoothConnected)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            label: '약통상태',
          ),
          
          // 3. 복용목록
          const BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: '복용목록',
          ),
          
          // 4. 약통연결
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.bluetooth),
                if (_isBluetoothConnected)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            label: '약통연결',
          ),
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
