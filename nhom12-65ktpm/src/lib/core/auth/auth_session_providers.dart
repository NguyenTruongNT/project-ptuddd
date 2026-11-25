import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_settings.dart';
import 'auth_session_service.dart';
import 'auth_repository.dart';
import 'profile_repository.dart';

final authInitializationFailedProvider = Provider<bool>((ref) => false);

// main truyền cấu hình đã nạp từ asset hoặc --dart-define cho toàn bộ Auth.
final supabaseSettingsProvider = Provider<SupabaseSettings>(
  (ref) => SupabaseSettings.fromEnvironment,
);

final authRepositoryProvider = Provider<AuthRepository?>(
  (ref) => ref.watch(authSessionServiceProvider),
);

final authSnapshotProvider = StreamProvider<AuthSnapshot>((ref) {
  if (ref.watch(authInitializationFailedProvider)) {
    return Stream.value(const AuthSnapshot.failure());
  }
  final repository = ref.watch(authRepositoryProvider);
  return repository?.watchSession() ??
      Stream.value(const AuthSnapshot.unconfigured());
});

// Demo là lựa chọn tường minh, không phải một phiên Supabase giả.
class DemoModeController extends Notifier<bool> {
  DemoModeController({this.initial = false});
  final bool initial;
  @override
  bool build() => initial;
  void enable() {
    if (ref.read(authRepositoryProvider) == null &&
        !ref.read(authInitializationFailedProvider)) {
      state = true;
    }
  }

  void disable() => state = false;
}

final demoModeProvider = NotifierProvider<DemoModeController, bool>(
  DemoModeController.new,
);

// Các cache riêng tư phụ thuộc khóa này để bị hủy khi logout/đổi người dùng.
final sessionBoundaryProvider = Provider<String>((ref) {
  final session = ref.watch(authSnapshotProvider).asData?.value;
  if (session?.isAuthenticated ?? false) return session!.identity!.id;
  if (ref.watch(demoModeProvider) && !(session?.configured ?? false)) {
    return 'demo';
  }
  return '';
});

final profileRepositoryProvider = Provider<ProfileRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseProfileRepository(client);
});

final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final identity = ref.watch(authSnapshotProvider).asData?.value.identity;
  final recovering =
      ref.watch(authSnapshotProvider).asData?.value.recovering ?? false;
  if (identity == null || recovering) return null;
  final repository = ref.watch(profileRepositoryProvider);
  return repository?.getOrCreateMyProfile(identity);
});

/// Khi tắt Supabase bằng cấu hình demo, app vẫn xem được các màn hình mock.
/// Không tạo SupabaseClient giả và không tự coi như đã đăng nhập.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!ref.watch(supabaseSettingsProvider).isConfigured) return null;
  if (ref.watch(authInitializationFailedProvider)) return null;
  return Supabase.instance.client;
});

final authSessionServiceProvider = Provider<AuthSessionService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null
      ? null
      : AuthSessionService(
          client,
          settings: ref.watch(supabaseSettingsProvider),
        );
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
