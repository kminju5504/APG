import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceControlScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceControlScreen({super.key, required this.device});

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  // 데이터를 쓰고 읽을 특성(Characteristic)을 저장할 변수
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;

  // 수신된 데이터를 화면에 표시하기 위한 리스트
  List<String> _receivedData = [];

  // 데이터 전송을 위한 컨트롤러
  final TextEditingController _sendController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _discoverServices(); // 화면 진입 시 서비스 탐색 시작
  }

  // 1. 서비스 및 특성(Characteristic) 탐색
  Future<void> _discoverServices() async {
    try {
      // 기기의 모든 서비스 가져오기
      List<BluetoothService> services = await widget.device.discoverServices();

      for (var service in services) {
        // 각 서비스 내의 특성(Characteristic) 확인
        for (var characteristic in service.characteristics) {

          // 쓰기(Write) 가능한 특성 찾기
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            _writeCharacteristic = characteristic;
          }

          // 알림(Notify) 가능한 특성 찾기 (데이터 수신용)
          if (characteristic.properties.notify) {
            _notifyCharacteristic = characteristic;
            _setupNotification(_notifyCharacteristic!);
          }
        }
      }
      setState(() {}); // 찾은 특성 정보를 화면에 반영
    } catch (e) {
      print("서비스 탐색 실패: $e");
    }
  }

  // 2. 데이터 수신 설정 (Notification 활성화)
  Future<void> _setupNotification(BluetoothCharacteristic characteristic) async {
    await characteristic.setNotifyValue(true);
    // 데이터가 들어올 때마다 리스트에 추가
    characteristic.lastValueStream.listen((value) {
      if (value.isNotEmpty) {
        String stringData = utf8.decode(value, allowMalformed: true); // 바이트를 문자열로 변환
        setState(() {
          _receivedData.add("수신: $stringData");
        });
      }
    });
  }

  // 3. 데이터 전송 함수
  Future<void> _sendData() async {
    if (_writeCharacteristic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("데이터를 보낼 수 있는 특성을 찾지 못했습니다.")),
      );
      return;
    }

    String text = _sendController.text;
    if (text.isEmpty) return;

    try {
      // 문자열을 UTF-8 바이트로 변환하여 전송
      await _writeCharacteristic!.write(utf8.encode(text));

      setState(() {
        _receivedData.add("전송: $text");
        _sendController.clear();
      });
    } catch (e) {
      print("전송 실패: $e");
    }
  }

  // 연결 해제 처리
  @override
  void dispose() {
    // 화면이 꺼질 때 연결 해제
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName),
        backgroundColor: const Color(0xFFB71C1C),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 상태 표시
            if (_writeCharacteristic == null || _notifyCharacteristic == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  "서비스 탐색 중... 또는 호환되는 특성이 없습니다.",
                  style: TextStyle(color: Colors.red),
                ),
              ),

            // 데이터 입력 및 전송
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sendController,
                    decoration: const InputDecoration(
                      labelText: "보낼 데이터 입력",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _sendData,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)),
                  child: const Text("전송", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const Divider(height: 30),

            // 데이터 로그 표시
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("통신 로그", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _receivedData.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_receivedData[index]),
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}