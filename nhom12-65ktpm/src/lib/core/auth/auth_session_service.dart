import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_settings.dart';
import 'auth_repository.dart';

/// Chỉ bao bọc thao tác đăng nhập cơ bản, dễ dùng từ các màn Auth sau này.
/// Server Supabase chịu trách nhiệm kiểm tra mật khẩu và phiên đăng nhập.
class AuthSessionService implements AuthRepository {
  AuthSessionService(
    this._client, {
    this._settings = SupabaseSettings.fromEnvironment,
    this._oauthSettingsClient,
    this._oauthLauncher,
  });

  final SupabaseClient _client;
  final SupabaseSettings _settings;
  final http.Client? _oauthSettingsClient;
  final Future<bool> Function(OAuthProvider, String)? _oauthLauncher;
  bool _recovering = false;
  static const callbackUrl = 'studyshare://auth/callback';

  /// Web quay về origin hiện tại; Android dùng deep link đã đăng ký.
  /// Không đưa query hoặc fragment chứa thông tin phiên vào redirect mới.
  static String callbackUrlForPlatform({bool isWeb = kIsWeb, Uri? baseUri}) =>
      isWeb ? (baseUri ?? Uri.base).resolve('/').toString() : callbackUrl;

  User? get currentUser => _client.auth.currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signInWithProvider(SocialAuthProvider provider) async {
    // Check the public provider status before opening a browser. A disabled
    // provider must not navigate the user to a raw Auth error page.
    final url = Uri.parse('${_settings.url}/auth/v1/settings');
    final headers = {'apikey': _settings.publishableKey};
    final response =
        await (_oauthSettingsClient?.get(url, headers: headers) ??
                http.get(url, headers: headers))
            .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw const SocialAuthUnavailable();
    final settings = jsonDecode(response.body) as Map<String, dynamic>;
    final external = settings['external'] as Map<String, dynamic>?;
    if (external?[provider.name] != true) throw const SocialAuthUnavailable();
    final oauthProvider = switch (provider) {
      SocialAuthProvider.google => OAuthProvider.google,
      SocialAuthProvider.github => OAuthProvider.github,
    };
    final redirect = callbackUrlForPlatform();
    final launched =
        await (_oauthLauncher?.call(oauthProvider, redirect) ??
            _client.auth.signInWithOAuth(oauthProvider, redirectTo: redirect));
    if (!launched) throw const SocialAuthUnavailable();
    // Opening the provider is not authentication. watchSession receives the
    // verified SDK callback and drives the router after sign-in succeeds.
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: callbackUrlForPlatform(),
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  AuthSnapshot _snapshot() {
    final session = _client.auth.currentSession;
    if (session == null || session.isExpired) {
      return const AuthSnapshot.signedOut();
    }
    final user = session.user;
    final metadata = user.userMetadata;
    final name =
        metadata?['display_name'] ??
        metadata?['full_name'] ??
        metadata?['name'] ??
        metadata?['user_name'];
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
      emailRedirectTo: callbackUrlForPlatform(),
      data: {'display_name': displayName.trim()},
    );
    return RegistrationOutcome(needsEmailConfirmation: result.session == null);
  }

  @override
  Future<void> requestPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: callbackUrlForPlatform(),
      );

  @override
  Future<void> resendConfirmation(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: callbackUrlForPlatform(),
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
