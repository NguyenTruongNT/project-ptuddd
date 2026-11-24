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

  final settings = SupabaseSettings.fromEnvironment;
  final preferences = await SharedPreferences.getInstance();
  var authFailed = false;
  if (settings.isConfigured) {
    // Khởi tạo đúng một lần trước khi chạy ứng dụng.
    try {
      await Supabase.initialize(
        url: settings.url,
        publishableKey: settings.publishableKey,
      );
    } catch (_) {
      // Không log URL/token/error payload có thể chứa dữ liệu phiên.
      authFailed = true;
    }
  } else {
    // Nhóm có thể phát triển UI mock khi chưa cấu hình Supabase.
    debugPrint('StudyShare: chưa cấu hình Supabase, chỉ chạy giao diện mock.');
  }

  runApp(
    ProviderScope(
      overrides: [
        preferencesStoreProvider.overrideWithValue(preferences),
        authInitializationFailedProvider.overrideWithValue(authFailed),
      ],
      child: const StudyShareApp(),
    ),
  );
}
