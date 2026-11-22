import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/config/supabase_settings.dart';

void main() {
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
  });
}
