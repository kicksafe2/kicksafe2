import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble_sensor_service.dart';

/// 센서(ESP32 + MPU6050) 연결 상태. 화면에 그대로 보여준다.
enum SensorStatus {
  idle, // 시작 전
  searching, // 주변에서 KickSafe-Sensor 찾는 중
  connecting, // 찾았고 연결 중
  connected, // 연결됨(값이 들어오는 중)
  reconnecting, // 끊겨서 다시 연결 중
  notFound, // 제한 시간 안에 못 찾음
  permissionDenied, // 블루투스 권한 거부
  bluetoothOff, // 폰의 블루투스가 꺼져 있음
  unsupported, // 이 기기는 블루투스 LE 미지원(에뮬레이터 등)
  error, // 그 외 실패
}

extension SensorStatusText on SensorStatus {
  String get label => switch (this) {
        SensorStatus.idle => '센서 대기',
        SensorStatus.searching => '센서 찾는 중...',
        SensorStatus.connecting => '센서 연결 중...',
        SensorStatus.connected => '센서 연결됨',
        SensorStatus.reconnecting => '센서 재연결 중...',
        SensorStatus.notFound => '센서를 찾지 못했어요',
        SensorStatus.permissionDenied => '블루투스 권한이 필요해요',
        SensorStatus.bluetoothOff => '블루투스를 켜주세요',
        SensorStatus.unsupported => '이 기기는 센서 연결을 지원하지 않아요',
        SensorStatus.error => '센서 연결 실패',
      };

  bool get isOk => this == SensorStatus.connected;
}

/// 주행 중 센서에 연결해 측정값을 [onReading]으로 흘려보낸다.
///
/// 연결에 실패해도 주행 자체는 계속된다(점수만 센서 없이 100점으로 남는다).
/// 연결이 도중에 끊기면 주행이 끝날 때까지 다시 연결을 시도한다.
class SensorLink {
  /// 펌웨어의 SERVICE_UUID 와 같아야 한다. (이름 대신 서비스 UUID 로 찾는 게 더 확실하다)
  static const scanTimeout = Duration(seconds: 12);
  static const connectTimeout = Duration(seconds: 15);
  static const reconnectDelay = Duration(seconds: 3);
  static const retryScanDelay = Duration(seconds: 3);

  final ValueNotifier<SensorStatus> status = ValueNotifier(SensorStatus.idle);

  final BleSensorService _service = BleSensorService();
  BluetoothDevice? _device;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  void Function(SensorReading)? _onReading;
  bool _active = false;

  /// 사용자가 마지막으로 본 연결 오류(디버그/화면 표시용)
  String? lastError;

  Future<void> start(void Function(SensorReading) onReading) async {
    if (_active) return;
    _active = true;
    _onReading = onReading;
    try {
      if (!await FlutterBluePlus.isSupported) {
        _set(SensorStatus.unsupported);
        return;
      }
      if (!await _ensurePermissions()) {
        _set(SensorStatus.permissionDenied);
        return;
      }
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        final state = await FlutterBluePlus.adapterState
            .firstWhere((s) => s != BluetoothAdapterState.unknown)
            .timeout(const Duration(seconds: 3), onTimeout: () => BluetoothAdapterState.off);
        if (state != BluetoothAdapterState.on) {
          _set(SensorStatus.bluetoothOff);
          return;
        }
      }
      await _findAndConnect();
    } catch (e, st) {
      lastError = '$e';
      debugPrint('센서 연결 실패: $e\n$st');
      if (_active) _set(SensorStatus.error);
    }
  }

  Future<bool> _ensurePermissions() async {
    final result = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    return result.values.every((s) => s.isGranted);
  }

  Future<void> _findAndConnect() async {
    _set(SensorStatus.searching);
    await FlutterBluePlus.startScan(
      withServices: [kSensorServiceUuid],
      timeout: scanTimeout,
    );
    final results = await FlutterBluePlus.scanResults
        .firstWhere((r) => r.isNotEmpty)
        .timeout(scanTimeout, onTimeout: () => <ScanResult>[]);
    await FlutterBluePlus.stopScan();
    if (!_active) return;
    if (results.isEmpty) {
      _set(SensorStatus.notFound);
      // 주행 화면을 연 뒤에 센서 전원을 켜는 경우도 있으니, 주행 중에는 계속 다시 찾는다.
      unawaited(Future<void>.delayed(retryScanDelay, () async {
        if (_active && _device == null) {
          try {
            await _findAndConnect();
          } catch (e) {
            debugPrint('센서 재탐색 실패: $e');
          }
        }
      }));
      return;
    }

    final device = results.first.device;
    _device = device;
    await _connect(device);

    // 연결이 끊기면 주행이 끝날 때까지 다시 붙는다.
    _connSub = device.connectionState.listen((state) async {
      if (!_active || state != BluetoothConnectionState.disconnected) return;
      _set(SensorStatus.reconnecting);
      while (_active) {
        await Future<void>.delayed(reconnectDelay);
        if (!_active) return;
        try {
          await _connect(device);
          return;
        } catch (e) {
          debugPrint('센서 재연결 실패: $e');
        }
      }
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    if (status.value != SensorStatus.reconnecting) _set(SensorStatus.connecting);
    await device.connect(timeout: connectTimeout);
    // 센서가 초당 약 50번 보내므로 연결 간격을 짧게(안드로이드 기본은 30~50ms) 요청한다.
    // 실패해도(미지원 기기 등) 연결과 점수 계산에는 영향이 없다.
    try {
      await device.requestConnectionPriority(connectionPriorityRequest: ConnectionPriority.high);
    } catch (e) {
      debugPrint('연결 우선순위 요청 실패(무시): $e');
    }
    await _service.subscribe(device, (r) => _onReading?.call(r));
    _set(SensorStatus.connected);
  }

  Future<void> stop() async {
    _active = false;
    _onReading = null;
    _service.dispose();
    await _connSub?.cancel();
    _connSub = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
  }

  void _set(SensorStatus s) {
    if (status.value != s) status.value = s;
  }

  void dispose() {
    unawaited(stop());
    status.dispose();
  }
}
