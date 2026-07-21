import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/ble_sensor_service.dart';
import '../services/firestore_service.dart';

class BleScreen extends StatefulWidget {
  const BleScreen({super.key});

  @override
  State<BleScreen> createState() => _BleScreenState();
}

class _BleScreenState extends State<BleScreen> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;

  final BleSensorService _sensorService = BleSensorService();
  final FirestoreService _firestoreService = FirestoreService();

  // main.dart의 테스트 유저와 동일한 ID 사용
  static const String _userId = 'testUser1';

  // 이 값(g) 이상이면 충격/낙하로 간주
  static const double _impactThreshold = 2.0;
  static const int _impactPenalty = -10;
  static const Duration _eventCooldown = Duration(seconds: 3);
  DateTime? _lastEventAt;

  // 화면 표시용 상태
  SensorReading? _latestReading;
  String? _connectedName;
  int _eventCount = 0;

  void startScan() async {
    setState(() {
      scanResults = [];
      isScanning = true;
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });

    await Future.delayed(const Duration(seconds: 5));
    setState(() => isScanning = false);
  }

  void connectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    await device.connect();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${device.platformName} 연결됨!')),
    );

    setState(() {
      _connectedName = device.platformName.isEmpty
          ? device.remoteId.toString()
          : device.platformName;
    });

    // 센서 characteristic 구독 시작 -> 값 들어올 때마다 _handleReading 호출
    await _sensorService.subscribe(device, _handleReading);
  }

  void _handleReading(SensorReading reading) {
    // 화면에 최신 값 표시
    if (mounted) {
      setState(() => _latestReading = reading);
    }

    if (reading.accelMagnitude < _impactThreshold) return;

    final now = DateTime.now();
    if (_lastEventAt != null && now.difference(_lastEventAt!) < _eventCooldown) {
      return; // 연속 감지 방지 (디바운스)
    }
    _lastEventAt = now;
    if (mounted) setState(() => _eventCount++);

    _firestoreService.addEvent(_userId, 'impact', _impactPenalty);
    _firestoreService.updateScore(_userId, _impactPenalty);
  }

  Widget _buildSensorPanel() {
    final r = _latestReading;
    if (_connectedName == null) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('연결됨: $_connectedName',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (r == null)
              const Text('센서값 수신 대기 중...')
            else ...[
              Text('가속도(g)  X: ${r.ax.toStringAsFixed(2)}  '
                  'Y: ${r.ay.toStringAsFixed(2)}  Z: ${r.az.toStringAsFixed(2)}'),
              Text('자이로(°/s) X: ${r.gx.toStringAsFixed(1)}  '
                  'Y: ${r.gy.toStringAsFixed(1)}  Z: ${r.gz.toStringAsFixed(1)}'),
              const SizedBox(height: 4),
              Text('가속도 크기: ${r.accelMagnitude.toStringAsFixed(2)} g',
                  style: TextStyle(
                    color: r.accelMagnitude >= _impactThreshold
                        ? Colors.red
                        : Colors.black87,
                    fontWeight: FontWeight.bold,
                  )),
            ],
            const SizedBox(height: 4),
            Text('충격 감지 횟수: $_eventCount'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sensorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE 기기 스캔')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: isScanning ? null : startScan,
            child: Text(isScanning ? '스캔 중...' : '스캔 시작'),
          ),
          _buildSensorPanel(),
          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final device = scanResults[index].device;
                return ListTile(
                  title: Text(device.platformName.isEmpty
                      ? '알 수 없는 기기'
                      : device.platformName),
                  subtitle: Text(device.remoteId.toString()),
                  trailing: ElevatedButton(
                    onPressed: () => connectToDevice(device),
                    child: const Text('연결'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}