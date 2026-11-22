import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/studyshare_app.dart';
import 'core/config/supabase_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SupabaseSettings.fromEnvironment;
  if (settings.isConfigured) {
    // Khởi tạo đúng một lần trước khi chạy ứng dụng.
    await Supabase.initialize(
      url: settings.url,
      publishableKey: settings.publishableKey,
    );
  } else {
    // Nhóm có thể phát triển UI mock khi chưa cấu hình Supabase.
    debugPrint('StudyShare: chưa cấu hình Supabase, chỉ chạy giao diện mock.');
  }

  runApp(const ProviderScope(child: StudyShareApp()));
}
