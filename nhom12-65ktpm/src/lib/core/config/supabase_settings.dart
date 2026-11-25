import 'dart:convert';

import 'package:flutter/services.dart';

/// Thông tin kết nối Supabase.
///
/// Mặc định đọc cấu hình development công khai đi kèm ứng dụng.
/// Có thể ghi đè cả URL và publishable key bằng --dart-define.
/// Không đặt service_role, secret key hoặc mật khẩu trong mã Dart.
class SupabaseSettings {
  const SupabaseSettings({required this.url, required this.publishableKey});

  final String url;
  final String publishableKey;

  /// Đọc cấu hình từ lệnh flutter run/build.
  static const fromEnvironment = SupabaseSettings(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  static const publicConfigAsset = 'assets/config/supabase.public.json';

  /// SUPABASE_ENABLED=false cho phép chạy demo mà không kết nối backend.
  /// Khi ghi đè, bắt buộc truyền đủ cặp URL/key để không trộn hai project.
  static Future<SupabaseSettings> load({
    AssetBundle? bundle,
    SupabaseSettings environment = fromEnvironment,
    bool enabled = const bool.fromEnvironment(
      'SUPABASE_ENABLED',
      defaultValue: true,
    ),
  }) async {
    if (!enabled) return const SupabaseSettings(url: '', publishableKey: '');

    if (environment.url.isNotEmpty || environment.publishableKey.isNotEmpty) {
      if (!environment.isConfigured) {
        throw const FormatException(
          'Can truyen day du SUPABASE_URL va SUPABASE_PUBLISHABLE_KEY hop le.',
        );
      }
      return environment;
    }

    final content = await (bundle ?? rootBundle).loadString(publicConfigAsset);
    final Object? decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 2 ||
        decoded['SUPABASE_URL'] is! String ||
        decoded['SUPABASE_PUBLISHABLE_KEY'] is! String) {
      throw const FormatException(
        'Cau hinh cong khai chi duoc chua SUPABASE_URL va '
        'SUPABASE_PUBLISHABLE_KEY dang chuoi.',
      );
    }
    final settings = SupabaseSettings(
      url: decoded['SUPABASE_URL'] as String,
      publishableKey: decoded['SUPABASE_PUBLISHABLE_KEY'] as String,
    );
    if (!settings.isConfigured ||
        Uri.parse(settings.url).scheme != 'https' ||
        !settings.publishableKey.startsWith('sb_publishable_')) {
      throw const FormatException(
        'Cau hinh development can URL HTTPS va khoa sb_publishable_.',
      );
    }
    return settings;
  }

  /// Cho phép http chỉ để kết nối Supabase chạy cục bộ trên máy phát triển.
  bool get isConfigured {
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasAuthority) return false;
    if (parsed.scheme != 'https' && parsed.scheme != 'http') return false;
    return publishableKey.trim().isNotEmpty;
  }
}
