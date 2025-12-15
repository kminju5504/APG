import 'dart:async';
import 'package:flutter/material.dart';
import 'BluetoothScanScreen.dart';
import 'pillbox_status_screen.dart';
import 'pillbox_firebase_service.dart';
import 'bluetooth_manager.dart';

class SmartPillboxScreen extends StatefulWidget {
  const SmartPillboxScreen({super.key});

  @override
  State<SmartPillboxScreen> createState() => _SmartPillboxScreenState();
}

class _SmartPillboxScreenState extends State<SmartPillboxScreen> {
  final BluetoothManager _bluetoothManager = BluetoothManager();
  final PillboxFirebaseService _firebaseService = PillboxFirebaseService();
  
  bool _isConnected = false;
  String? _connectedDeviceName;
  List<PillboxSlot> _slots = [];
  
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _slotSubscription;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  void _initServices() {
    // BLE 연결 상태
    _isConnected = _bluetoothManager.isConnected;
    _connectionSubscription = _bluetoothManager.connectionStream.listen((connected) {
      setState(() {
        _isConnected = connected;
      });
    });

    // 저장된 기기 이름 가져오기
    _loadDeviceName();

    // Firebase 구독 시작
    _firebaseService.startListening();
    _slotSubscription = _firebaseService.slotStream.listen((slots) {
      setState(() {
        _slots = slots;
      });
    });

    // 초기 데이터 로드
    _loadFirebaseData();
  }

  Future<void> _loadDeviceName() async {
    _connectedDeviceName = await _bluetoothManager.getSavedDeviceName();
    setState(() {});
  }

  Future<void> _loadFirebaseData() async {
    final slots = await _firebaseService.getAllSlots();
    if (slots.isNotEmpty) {
      setState(() {
        _slots = slots;
      });
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _slotSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 연결되어 있으면 상태 화면 표시
    if (_isConnected || _slots.isNotEmpty) {
      return _buildConnectedView();
    }
    
    // 연결 안 되어 있으면 연결 안내 화면
    return _buildDisconnectedView();
  }

  /// 연결됨 - 약통 상태 표시
  Widget _buildConnectedView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 연결 상태 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bluetooth_connected, 
                          color: Colors.green, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _connectedDeviceName ?? "APG 스마트 약통",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _isConnected ? Colors.green : Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isConnected ? "BLE 연결됨" : "Firebase 연결됨",
                                style: TextStyle(
                                  color: _isConnected ? Colors.green : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 상세보기 버튼
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PillboxStatusScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 간단한 슬롯 상태
            if (_slots.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "💊 약통 현재 상태",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              
              // 3개 슬롯 가로로
              Row(
                children: _slots.map((slot) => Expanded(
                  child: _buildMiniSlotCard(slot),
                )).toList(),
              ),
              
              const SizedBox(height: 16),
              
              // 상세보기 버튼
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PillboxStatusScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text("상세 상태 보기"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB71C1C),
                    side: const BorderSide(color: Color(0xFFB71C1C)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // 다른 기기 연결 버튼
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BluetoothScanScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text("다른 약통 연결하기"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 미니 슬롯 카드
  Widget _buildMiniSlotCard(PillboxSlot slot) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: slot.hasPill ? Colors.green.shade50 : Colors.orange.shade50,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFB71C1C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${slot.slotNumber}칸",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Icon(
              slot.hasPill ? Icons.medication : Icons.medication_outlined,
              color: slot.hasPill ? Colors.green : Colors.orange,
              size: 30,
            ),
            const SizedBox(height: 4),
            Text(
              slot.hasPill ? "약 있음" : "비어있음",
              style: TextStyle(
                fontSize: 11,
                color: slot.hasPill ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  slot.isLidClosed ? Icons.lock : Icons.lock_open,
                  size: 14,
                  color: slot.isLidClosed ? Colors.blue : Colors.orange,
                ),
                Text(
                  slot.isLidClosed ? "닫힘" : "열림",
                  style: TextStyle(
                    fontSize: 10,
                    color: slot.isLidClosed ? Colors.blue : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 연결 안 됨 - 연결 안내 화면
  Widget _buildDisconnectedView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 알약 아이콘
            Transform.rotate(
              angle: -0.5,
              child: Image.asset(
                'assets/image/pill_icon.png',
                width: 100,
                height: 100,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.medication, 
                      size: 100, color: Color(0xFFFFD600));
                },
              ),
            ),
            const SizedBox(height: 30),

            // 안내 텍스트
            const Text(
              "블루투스 약통 연결",
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 15),
            const Text(
              "약통의 전원을 켜고\n아래 버튼을 터치하여 연결하세요.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 50),

            // [스마트약통 연결] 버튼
            SizedBox(
              width: 180,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const BluetoothScanScreen()),
                  );
                },
                icon: const Icon(Icons.bluetooth, color: Colors.white),
                label: const Text(
                  "약통 연결하기",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Firebase만 연결된 경우 안내
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "ESP32가 WiFi에 연결되면\nFirebase로 실시간 데이터를 받을 수 있어요.",
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
