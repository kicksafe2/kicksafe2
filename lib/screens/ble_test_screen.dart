import 'package:flutter/material.dart';
import '../ble_service.dart';   // screens 폴더 안이면 ../ 필요, lib 바로 아래면 'ble_service.dart'

class BleTestScreen extends StatefulWidget {
  const BleTestScreen({super.key});
  @override
  State<BleTestScreen> createState() => _BleTestScreenState();
}

class _BleTestScreenState extends State<BleTestScreen> {
  final ble = BleService();

  @override
  void dispose() {
    ble.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BLE 테스트")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => ble.connect(),
              child: const Text("연결"),
            ),
            const SizedBox(height: 20),
            StreamBuilder<String>(
              stream: ble.dataStream,
              builder: (context, snap) {
                if (!snap.hasData) return const Text("대기 중...");
                final v = snap.data!.split(",").map(double.parse).toList();
                return Text("ax: ${v[0]}, ay: ${v[1]}, az: ${v[2]}");
              },
            ),
          ],
        ),
      ),
    );
  }
}