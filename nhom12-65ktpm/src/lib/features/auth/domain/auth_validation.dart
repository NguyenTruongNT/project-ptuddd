class AuthValidation {
  static const minimumPasswordLength = int.fromEnvironment(
    'AUTH_MIN_PASSWORD_LENGTH',
    defaultValue: 6,
  );
  static bool validEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
  static bool validName(String value) =>
      value.trim().isNotEmpty && value.trim().length <= 100;
  static bool validNewPassword(String value) =>
      value.length >= minimumPasswordLength;
}
