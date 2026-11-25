import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemoryStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}

void main() {
  const enabled = bool.fromEnvironment('RUN_LOCAL_PASSWORD_POLICY');
  const key = String.fromEnvironment('LOCAL_SUPABASE_PUBLISHABLE_KEY');
  test(
    'Server chặn mật khẩu yếu khi signup/update, kể cả gọi SDK trực tiếp',
    () async {
      expect(key, isNotEmpty);
      final client = SupabaseClient(
        'http://127.0.0.1:54321',
        key,
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: _MemoryStorage(),
        ),
      );
      final other = SupabaseClient(
        'http://127.0.0.1:54321',
        key,
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: _MemoryStorage(),
        ),
      );
      final ids = <String>[];
      addTearDown(() async {
        await client.dispose();
        await other.dispose();
        for (final id in ids) {
          if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(id)) {
            throw StateError('Invalid QA UUID');
          }
          final result = await Process.run('docker', [
            'exec',
            'supabase_db_src',
            'psql',
            '-U',
            'postgres',
            '-d',
            'postgres',
            '-c',
            "delete from auth.users where id = '$id'::uuid;",
          ]);
          expect(
            result.exitCode,
            0,
            reason: 'Remove only the test-created account',
          );
        }
      });
      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      const weak = ['abc123!@', 'ABC123!@', 'Abcdef!@', 'Abcdef12', 'Aa1!'];
      for (var index = 0; index < weak.length; index++) {
        try {
          final response = await client.auth.signUp(
            email: 'policy-weak-$suffix-$index@qa.co',
            password: weak[index],
          );
          if (response.user != null) ids.add(response.user!.id);
          fail('Weak password was accepted by signup');
        } on AuthException catch (error) {
          expect(error.code, 'weak_password');
        }
      }
      final email = 'policy-valid-$suffix@qa.co';
      final password = 'PolicyTest-$suffix!';
      final created = await client.auth.signUp(
        email: email,
        password: password,
      );
      expect(created.user, isNotNull);
      ids.add(created.user!.id);
      expect(created.session, isNotNull);
      for (final candidate in weak) {
        try {
          await client.auth.updateUser(UserAttributes(password: candidate));
          fail('Weak password was accepted by updateUser');
        } on AuthException catch (error) {
          expect(error.code, 'weak_password');
        }
      }
      await other.auth.signInWithPassword(email: email, password: password);
      final next = '${password}Next';
      await client.auth.updateUser(UserAttributes(password: next));
      await expectLater(
        other.auth.signInWithPassword(email: email, password: password),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'invalid_credentials',
          ),
        ),
      );
      final login = await other.auth.signInWithPassword(
        email: email,
        password: next,
      );
      expect(login.user?.id, created.user!.id);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
