/// 앱 전역 설정값. 비밀이 아닌 값만 여기에 둔다.
/// (REST API 키/시크릿은 secrets.dart 에 두고 Git에 올리지 않는다)
class AppConfig {
  AppConfig._();

  /// 네이버 클라우드 Maps Application의 Client ID.
  /// 패키지명(com.kicksafe.app)에 묶여 있어 앱 코드에 넣어도 되는 값이다.
  static const naverMapClientId = 'buu12no1iw';
}
