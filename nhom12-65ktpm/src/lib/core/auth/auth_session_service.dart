import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';

/// Chỉ bao bọc thao tác đăng nhập cơ bản, dễ dùng từ các màn Auth sau này.
/// Server Supabase chịu trách nhiệm kiểm tra mật khẩu và phiên đăng nhập.
class AuthSessionService implements AuthRepository {
  AuthSessionService(this._client);

  final SupabaseClient _client;
  bool _recovering = false;
  static const callbackUrl = 'studyshare://auth/callback';

  User? get currentUser => _client.auth.currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email.trim(), password: password);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  AuthSnapshot _snapshot() {
    final session = _client.auth.currentSession;
    if (session == null || session.isExpired) {
      return const AuthSnapshot.signedOut();
    }
    final user = session.user;
    final name = user.userMetadata?['display_name'];
    return AuthSnapshot.signedIn(
      AuthIdentity(
        id: user.id,
        email: user.email,
        displayName: name is String ? name : null,
      ),
      recovering: _recovering,
    );
  }

  @override
  Stream<AuthSnapshot> watchSession() => Stream<AuthSnapshot>.multi((sink) {
    final subscription = _client.auth.onAuthStateChange.listen(
      (data) {
        if (data.event == AuthChangeEvent.signedIn) _recovering = false;
        if (data.event == AuthChangeEvent.passwordRecovery) _recovering = true;
        if (data.event == AuthChangeEvent.signedOut) _recovering = false;
        sink.add(_snapshot());
      },
      onError: (Object _, StackTrace _) {
        _recovering = false;
        sink.add(const AuthSnapshot.failure());
      },
    );
    sink.add(_snapshot());
    sink.onCancel = subscription.cancel;
  });

  @override
  Future<RegistrationOutcome> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final result = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: callbackUrl,
      data: {'display_name': displayName.trim()},
    );
    return RegistrationOutcome(needsEmailConfirmation: result.session == null);
  }

  @override
  Future<void> requestPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(email.trim(), redirectTo: callbackUrl);

  @override
  Future<void> resendConfirmation(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: callbackUrl,
    );
  }

  @override
  Future<void> completePasswordRecovery(String password) async {
    // URL/query do client gửi không cấp quyền recovery; cần sự kiện SDK xác thực.
    if (!_recovering ||
        _client.auth.currentSession == null ||
        _client.auth.currentSession!.isExpired) {
      throw const RecoverySessionRequired();
    }
    await _client.auth.updateUser(UserAttributes(password: password));
    await _client.auth.signOut(scope: SignOutScope.global);
    _recovering = false;
  }
}
