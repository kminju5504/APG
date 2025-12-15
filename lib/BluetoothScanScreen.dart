import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'bluetooth_manager.dart';
import 'TabBarPage.dart';

class BluetoothScanScreen extends StatefulWidget {
  const BluetoothScanScreen({super.key});

  @override
  State<BluetoothScanScreen> createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen> {
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _connectingDeviceId;

  // ESP32 기기 이름 필터
  static const List<String> ESP32_DEVICE_NAMES = [
    "APG Pillbox",
    "APG_Pillbox",
    "APG",
    "Pillbox",
    "ESP32",
  ];

  final BluetoothManager _bluetoothManager = BluetoothManager();

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    final adapterState = await FlutterBluePlus.adapterState.first;

    if (adapterState != BluetoothAdapterState.on) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('블루투스를 켜주세요!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    await _checkPermissionsAndScan();
  }

  Future<void> _checkPermissionsAndScan() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted) {
      _startScan();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('블루투스 권한을 허용해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
    });

    try {
      FlutterBluePlus.setLogLevel(LogLevel.warning);

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      print("❌ 스캔 에러: $e");
    }

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  bool _isESP32Device(ScanResult result) {
    final name = result.device.platformName;
    if (name.isEmpty) return false;

    for (var esp32Name in ESP32_DEVICE_NAMES) {
      if (name.toLowerCase().contains(esp32Name.toLowerCase())) {
        return true;
      }
    }
    return true; // 테스트용: 모든 기기 표시
  }

  /// 기기 연결 및 알리미 목록으로 자동 이동
  Future<void> _connectToDevice(ScanResult result) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
      _connectingDeviceId = result.device.remoteId.toString();
    });

    try {
      await FlutterBluePlus.stopScan();

      // BluetoothManager를 통해 연결
      bool success = await _bluetoothManager.connect(result.device);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${result.device.platformName} 연결 성공!"),
            backgroundColor: Colors.green,
          ),
        );

        // ✅ 연결 성공 시 알리미 목록(TabBarPage)으로 자동 이동
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const TabbarPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print("❌ 연결 실패: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("연결 실패: ${e.toString().substring(0, e.toString().length > 50 ? 50 : e.toString().length)}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectingDeviceId = null;
        });
      }
    }
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        title: const Text('ESP32 약통 연결',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            FlutterBluePlus.stopScan();
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            Center(
              child: StreamBuilder<bool>(
                stream: FlutterBluePlus.isScanning,
                initialData: false,
                builder: (context, snapshot) {
                  final isScanningNow = snapshot.data ?? false;

                  if (isScanningNow) {
                    return Column(
                      children: [
                        const SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            color: Color(0xFFB71C1C),
                            strokeWidth: 4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "ESP32 약통 검색 중...",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "약통의 전원이 켜져있는지 확인하세요",
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        const Icon(Icons.bluetooth_searching,
                            size: 60, color: Color(0xFFB71C1C)),
                        const SizedBox(height: 20),
                        const Text(
                          "기기 검색 완료",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _startScan,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text("다시 검색",
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB71C1C),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),

            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "연결되면 자동으로 알리미 목록으로 이동합니다.\n연결 해제 전까지 자동으로 재연결됩니다.",
                      style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              "발견된 기기",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: StreamBuilder<List<ScanResult>>(
                  stream: FlutterBluePlus.scanResults,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bluetooth_disabled,
                                size: 50, color: Colors.grey[400]),
                            const SizedBox(height: 10),
                            Text(
                              "기기를 찾지 못했습니다",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }

                    final results = snapshot.data!
                        .where((r) => _isESP32Device(r))
                        .toList();

                    results.sort((a, b) => b.rssi.compareTo(a.rssi));

                    if (results.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off,
                                size: 50, color: Colors.grey[400]),
                            const SizedBox(height: 10),
                            Text(
                              "ESP32 약통이 발견되지 않았습니다",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: results.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final result = results[index];
                        final isThisConnecting =
                            _connectingDeviceId == result.device.remoteId.toString();

                        IconData signalIcon;
                        Color signalColor;
                        if (result.rssi >= -60) {
                          signalIcon = Icons.signal_cellular_4_bar;
                          signalColor = Colors.green;
                        } else if (result.rssi >= -75) {
                          signalIcon = Icons.signal_cellular_alt;
                          signalColor = Colors.orange;
                        } else {
                          signalIcon = Icons.signal_cellular_alt_1_bar;
                          signalColor = Colors.red;
                        }

                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB71C1C).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.medication,
                                color: Color(0xFFB71C1C)),
                          ),
                          title: Text(
                            result.device.platformName.isNotEmpty
                                ? result.device.platformName
                                : "Unknown Device",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.device.remoteId.toString(),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(signalIcon, size: 16, color: signalColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${result.rssi} dBm",
                                    style: TextStyle(fontSize: 12, color: signalColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: isThisConnecting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : ElevatedButton(
                                  onPressed: _isConnecting
                                      ? null
                                      : () => _connectToDevice(result),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB71C1C),
                                    disabledBackgroundColor: Colors.grey,
                                  ),
                                  child: const Text(
                                    "연결",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
