import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/auth/auth_session_service.dart';

void main() {
  test('Android dùng đúng deep link đã đăng ký trong manifest', () {
    expect(
      AuthSessionService.callbackUrlForPlatform(
        isWeb: false,
        baseUri: Uri.parse('http://127.0.0.1:5180/?code=previous-code'),
      ),
      'studyshare://auth/callback',
    );
  });

  test('Web giữ đúng host và cổng, loại bỏ query và hash route', () {
    for (final host in ['127.0.0.1', 'localhost']) {
      expect(
        AuthSessionService.callbackUrlForPlatform(
          isWeb: true,
          baseUri: Uri.parse(
            'http://$host:5180/?code=previous-code#/auth/sign-up',
          ),
        ),
        'http://$host:5180/',
      );
    }
  });

  test(
    'Web HTTPS dùng origin đang chạy, không gửi lại token hoặc return URL',
    () {
      expect(
        AuthSessionService.callbackUrlForPlatform(
          isWeb: true,
          baseUri: Uri.parse(
            'https://studyshare.example/auth/reset-password'
            '?from=https%3A%2F%2Fother.example#access_token=previous-token',
          ),
        ),
        'https://studyshare.example/',
      );
    },
  );
}
