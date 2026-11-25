import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/config/supabase_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseSettings', () {
    test('khong co key thi app chi chay giao dien mock', () {
      const config = SupabaseSettings(url: '', publishableKey: '');
      expect(config.isConfigured, isFalse);
    });

    test('khong chap nhan URL khong hop le', () {
      const config = SupabaseSettings(
        url: 'khong-phai-url',
        publishableKey: 'sb_publishable_example',
      );
      expect(config.isConfigured, isFalse);
    });

    test('chap nhan URL HTTPS va publishable key', () {
      const config = SupabaseSettings(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_publishable_example',
      );
      expect(config.isConfigured, isTrue);
    });

    test('cho phep HTTP khi test Supabase local', () {
      const config = SupabaseSettings(
        url: 'http://10.0.2.2:54321',
        publishableKey: 'local-test-key',
      );
      expect(config.isConfigured, isTrue);
    });

    test('pull code ve co san cau hinh development trong asset', () async {
      final config = await SupabaseSettings.load(
        environment: const SupabaseSettings(url: '', publishableKey: ''),
      );
      expect(config.isConfigured, isTrue);
      expect(Uri.parse(config.url).scheme, 'https');
      expect(config.publishableKey, startsWith('sb_publishable_'));
    });

    test('ghi de day du URL va key thi khong doc asset development', () async {
      final bundle = _ConfigBundle('khong-phai-json');
      const local = SupabaseSettings(
        url: 'http://10.0.2.2:54321',
        publishableKey: 'local-test-key',
      );
      final config = await SupabaseSettings.load(
        bundle: bundle,
        environment: local,
      );
      expect(config, same(local));
      expect(bundle.reads, 0);
    });

    test(
      'tat Supabase thi khong doc asset hoac dung cau hinh ghi de',
      () async {
        final bundle = _ConfigBundle('khong-phai-json');
        final config = await SupabaseSettings.load(
          bundle: bundle,
          enabled: false,
          environment: const SupabaseSettings(
            url: 'https://override.example',
            publishableKey: 'sb_publishable_override',
          ),
        );
        expect(config.isConfigured, isFalse);
        expect(config.url, isEmpty);
        expect(config.publishableKey, isEmpty);
        expect(bundle.reads, 0);
      },
    );

    for (final incomplete in [
      const SupabaseSettings(
        url: 'https://override.example',
        publishableKey: '',
      ),
      const SupabaseSettings(
        url: '',
        publishableKey: 'sb_publishable_override',
      ),
      const SupabaseSettings(
        url: 'khong-phai-url',
        publishableKey: 'sb_publishable_override',
      ),
    ].indexed) {
      test(
        'ghi de khong hop le ${incomplete.$1} khong tron voi asset',
        () async {
          final bundle = _ConfigBundle('{}');
          await expectLater(
            SupabaseSettings.load(bundle: bundle, environment: incomplete.$2),
            throwsFormatException,
          );
          expect(bundle.reads, 0);
        },
      );
    }

    final invalidAssets = <String, String>{
      'JSON sai cu phap': '{',
      'JSON khong phai object': '[]',
      'thieu URL va key': '{}',
      'sai kieu du lieu': jsonEncode({
        'SUPABASE_URL': 'https://example.supabase.co',
        'SUPABASE_PUBLISHABLE_KEY': 123,
      }),
      'truong ngoai danh sach cong khai': jsonEncode({
        'SUPABASE_URL': 'https://example.supabase.co',
        'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_example',
        'SERVICE_ROLE_KEY': 'khong-duoc-dong-goi',
      }),
      'URL khong hop le': jsonEncode({
        'SUPABASE_URL': 'khong-phai-url',
        'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_example',
      }),
      'Cloud khong dung HTTPS': jsonEncode({
        'SUPABASE_URL': 'http://example.supabase.co',
        'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_example',
      }),
      'khoa khong phai publishable': jsonEncode({
        'SUPABASE_URL': 'https://example.supabase.co',
        'SUPABASE_PUBLISHABLE_KEY': 'sb_secret_khong-duoc-dong-goi',
      }),
    };
    for (final entry in invalidAssets.entries) {
      test('tu choi asset ${entry.key}', () async {
        await expectLater(
          SupabaseSettings.load(
            bundle: _ConfigBundle(entry.value),
            environment: const SupabaseSettings(url: '', publishableKey: ''),
          ),
          throwsFormatException,
        );
      });
    }

    test('thieu asset thi bao loi thay vi am tham chuyen sang demo', () async {
      await expectLater(
        SupabaseSettings.load(
          bundle: _MissingConfigBundle(),
          environment: const SupabaseSettings(url: '', publishableKey: ''),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class _ConfigBundle extends CachingAssetBundle {
  _ConfigBundle(this.content);

  final String content;
  int reads = 0;

  @override
  Future<ByteData> load(String key) async {
    expect(key, SupabaseSettings.publicConfigAsset);
    reads++;
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}

class _MissingConfigBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw StateError('Thieu asset');
}
