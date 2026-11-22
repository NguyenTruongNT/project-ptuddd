import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_settings.dart';
import 'auth_session_service.dart';

/// Khi chưa truyền cấu hình, app vẫn xem được các màn hình mock.
/// Không tạo SupabaseClient giả và không tự coi như đã đăng nhập.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!SupabaseSettings.fromEnvironment.isConfigured) return null;
  return Supabase.instance.client;
});

final authSessionServiceProvider = Provider<AuthSessionService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : AuthSessionService(client);
});

/// Dòng sự kiện cho router và màn hình đăng nhập dùng về sau.
/// Đọc người dùng hiện tại trước, sau đó nghe token/login/logout.
final currentAuthUserProvider = StreamProvider<User?>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    yield null;
    return;
  }

  yield client.auth.currentUser;
  yield* client.auth.onAuthStateChange.map((event) => event.session?.user);
});
