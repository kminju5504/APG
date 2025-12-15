import 'dart:async';
import 'package:flutter/material.dart';
import 'pillbox_firebase_service.dart';
import 'bluetooth_manager.dart';

/// 약통 실시간 상태 화면 (Firebase + BLE)
class PillboxStatusScreen extends StatefulWidget {
  const PillboxStatusScreen({super.key});

  @override
  State<PillboxStatusScreen> createState() => _PillboxStatusScreenState();
}

class _PillboxStatusScreenState extends State<PillboxStatusScreen> {
  final PillboxFirebaseService _firebaseService = PillboxFirebaseService();
  final BluetoothManager _bluetoothManager = BluetoothManager();
  
  List<PillboxSlot> _slots = [];
  bool _isBluetoothConnected = false;
  StreamSubscription? _firebaseSubscription;
  StreamSubscription? _bleSubscription;
  StreamSubscription? _pillTakenSubscription;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  void _initServices() {
    // Firebase 실시간 구독
    _firebaseService.startListening();
    _firebaseSubscription = _firebaseService.slotStream.listen((slots) {
      setState(() {
        _slots = slots;
      });
    });

    // 복용 감지 알림
    _pillTakenSubscription = _firebaseService.pillTakenStream.listen((slotNumber) {
      _showPillTakenNotification(slotNumber);
    });

    // BLE 연결 상태
    _isBluetoothConnected = _bluetoothManager.isConnected;
    _bleSubscription = _bluetoothManager.connectionStream.listen((connected) {
      setState(() {
        _isBluetoothConnected = connected;
      });
    });

    // 초기 데이터 로드
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final slots = await _firebaseService.getAllSlots();
    if (slots.isNotEmpty) {
      setState(() {
        _slots = slots;
      });
    }
  }

  void _showPillTakenNotification(int slotNumber) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Text("$slotNumber번 칸 약 복용 완료! 💊"),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _firebaseSubscription?.cancel();
    _bleSubscription?.cancel();
    _pillTakenSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _slots.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFB71C1C)),
                  SizedBox(height: 20),
                  Text("약통 데이터 로딩 중..."),
                  SizedBox(height: 10),
                  Text(
                    "ESP32가 WiFi에 연결되어 있어야 합니다",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 연결 상태 카드
                    _buildConnectionCard(),
                    
                    const SizedBox(height: 20),
                    
                    // 슬롯 상태 카드들
                    ..._slots.map((slot) => _buildSlotCard(slot)),
                    
                    const SizedBox(height: 20),
                    
                    // 범례
                    _buildLegend(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildConnectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFB71C1C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.medication, color: Color(0xFFB71C1C), size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "APG 스마트 약통",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildStatusChip(
                        "BLE",
                        _isBluetoothConnected,
                        Icons.bluetooth,
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(
                        "Firebase",
                        _slots.isNotEmpty,
                        Icons.cloud,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isConnected, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.grey,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isConnected ? Colors.green : Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isConnected ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(PillboxSlot slot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: slot.hasPill
                ? [Colors.green.shade50, Colors.green.shade100]
                : [Colors.orange.shade50, Colors.orange.shade100],
          ),
        ),
        child: Row(
          children: [
            // 슬롯 번호
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFB71C1C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  "${slot.slotNumber}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 상태 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${slot.slotNumber}번 칸",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // 약 상태
                      _buildStatusIcon(
                        slot.hasPill ? Icons.medication : Icons.medication_outlined,
                        slot.hasPill ? "약 있음" : "비어있음",
                        slot.hasPill ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 16),
                      // 뚜껑 상태
                      _buildStatusIcon(
                        slot.isLidClosed ? Icons.lock : Icons.lock_open,
                        slot.isLidClosed ? "닫힘" : "열림",
                        slot.isLidClosed ? Colors.blue : Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 마지막 복용 시간
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "마지막 복용",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        slot.lastTakenTime != null 
                            ? _formatLastTaken(slot.lastTakenTime!)
                            : "-",
                        style: TextStyle(
                          fontSize: slot.lastTakenTime != null ? 12 : 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFB71C1C),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (slot.takenNow)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "방금 복용!",
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "상태 안내",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(Icons.medication, Colors.green, "약 있음"),
                _buildLegendItem(Icons.medication_outlined, Colors.orange, "비어있음"),
                _buildLegendItem(Icons.lock, Colors.blue, "닫힘"),
                _buildLegendItem(Icons.lock_open, Colors.orange, "열림"),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "💡 복용 인정: 뚜껑 열림 상태에서 약이 감지되다가 사라지면 복용으로 인정됩니다.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      ],
    );
  }

  /// 마지막 복용 시간 포맷 (날짜 + 시간 줄바꿈)
  String _formatLastTaken(String dateTimeStr) {
    try {
      // 형식: "2025-12-07 14:30:00"
      final parts = dateTimeStr.split(' ');
      if (parts.length == 2) {
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');
        if (dateParts.length >= 3 && timeParts.length >= 2) {
          return "${dateParts[1]}/${dateParts[2]}\n${timeParts[0]}:${timeParts[1]}";
        }
      }
      return dateTimeStr;
    } catch (e) {
      return dateTimeStr;
    }
  }
}

