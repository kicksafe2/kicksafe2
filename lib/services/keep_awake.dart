import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 주행 중 화면이 꺼지지 않게 한다.
///
/// 화면이 꺼지면 폰이 절전 상태로 들어가 BLE 수신과 GPS 갱신이 늦어지거나 멈출 수 있어서
/// 주행 화면이 열려 있는 동안만 켜 둔다. (배터리를 더 쓰는 대신 센서·위치가 끊기지 않게 하는 선택)
///
/// 지원하지 않는 환경(에뮬레이터 일부, 테스트 등)에서도 예외 없이 넘어간다.
class KeepAwake {
  KeepAwake._();

  static bool _on = false;

  /// 지금 화면 유지를 켜 둔 상태인지
  static bool get isOn => _on;

  static Future<void> on() async {
    try {
      await WakelockPlus.enable();
      _on = true;
    } catch (e) {
      debugPrint('화면 유지를 켜지 못했어요: $e');
    }
  }

  static Future<void> off() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('화면 유지를 끄지 못했어요: $e');
    }
    _on = false;
  }
}
