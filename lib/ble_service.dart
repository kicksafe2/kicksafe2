import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

const serviceUuid = "12345678-1234-1234-1234-1234567890ab";
const charUuid    = "12345678-1234-1234-1234-1234567890cd";

class BleService {
  BluetoothDevice? _device;
  StreamSubscription? _valueSub;
  final _controller = StreamController<String>.broadcast();
  Stream<String> get dataStream => _controller.stream;

  Future<void> connect() async {
    // 1. 권한
    await [Permission.bluetoothScan, Permission.bluetoothConnect,
           Permission.location].request();

    // 2. 스캔 (이름으로 필터)
    await FlutterBluePlus.startScan(
      withNames: ["KickSafe"], timeout: const Duration(seconds: 8));
    final results = await FlutterBluePlus.scanResults
        .firstWhere((r) => r.isNotEmpty);
    await FlutterBluePlus.stopScan();

    // 3. 연결
    _device = results.first.device;
    await _device!.connect();

    // 4. 서비스/특성 찾기 + Notify 구독
    final services = await _device!.discoverServices();
    for (var s in services) {
      if (s.uuid.toString() == serviceUuid) {
        for (var c in s.characteristics) {
          if (c.uuid.toString() == charUuid) {
            await c.setNotifyValue(true);
            _valueSub = c.onValueReceived.listen((value) {
              _controller.add(utf8.decode(value));
            });
          }
        }
      }
    }

    // 5. 끊김 감지
    _device!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        // 여기서 재연결 로직 호출
      }
    });
  }

  Future<void> disconnect() async {
    await _valueSub?.cancel();
    await _device?.disconnect();
  }
}