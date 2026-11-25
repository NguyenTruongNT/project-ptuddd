/// Đọc DTO RPC có kiểm tra kiểu; lỗi hợp đồng không được biến thành dữ liệu rỗng.
abstract final class WorkflowJson {
  static Map<String, dynamic> object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected object');
    }
    return value;
  }

  static List<Object?> list(Object? value) {
    if (value is! List) throw const FormatException('Expected list');
    return value;
  }

  static String text(Object? value) {
    if (value is! String) throw const FormatException('Expected string');
    return value;
  }

  static String? optionalText(Object? value) =>
      value == null ? null : text(value);

  static int integer(Object? value) {
    if (value is! int) throw const FormatException('Expected integer');
    return value;
  }

  static int? optionalInteger(Object? value) =>
      value == null ? null : integer(value);

  static bool boolean(Object? value) {
    if (value is! bool) throw const FormatException('Expected boolean');
    return value;
  }

  static DateTime timestamp(Object? value) {
    final raw = text(value);
    if (!RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(raw)) {
      throw const FormatException('Expected timestamp with timezone');
    }
    return DateTime.parse(raw).toUtc();
  }

  static DateTime? optionalTimestamp(Object? value) =>
      value == null ? null : timestamp(value);

  static String? dateVn(Object? value) {
    if (value == null) return null;
    final raw = text(value);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw) ||
        DateTime.parse(raw).toIso8601String().substring(0, 10) != raw) {
      throw const FormatException('Expected Vietnam calendar date');
    }
    return raw;
  }
}
