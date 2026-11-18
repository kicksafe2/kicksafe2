import 'package:flutter_test/flutter_test.dart';
import 'package:kicksafe/services/keep_awake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('플러그인이 없는 환경(테스트)에서도 켜고 꺼도 예외가 없다', () async {
    await KeepAwake.on(); // 플러그인 호출이 실패해도 던지지 않아야 함
    await KeepAwake.off();
    expect(KeepAwake.isOn, isFalse);
  });
}
