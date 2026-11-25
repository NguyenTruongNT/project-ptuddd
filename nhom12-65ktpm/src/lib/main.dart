import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/studyshare_app.dart';
import 'core/config/supabase_settings.dart';
import 'core/preferences/app_preferences.dart';
import 'core/auth/auth_session_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  var settings = const SupabaseSettings(url: '', publishableKey: '');
  var authFailed = false;
  try {
    settings = await SupabaseSettings.load();
    if (settings.isConfigured) {
      // Khởi tạo đúng một lần trước khi chạy ứng dụng.
      await Supabase.initialize(
        url: settings.url,
        publishableKey: settings.publishableKey,
      );
    } else {
      debugPrint('StudyShare: dang chay demo, khong ket noi Supabase.');
    }
  } catch (_) {
    // Lỗi cấu hình/khởi tạo phải hiện trạng thái lỗi Auth, không giả đăng nhập.
    // Không log URL/token/error payload có thể chứa dữ liệu phiên.
    authFailed = true;
  }

  runApp(
    ProviderScope(
      overrides: [
        preferencesStoreProvider.overrideWithValue(preferences),
        supabaseSettingsProvider.overrideWithValue(settings),
        authInitializationFailedProvider.overrideWithValue(authFailed),
      ],
      child: const StudyShareApp(),
    ),
  );
}
