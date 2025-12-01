import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // 블루투스 패키지
import 'package:permission_handler/permission_handler.dart'; // 권한 패키지
import 'login_screen.dart';
import 'device_control_screen.dart'; // 2단계에서 만든 제어 화면 import (파일이 있어야 에러가 안 납니다)

class BluetoothScanScreen extends StatefulWidget {
  const BluetoothScanScreen({super.key});

  @override
  State<BluetoothScanScreen> createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen> {
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    // 화면이 켜지면 권한 체크 후 스캔 시작
    _checkPermissionsAndScan();
  }

  // 1. 권한 요청 및 스캔 시작 함수
  Future<void> _checkPermissionsAndScan() async {
    // 블루투스와 위치 권한 요청
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // 권한이 모두 허용되었으면 스캔 시작
    if (statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted) {
      _startScan();
    } else {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('블루투스 권한을 허용해주세요.')),
        );
      }
    }
  }

  // 2. 실제 스캔 동작 함수
  void _startScan() async {
    setState(() {
      _isScanning = true;
    });

    try {
      // 4초 동안 스캔 진행
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    } catch (e) {
      print("스캔 에러: $e");
    }

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  // 로그아웃 함수
  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        title: const Text('APG', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => _logout(context),
            child: const Text("로그아웃", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // 3. 상단 상태 표시 (스캔 중인지 아닌지)
            Center(
              child: Column(
                children: [
                  // 스트림 빌더를 사용하여 스캔 상태 실시간 확인
                  StreamBuilder<bool>(
                    stream: FlutterBluePlus.isScanning,
                    initialData: false,
                    builder: (context, snapshot) {
                      final isScanningNow = snapshot.data ?? false;
                      if (isScanningNow) {
                        return Column(
                          children: const [
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: CircularProgressIndicator(color: Colors.grey, strokeWidth: 3),
                            ),
                            SizedBox(height: 20),
                            Text("주변 기기 찾는 중...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            const Icon(Icons.bluetooth_searching, size: 60, color: Color(0xFFB71C1C)),
                            const SizedBox(height: 20),
                            const Text("기기 검색 완료", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            TextButton(
                              onPressed: _startScan, // 다시 스캔 버튼
                              child: const Text("다시 찾기", style: TextStyle(color: Color(0xFFB71C1C))),
                            )
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            const Text("발견된 기기", style: TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 10),

            // 4. 발견된 기기 리스트 (실시간 업데이트)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                // StreamBuilder로 스캔 결과 실시간 표시
                child: StreamBuilder<List<ScanResult>>(
                  stream: FlutterBluePlus.scanResults,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("기기를 찾지 못했습니다."));
                    }

                    // 이름이 있는 기기만 필터링
                    final results = snapshot.data!
                        .where((r) => r.device.platformName.isNotEmpty)
                        .toList();

                    if (results.isEmpty) {
                      return const Center(child: Text("이름이 있는 기기가 없습니다."));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: results.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final result = results[index];
                        return ListTile(
                          title: Text(
                            result.device.platformName, // 기기 이름
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(result.device.remoteId.toString()), // MAC 주소
                          trailing: ElevatedButton(
                            onPressed: () async {
                              // === [수정된 부분: 연결 로직] ===
                              try {
                                // 1. 연결 전 스캔 중지
                                await FlutterBluePlus.stopScan();

                                // 2. 연결 시도 (블루투스 기기와 통신 시작)
                                await result.device.connect(autoConnect: false);

                                if (mounted) {
                                  // 3. 연결 성공 시 제어 화면으로 이동
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      // DeviceControlScreen 파일이 필요합니다.
                                      builder: (context) => DeviceControlScreen(device: result.device),
                                    ),
                                  );
                                }
                              } catch (e) {
                                print("연결 실패: $e");
                                if(mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("연결 실패: $e")),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)),
                            child: const Text("연결", style: TextStyle(color: Colors.white)),
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