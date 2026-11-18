/// 앱 전역 설정값. 비밀이 아닌 값만 여기에 둔다.
/// (REST API 키/시크릿은 secrets.dart 에 두고 Git에 올리지 않는다)
class AppConfig {
  AppConfig._();

  /// 네이버 클라우드 Maps Application의 Client ID.
  /// 패키지명(com.kicksafe.app)에 묶여 있어 앱 코드에 넣어도 되는 값이다.
  static const naverMapClientId = 'buu12no1iw';

  /// 이 시간(분)을 넘는 경로는 주행을 차단한다.
  static const maxRideMinutes = 90;

  /// 킥보드 평균 속도(km/h). 거리 → 예상 주행 시간 환산에 쓴다.
  /// (정지/신호 대기 등을 감안해 법정 최고속도 25km/h보다 낮게 잡음)
  static const avgKickboardSpeedKmh = 20.0;

  /// 주행 중 센서 원시값을 폰 파일(CSV)에 기록한다. 점수 임계값을 되짚어 조정하려고 켜 둔다.
  /// 위치: Android/data/com.kicksafe.app/files/sensor_logs/<세션ID>_imu.csv, _events.csv
  static const saveRawSensorToFile = true;

  /// 디버그 빌드에서 주행 화면에 'GPS 시뮬레이션', '가짜 충돌/급정거/급회전' 버튼을 보일지.
  /// 실제 센서로 주행 테스트를 할 때는 false 로 둔다(실수로 눌러 가짜 값이 점수에 섞이는 것을 막음).
  /// 릴리즈 빌드에서는 이 값과 상관없이 항상 숨겨진다. 센서 없이 점수 흐름만 확인하려면 true.
  static const showDebugTools = false;

  /// 같은 원시값을 Firestore(imuLogs/{세션ID}/logs)에도 1초 묶음으로 저장한다.
  /// 10분 주행에 문서 약 600개. 쓰기 한도(하루 2만 건)가 걱정되면 false.
  static const saveRawSensorToFirestore = true;
}
