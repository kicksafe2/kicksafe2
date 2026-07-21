import 'dart:async';
import 'dart:math';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// firmware/kicksafe_sensor/kicksafe_sensor.ino 와 짝을 이루는 BLE UUID.
/// 두 값 모두 펌웨어 쪽 SERVICE_UUID / CHARACTERISTIC_UUID와 반드시 동일해야 함.
final Guid kSensorServiceUuid = Guid('12345678-1234-5678-1234-56789abcdef0');
final Guid kSensorCharacteristicUuid =
    Guid('12345678-1234-5678-1234-56789abcdef1');

/// ESP32가 보내는 한 번의 센서 측정값 (가속도 단위: g, 자이로 단위: deg/s)
class SensorReading {
  final double ax, ay, az, gx, gy, gz;

  SensorReading({
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });

  /// 가속도 크기. 정지 상태 기준 약 1.0g가 정상이고, 급격히 커지면 충격/낙하로 판단.
  double get accelMagnitude => sqrt(ax * ax + ay * ay + az * az);

  /// 펌웨어에서 보내는 "ax,ay,az,gx,gy,gz" CSV 문자열 파싱
  static SensorReading? parse(List<int> bytes) {
    final text = String.fromCharCodes(bytes);
    final parts = text.split(',');
    if (parts.length != 6) return null;
    try {
      return SensorReading(
        ax: double.parse(parts[0]),
        ay: double.parse(parts[1]),
        az: double.parse(parts[2]),
        gx: double.parse(parts[3]),
        gy: double.parse(parts[4]),
        gz: double.parse(parts[5]),
      );
    } catch (_) {
      return null;
    }
  }
}

/// 연결된 BLE 기기에서 KickSafe 센서 characteristic을 찾아 notify를 구독하는 서비스
class BleSensorService {
  StreamSubscription<List<int>>? _subscription;

  /// [device]에서 센서 characteristic을 찾아 notify를 켜고,
  /// 값이 들어올 때마다 [onReading]을 호출한다.
  /// 매칭되는 service/characteristic이 없으면 아무 것도 하지 않는다.
  Future<void> subscribe(
    BluetoothDevice device,
    void Function(SensorReading reading) onReading,
  ) async {
    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid != kSensorServiceUuid) continue;

      for (final characteristic in service.characteristics) {
        if (characteristic.uuid != kSensorCharacteristicUuid) continue;

        await characteristic.setNotifyValue(true);
        await _subscription?.cancel();
        _subscription = characteristic.onValueReceived.listen((bytes) {
          final reading = SensorReading.parse(bytes);
          if (reading != null) onReading(reading);
        });
        return;
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
