import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:studyshare/core/auth/auth_repository.dart';
import 'package:studyshare/core/auth/auth_session_service.dart';
import 'package:studyshare/core/config/supabase_settings.dart';

void main() {
  const settings = SupabaseSettings(
    url: 'https://example.supabase.co',
    publishableKey: 'sb_publishable_test',
  );

  for (final provider in SocialAuthProvider.values) {
    test('$provider chưa bật không mở trình duyệt hoặc tạo phiên', () async {
      final client = SupabaseClient(settings.url, settings.publishableKey);
      addTearDown(client.dispose);
      var launched = false;
      final transport = MockClient((request) async {
        expect(request.url.path, '/auth/v1/settings');
        expect(request.headers['apikey'], settings.publishableKey);
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response(
          jsonEncode({
            'external': {provider.name: false},
          }),
          200,
        );
      });
      addTearDown(transport.close);
      final service = AuthSessionService(
        client,
        settings: settings,
        oauthSettingsClient: transport,
        oauthLauncher: (_, _) async => launched = true,
      );
      await expectLater(
        service.signInWithProvider(provider),
        throwsA(isA<SocialAuthUnavailable>()),
      );
      expect(launched, isFalse);
      expect(client.auth.currentSession, isNull);
    });

    test(
      '$provider mở đúng provider/callback và vẫn đợi SDK xác thực',
      () async {
        final client = SupabaseClient(settings.url, settings.publishableKey);
        addTearDown(client.dispose);
        final transport = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'external': {provider.name: true},
            }),
            200,
          ),
        );
        addTearDown(transport.close);
        OAuthProvider? selected;
        String? redirect;
        final service = AuthSessionService(
          client,
          settings: settings,
          oauthSettingsClient: transport,
          oauthLauncher: (value, callback) async {
            selected = value;
            redirect = callback;
            return true;
          },
        );
        await service.signInWithProvider(provider);
        expect(selected?.name, provider.name);
        expect(redirect, 'studyshare://auth/callback');
        expect(client.auth.currentSession, isNull);
      },
    );
  }

  test(
    'Không mở được provider trả lỗi để UI kết thúc trạng thái chờ',
    () async {
      final client = SupabaseClient(settings.url, settings.publishableKey);
      addTearDown(client.dispose);
      final transport = MockClient(
        (_) async => http.Response('{"external":{"google":true}}', 200),
      );
      addTearDown(transport.close);
      final service = AuthSessionService(
        client,
        settings: settings,
        oauthSettingsClient: transport,
        oauthLauncher: (_, _) async => false,
      );
      await expectLater(
        service.signInWithProvider(SocialAuthProvider.google),
        throwsA(isA<SocialAuthUnavailable>()),
      );
      expect(client.auth.currentSession, isNull);
    },
  );
}
