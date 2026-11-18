import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 센서 기록(CSV)을 저장할 폴더.
///
/// 안드로이드는 앱 전용 외부 저장소(`Android/data/<패키지>/files/sensor_logs`)를 쓴다.
/// 앱을 지우면 같이 지워지고, 별도 저장소 권한이 필요 없다. 꺼낼 때:
///   adb pull /sdcard/Android/data/com.kicksafe.app/files/sensor_logs
/// 외부 저장소를 못 쓰면 앱 내부 문서 폴더로 대신한다. (null 이면 파일 기록 안 함)
Future<Directory?> sensorLogDirectory() async {
  if (kIsWeb) return null;
  try {
    final ext = await getExternalStorageDirectory();
    final base = ext ?? await getApplicationDocumentsDirectory();
    return Directory('${base.path}${Platform.pathSeparator}sensor_logs');
  } catch (e) {
    debugPrint('센서 기록 폴더를 정하지 못했어요: $e');
    return null;
  }
}
