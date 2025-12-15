import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// ESP32 약통 제어 화면 (센서 데이터 표시)
class DeviceControlScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceControlScreen({super.key, required this.device});

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  // ============================================================
  // 🔧 ESP32 UUID (Nordic UART Service)
  // ============================================================
  static const String SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  static const String CHAR_TX_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";

  // BLE 특성
  BluetoothCharacteristic? _txCharacteristic;
  
  // 연결 상태
  bool _isConnected = true;
  bool _isLoading = true;
  
  // 약통 슬롯 상태 (3칸)
  List<SlotStatus> _slots = [
    SlotStatus(slotNumber: 1),
    SlotStatus(slotNumber: 2),
    SlotStatus(slotNumber: 3),
  ];
  
  // 수신 로그
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  
  // 구독
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _notifySubscription;

  @override
  void initState() {
    super.initState();
    _setupConnection();
  }

  /// 연결 설정 및 서비스 탐색
  Future<void> _setupConnection() async {
    _connectionSubscription = widget.device.connectionState.listen((state) {
      setState(() {
        _isConnected = (state == BluetoothConnectionState.connected);
      });
      
      if (!_isConnected && mounted) {
        _addLog("⚠️ 연결이 끊어졌습니다");
      }
    });

    await _discoverServices();
  }

  /// 서비스 및 특성 탐색
  Future<void> _discoverServices() async {
    try {
      _addLog("🔍 서비스 탐색 중...");
      
      List<BluetoothService> services = await widget.device.discoverServices();
      
      for (var service in services) {
        _addLog("📦 서비스: ${service.uuid}");
        
        // Nordic UART Service 찾기
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID) {
          _addLog("✅ APG Pillbox 서비스 발견!");
          
          for (var char in service.characteristics) {
            _addLog("  📝 특성: ${char.uuid}");
            
            // TX 특성 (ESP32 → 앱, Notify)
            if (char.uuid.toString().toLowerCase() == CHAR_TX_UUID) {
              _txCharacteristic = char;
              await _setupNotification(char);
              _addLog("✅ 데이터 수신 준비 완료!");
            }
          }
        }
      }

      // 서비스를 못 찾은 경우 - 모든 Notify 특성 시도
      if (_txCharacteristic == null) {
        _addLog("⚠️ 지정된 서비스 없음, 범용 탐색...");
        for (var service in services) {
          for (var char in service.characteristics) {
            if (char.properties.notify && _txCharacteristic == null) {
              _txCharacteristic = char;
              await _setupNotification(char);
              _addLog("📝 범용 Notify 특성 사용: ${char.uuid}");
            }
          }
        }
      }

      setState(() {
        _isLoading = false;
      });

      if (_txCharacteristic != null) {
        _addLog("✅ ESP32 연결 완료! 데이터 수신 대기중...");
      } else {
        _addLog("❌ Notify 특성을 찾지 못했습니다");
      }
    } catch (e) {
      _addLog("❌ 서비스 탐색 실패: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 알림(Notification) 설정 - ESP32에서 데이터 수신
  Future<void> _setupNotification(BluetoothCharacteristic char) async {
    try {
      await char.setNotifyValue(true);
      
      _notifySubscription = char.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          String data = utf8.decode(value, allowMalformed: true).trim();
          _addLog("📩 $data");
          _parseESP32Data(data);
        }
      });
      
    } catch (e) {
      _addLog("⚠️ 알림 설정 실패: $e");
    }
  }

  /// ESP32 데이터 파싱
  /// 형식: "1:present,closed;2:empty,open;3:present,closed"
  void _parseESP32Data(String data) {
    try {
      // 세미콜론으로 슬롯 분리
      List<String> slotData = data.split(';');
      
      for (var slot in slotData) {
        // "1:present,closed" 형식 파싱
        var parts = slot.split(':');
        if (parts.length == 2) {
          int slotNum = int.tryParse(parts[0]) ?? 0;
          var values = parts[1].split(',');
          
          if (slotNum >= 1 && slotNum <= 3 && values.length == 2) {
            setState(() {
              _slots[slotNum - 1] = SlotStatus(
                slotNumber: slotNum,
                hasPill: values[0].trim() == "present",
                isLidClosed: values[1].trim() == "closed",
              );
            });
          }
        }
      }
    } catch (e) {
      _addLog("⚠️ 데이터 파싱 오류: $e");
    }
  }

  /// 로그 추가
  void _addLog(String message) {
    setState(() {
      _logs.add("[${DateTime.now().toString().substring(11, 19)}] $message");
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _notifySubscription?.cancel();
    _scrollController.dispose();
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        title: Text(
          widget.device.platformName.isNotEmpty 
              ? widget.device.platformName 
              : "APG Pillbox",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.greenAccent : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? "연결됨" : "끊김",
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFB71C1C)),
                  SizedBox(height: 20),
                  Text("ESP32 연결 중...", style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : Column(
              children: [
                // 약통 슬롯 상태 표시
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        const Text(
                          "💊 약통 상태",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // 3개의 슬롯 카드
                        Expanded(
                          child: Row(
                            children: _slots.map((slot) => 
                              Expanded(child: _buildSlotCard(slot))
                            ).toList(),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // 범례
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildLegendItem(Icons.medication, Colors.green, "약 있음"),
                              _buildLegendItem(Icons.medication_outlined, Colors.grey, "약 없음"),
                              _buildLegendItem(Icons.lock, Colors.blue, "뚜껑 닫힘"),
                              _buildLegendItem(Icons.lock_open, Colors.orange, "뚜껑 열림"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // 통신 로그
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "📡 ESP32 데이터 로그",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, 
                                    color: Colors.white54, size: 20),
                                onPressed: () => setState(() => _logs.clear()),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  _logs[index],
                                  style: TextStyle(
                                    color: _logs[index].contains("❌") 
                                        ? Colors.redAccent 
                                        : _logs[index].contains("✅")
                                            ? Colors.greenAccent
                                            : _logs[index].contains("📩")
                                                ? Colors.cyanAccent
                                                : Colors.white70,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// 슬롯 카드 위젯
  Widget _buildSlotCard(SlotStatus slot) {
    return Card(
      margin: const EdgeInsets.all(6),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: slot.hasPill 
                ? [Colors.green.shade50, Colors.green.shade100]
                : [Colors.grey.shade100, Colors.grey.shade200],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 슬롯 번호
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFB71C1C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${slot.slotNumber}칸",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 약 아이콘
            Icon(
              slot.hasPill ? Icons.medication : Icons.medication_outlined,
              size: 50,
              color: slot.hasPill ? Colors.green : Colors.grey,
            ),
            
            const SizedBox(height: 8),
            
            Text(
              slot.hasPill ? "약 있음" : "비어있음",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: slot.hasPill ? Colors.green[700] : Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 뚜껑 상태
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  slot.isLidClosed ? Icons.lock : Icons.lock_open,
                  size: 20,
                  color: slot.isLidClosed ? Colors.blue : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  slot.isLidClosed ? "닫힘" : "열림",
                  style: TextStyle(
                    fontSize: 12,
                    color: slot.isLidClosed ? Colors.blue : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 범례 아이템
  Widget _buildLegendItem(IconData icon, Color color, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      ],
    );
  }
}

/// 약통 슬롯 상태 모델
class SlotStatus {
  final int slotNumber;
  final bool hasPill;      // 약 유무 (IR 센서)
  final bool isLidClosed;  // 뚜껑 상태 (리드 스위치)

  SlotStatus({
    required this.slotNumber,
    this.hasPill = false,
    this.isLidClosed = true,
  });
}
