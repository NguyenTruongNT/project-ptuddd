/// Thông tin kết nối Supabase.
///
/// URL và publishable key được truyền bằng --dart-define khi chạy ứng dụng.
/// Không đặt service_role, secret key hoặc mật khẩu trong mã Dart.
class SupabaseSettings {
  const SupabaseSettings({
    required this.url,
    required this.publishableKey,
  });

  final String url;
  final String publishableKey;

  /// Đọc cấu hình từ lệnh flutter run/build.
  static const fromEnvironment = SupabaseSettings(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  /// Cho phép http chỉ để kết nối Supabase chạy cục bộ trên máy phát triển.
  bool get isConfigured {
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasAuthority) return false;
    if (parsed.scheme != 'https' && parsed.scheme != 'http') return false;
    return publishableKey.trim().isNotEmpty;
  }
}
