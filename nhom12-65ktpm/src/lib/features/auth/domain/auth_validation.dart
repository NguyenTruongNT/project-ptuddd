enum PasswordRequirement { length, uppercase, lowercase, digit, symbol }

class AuthValidation {
  static const _configuredMinimum = int.fromEnvironment(
    'AUTH_MIN_PASSWORD_LENGTH',
    defaultValue: 8,
  );
  static const minimumPasswordLength = _configuredMinimum < 8
      ? 8
      : _configuredMinimum;
  // Same symbol set as Supabase lower_upper_letters_digits_symbols.
  static const passwordSymbols = r'''!@#$%^&*()_+-=[]{};'\:"|<>?,./`~''';
  static bool validEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
  static bool validName(String value) =>
      value.trim().isNotEmpty && value.trim().length <= 100;
  static List<PasswordRequirement> missingPasswordRequirements(
    String value,
  ) => [
    if (value.runes.length < minimumPasswordLength) PasswordRequirement.length,
    if (!RegExp(r'[A-Z]').hasMatch(value)) PasswordRequirement.uppercase,
    if (!RegExp(r'[a-z]').hasMatch(value)) PasswordRequirement.lowercase,
    if (!RegExp(r'[0-9]').hasMatch(value)) PasswordRequirement.digit,
    if (!passwordSymbols.split('').any(value.contains))
      PasswordRequirement.symbol,
  ];

  static bool validNewPassword(String value) =>
      missingPasswordRequirements(value).isEmpty;
}
