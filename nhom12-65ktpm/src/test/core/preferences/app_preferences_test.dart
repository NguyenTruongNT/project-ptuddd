import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyshare/core/preferences/app_preferences.dart';

import '../../support/controlled_preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Áp dụng ngay trước khi ghi xong; lỗi cũ không ghi đè lựa chọn mới',
    () async {
      final store = ControlledPreferencesStore();
      final container = ProviderContainer(
        overrides: [preferencesStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final controller = container.read(appPreferencesProvider.notifier);
      final first = controller.setThemeMode(ThemeMode.dark);
      final firstError = expectLater(first, throwsStateError);
      expect(container.read(appPreferencesProvider).themeMode, ThemeMode.dark);
      expect(
        container.read(preferencesSaveStateProvider).phase,
        PreferencesSavePhase.saving,
      );
      final second = controller.setLocale('en');
      expect(container.read(appPreferencesProvider).localeCode, 'en');
      await Future<void>.delayed(Duration.zero);
      store.writes[0].result.complete(false);
      await firstError;
      await Future<void>.delayed(Duration.zero);
      expect(container.read(appPreferencesProvider).themeMode, ThemeMode.dark);
      expect(container.read(appPreferencesProvider).localeCode, 'en');
      store.writes[1].result.complete(true);
      await second;
      expect(store.values['ui.preferences.v1'], contains('"locale":"en"'));
      expect(
        container.read(preferencesSaveStateProvider).phase,
        PreferencesSavePhase.saved,
      );
    },
  );

  test(
    'Lỗi cuối khôi phục bản lưu thành công gần nhất, lần sau vẫn lưu được',
    () async {
      final store = ControlledPreferencesStore();
      final container = ProviderContainer(
        overrides: [preferencesStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final controller = container.read(appPreferencesProvider.notifier);
      final first = controller.setThemeMode(ThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      store.writes[0].result.complete(true);
      await first;
      final second = controller.setLocale('en');
      final last = controller.setPalette(StudySharePalette.purple);
      final lastError = expectLater(last, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      store.writes[1].result.complete(true);
      await second;
      await Future<void>.delayed(Duration.zero);
      store.writes[2].result.complete(false);
      await lastError;
      final restored = container.read(appPreferencesProvider);
      expect(restored.themeMode, ThemeMode.dark);
      expect(restored.localeCode, 'en');
      expect(restored.palette, StudySharePalette.green);
      expect(
        container.read(preferencesSaveStateProvider).phase,
        PreferencesSavePhase.failed,
      );
      final retry = controller.setPalette(StudySharePalette.blue);
      await Future<void>.delayed(Duration.zero);
      store.writes[3].result.complete(true);
      await retry;
      expect(
        container.read(appPreferencesProvider).palette,
        StudySharePalette.blue,
      );
      expect(
        container.read(preferencesSaveStateProvider).phase,
        PreferencesSavePhase.saved,
      );
    },
  );
  test('Bộ lựa chọn được ghi cùng nhau và khôi phục sau mở lại', () async {
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
  });
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
