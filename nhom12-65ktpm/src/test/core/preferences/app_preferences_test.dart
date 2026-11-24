import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyshare/core/preferences/app_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Bộ lựa chọn xác nhận được ghi cùng nhau và khôi phục sau mở lại',
    () async {
      SharedPreferences.setMockInitialValues({
        'ui.theme': 'light',
        'ui.locale': 'vi',
      });
      final store = await SharedPreferences.getInstance();
      final first = ProviderContainer(
        overrides: [preferencesStoreProvider.overrideWithValue(store)],
      );
      expect(first.read(appPreferencesProvider).themeMode, ThemeMode.light);
      await first
          .read(appPreferencesProvider.notifier)
          .savePreferences(
            const AppPreferences(
              themeMode: ThemeMode.dark,
              localeCode: 'en',
              palette: StudySharePalette.blue,
              showGrid: false,
              showLeaves: false,
            ),
          );
      first.dispose();
      final restored = ProviderContainer(
        overrides: [preferencesStoreProvider.overrideWithValue(store)],
      );
      addTearDown(restored.dispose);
      expect(
        restored
            .read(appPreferencesProvider)
            .sameAs(
              const AppPreferences(
                themeMode: ThemeMode.dark,
                localeCode: 'en',
                palette: StudySharePalette.blue,
                showGrid: false,
                showLeaves: false,
              ),
            ),
        isTrue,
      );
    },
  );
  test('Khôi phục lựa chọn sau khi tạo lại container, không mất thay đổi đồng thời', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SharedPreferences.getInstance();
    final first = ProviderContainer(
      overrides: [preferencesStoreProvider.overrideWithValue(store)],
    );
    final controller = first.read(appPreferencesProvider.notifier);
    await Future.wait([
      controller.setThemeMode(ThemeMode.dark),
      controller.setLocale('en'),
      controller.setLeaves(false),
      controller.setPalette(StudySharePalette.purple),
    ]);
    expect(first.read(appPreferencesProvider).themeMode, ThemeMode.dark);
    expect(first.read(appPreferencesProvider).localeCode, 'en');
    first.dispose();
    final second = ProviderContainer(
      overrides: [preferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(second.dispose);
    final restored = second.read(appPreferencesProvider);
    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.localeCode, 'en');
    expect(restored.showLeaves, isFalse);
    expect(restored.palette, StudySharePalette.purple);
    expect(
      () => second.read(appPreferencesProvider.notifier).setLocale('invalid'),
      throwsArgumentError,
    );
  });
  test('Giá trị enum không biết dùng cấu hình mặc định an toàn', () async {
    SharedPreferences.setMockInitialValues({
      'ui.theme': 'invalid',
      'ui.palette': 'invalid',
      'ui.locale': 'xx',
    });
    final store = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [preferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    expect(container.read(appPreferencesProvider).themeMode, ThemeMode.system);
    expect(container.read(appPreferencesProvider).localeCode, 'vi');
  });
}
