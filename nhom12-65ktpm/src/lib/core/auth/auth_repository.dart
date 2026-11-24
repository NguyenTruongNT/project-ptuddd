/// Không chuyển token vào UI hay URL.
class AuthIdentity {
  const AuthIdentity({required this.id, this.email, this.displayName});
  final String id;
  final String? email;
  final String? displayName;
}

class AuthSnapshot {
  const AuthSnapshot.signedOut()
    : identity = null,
      configured = true,
      recovering = false,
      failed = false;
  const AuthSnapshot.unconfigured()
    : identity = null,
      configured = false,
      recovering = false,
      failed = false;
  const AuthSnapshot.failure()
    : identity = null,
      configured = true,
      recovering = false,
      failed = true;
  const AuthSnapshot.signedIn(this.identity, {this.recovering = false})
    : configured = true,
      failed = false;
  final AuthIdentity? identity;
  final bool configured;
  final bool recovering;
  final bool failed;
  bool get isAuthenticated => identity != null && !failed;
}

class RegistrationOutcome {
  const RegistrationOutcome({required this.needsEmailConfirmation});
  final bool needsEmailConfirmation;
}

/// Session/actor do Supabase xác thực, không lấy từ dữ liệu demo.
abstract interface class AuthRepository {
  Stream<AuthSnapshot> watchSession();
  Future<void> signIn({required String email, required String password});
  Future<RegistrationOutcome> register({
    required String displayName,
    required String email,
    required String password,
  });
  Future<void> requestPasswordReset(String email);
  Future<void> resendConfirmation(String email);
  Future<void> completePasswordRecovery(String password);
  Future<void> signOut();
}

class RecoverySessionRequired implements Exception {
  const RecoverySessionRequired();
}
