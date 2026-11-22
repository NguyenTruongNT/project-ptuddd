import 'package:supabase_flutter/supabase_flutter.dart';

/// Chỉ bao bọc thao tác đăng nhập cơ bản, dễ dùng từ các màn Auth sau này.
/// Server Supabase chịu trách nhiệm kiểm tra mật khẩu và phiên đăng nhập.
class AuthSessionService {
  AuthSessionService(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
