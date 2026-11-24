import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/features/auth/domain/auth_validation.dart';

void main() {
  test('Validation email, tên và password mới theo cấu hình', () {
    expect(AuthValidation.validEmail(' a@example.test '), isTrue);
    for (final email in ['', 'a@', 'x y@example.test', 'a@example']) {
      expect(AuthValidation.validEmail(email), isFalse);
    }
    expect(AuthValidation.validName('   '), isFalse);
    expect(AuthValidation.validName('a' * 101), isFalse);
    expect(AuthValidation.validName('Nguyễn Văn Trường'), isTrue);
    expect(AuthValidation.validNewPassword('123'), isFalse);
  });
}
