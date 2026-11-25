import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:studyshare/core/auth/auth_repository.dart';
import 'package:studyshare/core/auth/auth_session_service.dart';
import 'package:studyshare/core/auth/profile_repository.dart';

class _PkceStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

Future<Map<String, dynamic>> _json(String path) async {
  final http = HttpClient();
  try {
    final response = await (await http.getUrl(
      Uri.parse('http://127.0.0.1:54324$path'),
    )).close();
    return jsonDecode(await utf8.decoder.bind(response).join())
        as Map<String, dynamic>;
  } finally {
    http.close(force: true);
  }
}

void main() {
  const enabled = bool.fromEnvironment('RUN_LOCAL_AUTH');
  const key = String.fromEnvironment('LOCAL_SUPABASE_PUBLISHABLE_KEY');
  test(
    'Supabase local: Auth, profile/RLS, PKCE recovery và mật khẩu mới',
    () async {
      // Chỉ chạy với stack local; không nhận URL cloud từ môi trường.
      expect(key, isNotEmpty);
      final client = SupabaseClient(
        'http://127.0.0.1:54321',
        key,
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: _PkceStorage(),
        ),
      );
      final other = SupabaseClient(
        'http://127.0.0.1:54321',
        key,
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: _PkceStorage(),
        ),
      );
      final anonymous = SupabaseClient('http://127.0.0.1:54321', key);
      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      final email = 'day1-a-$suffix@example.test';
      final emailB = 'day1-b-$suffix@example.test';
      final password = 'LocalTest-$suffix!';
      final newPassword = '${password}New';
      final createdIds = <String>[];
      final auth = AuthSessionService(client);
      final snapshots = <AuthSnapshot>[];
      final subscription = auth.watchSession().listen(snapshots.add);
      addTearDown(() async {
        await subscription.cancel();
        await client.dispose();
        await other.dispose();
        await anonymous.dispose();
        // Chỉ xóa UUID của tài khoản giả do chính test này vừa tạo.
        for (final id in createdIds) {
          if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(id)) {
            throw StateError('Invalid test UUID');
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
            "delete from auth.users where id = '$id' and email in ('$email','$emailB');",
          ]);
          expect(
            result.exitCode,
            0,
            reason: 'Clean up only accounts created by this test',
          );
        }
      });

      final registration = await auth.register(
        displayName: 'Local A',
        email: email,
        password: password,
      );
      expect(
        registration.needsEmailConfirmation,
        isFalse,
        reason: 'Local config disables signup confirmation; cloud behavior has a widget test',
      );
      createdIds.add(client.auth.currentUser!.id);
      final profileRepository = SupabaseProfileRepository(client);
      final identity = AuthIdentity(
        id: client.auth.currentUser!.id,
        displayName: 'Local A',
      );
      expect(
        (await profileRepository.getOrCreateMyProfile(identity)).displayName,
        'Local A',
      );
      expect(
        (await profileRepository.updateMyDisplayName('Local A updated'))
            .displayName,
        'Local A updated',
      );
      await other.auth.signUp(email: emailB, password: password);
      createdIds.add(other.auth.currentUser!.id);
      final bProfile = SupabaseProfileRepository(other);
      await bProfile.getOrCreateMyProfile(
        AuthIdentity(id: other.auth.currentUser!.id, displayName: 'Local B'),
      );
      expect(
        await other.from('profiles').select().eq('user_id', identity.id),
        isEmpty,
      );
      expect(
        await other
            .from('profiles')
            .update({'display_name': 'forged'})
            .eq('user_id', identity.id)
            .select(),
        isEmpty,
      );
      await expectLater(
        anonymous.from('profiles').select(),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        auth.completePasswordRecovery(newPassword),
        throwsA(isA<RecoverySessionRequired>()),
      );
      await auth.signOut();
      await expectLater(
        profileRepository.updateMyDisplayName('forged'),
        throwsA(isA<AuthSessionMissingException>()),
      );
      await auth.signIn(email: email, password: password);
      expect(client.auth.currentUser!.id, identity.id);
      await auth.signOut();
      await auth.requestPasswordReset(email);

      Map<String, dynamic>? message;
      for (var attempt = 0; attempt < 20 && message == null; attempt++) {
        final mailbox = await _json('/api/v1/messages');
        for (final raw in mailbox['messages'] as List) {
          final entry = raw as Map<String, dynamic>;
          final recipients = entry['To'] as List? ?? [];
          if (recipients.any((r) => (r as Map)['Address'] == email)) {
            message = await _json('/api/v1/message/${entry['ID']}');
            break;
          }
        }
        if (message == null) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      expect(
        message,
        isNotNull,
        reason: 'Local Mailpit must receive the recovery email',
      );
      final content = (message!['HTML'] ?? message['Text'] ?? '')
          .toString()
          .replaceAll('&amp;', '&');
      final link = RegExp(r'''https?://[^\s"<>]+/auth/v1/verify\?[^\s"<>]+''')
          .firstMatch(content)
          ?.group(0);
      expect(link, isNotNull);
      final http = HttpClient();
      late Uri callback;
      try {
        final request = await http.getUrl(Uri.parse(link!));
        request.followRedirects = false;
        final response = await request.close();
        callback = Uri.parse(
          response.headers.value(HttpHeaders.locationHeader)!,
        );
        await response.drain<void>();
      } finally {
        http.close(force: true);
      }
      expect(callback.scheme, 'studyshare');
      expect(callback.host, 'auth');
      expect(callback.queryParameters['code'], isNotNull);
      await client.auth.exchangeCodeForSession(
        callback.queryParameters['code']!,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        snapshots.last.recovering,
        isTrue,
        reason: 'Only a verified PKCE exchange may produce recovery state',
      );
      await auth.completePasswordRecovery(newPassword);
      expect(client.auth.currentSession, isNull);
      await expectLater(
        auth.signIn(email: email, password: password),
        throwsA(isA<AuthException>()),
      );
      await auth.signIn(email: email, password: newPassword);
      expect(client.auth.currentUser!.id, identity.id);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
