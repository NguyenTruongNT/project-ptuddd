import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/features/auth/domain/auth_validation.dart';

void main() {
  test('Mật khẩu mới bắt buộc đủ từng nhóm ký tự và ít nhất 8 ký tự', () {
    expect(AuthValidation.minimumPasswordLength, greaterThanOrEqualTo(8));
    for (final entry in {
      'abc123!@': PasswordRequirement.uppercase,
      'ABC123!@': PasswordRequirement.lowercase,
      'Abcdef!@': PasswordRequirement.digit,
      'Abcdef12': PasswordRequirement.symbol,
      'Aa1!': PasswordRequirement.length,
    }.entries) {
      expect(AuthValidation.validNewPassword(entry.key), isFalse);
      expect(
        AuthValidation.missingPasswordRequirements(entry.key),
        contains(entry.value),
      );
    }
    expect(AuthValidation.validNewPassword('StrongPassword123!'), isTrue);
    expect(AuthValidation.validNewPassword('12345678'), isFalse);
    expect(AuthValidation.validNewPassword('Abc1234 '), isFalse);
    expect(AuthValidation.validNewPassword('Abc1234🙂'), isFalse);
    // Supabase counts Unicode code points, not UTF-16 code units.
    expect(AuthValidation.validNewPassword('Aa1!🙂🙂'), isFalse);
  });
  test('Ký tự đặc biệt đồng bộ với tập ký tự Supabase cho phép', () {
    for (final symbol in AuthValidation.passwordSymbols.split('')) {
      final password =
          'Aa1${'a' * (AuthValidation.minimumPasswordLength - 4)}$symbol';
      expect(
        AuthValidation.validNewPassword(password),
        isTrue,
        reason: 'Allowed symbol: $symbol',
      );
    }
  });
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
