import 'dart:async';

import 'package:studyshare/core/auth/auth_repository.dart';
import 'package:studyshare/core/auth/profile_repository.dart';

class FakeAuthRepository implements AuthRepository {
  AuthSnapshot snapshot = const AuthSnapshot.signedOut();
  final _events = StreamController<AuthSnapshot>.broadcast(sync: true);
  int loginCalls = 0;
  int resetCalls = 0;
  int registerCalls = 0;
  int signOutCalls = 0;
  int recoveryCalls = 0;
  String? submittedEmail;
  String? submittedName;
  Object? loginError;
  Completer<void>? loginPending;
  bool needsConfirmation = true;

  void emit(AuthSnapshot next) {
    snapshot = next;
    _events.add(next);
  }

  Future<void> close() => _events.close();
  @override
  Stream<AuthSnapshot> watchSession() => Stream.multi((sink) {
    final subscription = _events.stream.listen(sink.add);
    sink.add(snapshot);
    sink.onCancel = subscription.cancel;
  });
  @override
  Future<void> signIn({required String email, required String password}) async {
    loginCalls++;
    submittedEmail = email;
    await loginPending?.future;
    if (loginError != null) throw loginError!;
    emit(
      const AuthSnapshot.signedIn(
        AuthIdentity(id: 'real-user-a', email: 'a@example.test'),
      ),
    );
  }

  @override
  Future<RegistrationOutcome> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    registerCalls++;
    submittedEmail = email;
    submittedName = displayName;
    if (!needsConfirmation) {
      emit(
        AuthSnapshot.signedIn(
          AuthIdentity(
            id: 'real-user-a',
            email: email,
            displayName: displayName,
          ),
        ),
      );
    }
    return RegistrationOutcome(needsEmailConfirmation: needsConfirmation);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    resetCalls++;
  }

  @override
  Future<void> resendConfirmation(String email) async {
    resetCalls++;
  }

  @override
  Future<void> completePasswordRecovery(String password) async {
    if (!snapshot.recovering) throw const RecoverySessionRequired();
    recoveryCalls++;
    emit(const AuthSnapshot.signedOut());
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    emit(const AuthSnapshot.signedOut());
  }
}

class FakeProfileRepository implements ProfileRepository {
  String? currentId;
  final names = <String, String>{};
  int updateCalls = 0;
  @override
  Future<UserProfile> getOrCreateMyProfile(AuthIdentity identity) async {
    currentId = identity.id;
    final name = names.putIfAbsent(
      identity.id,
      () => identity.displayName ?? 'StudyShare',
    );
    return UserProfile(userId: identity.id, displayName: name);
  }

  @override
  Future<UserProfile> updateMyDisplayName(String displayName) async {
    updateCalls++;
    names[currentId!] = displayName;
    return UserProfile(userId: currentId!, displayName: displayName);
  }
}
