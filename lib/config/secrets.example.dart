/// 이 파일을 복사해 `secrets.dart` 로 만들고 값을 채운다. (secrets.dart 는 Git에 올라가지 않음)
///
///   cp lib/config/secrets.example.dart lib/config/secrets.dart
///
/// 네이버 클라우드 콘솔 > Maps > Application > 인증 정보에서 확인한다.
class Secrets {
  Secrets._();

  /// X-NCP-APIGW-API-KEY-ID (Geocoding / Reverse Geocoding / Directions 5 REST 호출용)
  static const naverApiKeyId = '';

  /// X-NCP-APIGW-API-KEY (Client Secret)
  static const naverApiKey = '';
}
