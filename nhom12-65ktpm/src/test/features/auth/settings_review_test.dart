import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyshare/app/app_router.dart';
import 'package:studyshare/app/studyshare_app.dart';
import 'package:studyshare/core/auth/auth_session_providers.dart';
import 'package:studyshare/core/preferences/app_preferences.dart';
import 'package:studyshare/features/profile_settings/settings_page.dart';

import '../../support/controlled_preferences_store.dart';
import 'auth_flow_test.dart' show frames;

Future<ProviderContainer> startSettings(
  WidgetTester tester, {
  SharedPreferences? store,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        demoModeProvider.overrideWith(() => DemoModeController(initial: true)),
        if (store != null) preferencesStoreProvider.overrideWithValue(store),
      ],
      child: const StudyShareApp(),
    ),
  );
  await frames(tester);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(StudyShareApp)),
  );
  container.read(appRouterProvider).go('/profile');
  await frames(tester);
  container.read(appRouterProvider).push('/settings');
  await frames(tester);
  return container;
}

void main() {
  testWidgets('Ngôn ngữ đổi ngay, dịch nhãn màu và toast sau khi tự lưu', (
    tester,
  ) async {
    final container = await startSettings(tester);
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await frames(tester);
    await tester.tap(find.text('English').last);
    await frames(tester);
    expect(container.read(appPreferencesProvider).localeCode, 'en');
    expect(find.text('Green'), findsOneWidget);
    expect(find.text('Xanh lá'), findsNothing);
    expect(find.byKey(const ValueKey('settings-save')), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('study-toast')),
        matching: find.text('Settings saved.'),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
    'Thay đổi liên tiếp áp dụng ngay, gộp toast và lưu được sau Back',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await SharedPreferences.getInstance();
      final container = await startSettings(tester, store: store);
      await tester.tap(find.byKey(const ValueKey('theme-dark')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(appPreferencesProvider).themeMode, ThemeMode.dark);
      await tester.tap(find.byKey(const ValueKey('palette-blue')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        container.read(appPreferencesProvider).palette,
        StudySharePalette.blue,
      );
      expect(find.byKey(const ValueKey('study-toast')), findsNothing);
      await tester.tap(find.byTooltip('Quay lại'));
      await frames(tester);
      expect(find.byType(SettingsPage), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('study-toast')), findsOneWidget);
      expect(store.getString('ui.preferences.v1'), contains('blue'));
      final restored = ProviderContainer(
        overrides: [preferencesStoreProvider.overrideWithValue(store)],
      );
      addTearDown(restored.dispose);
      expect(restored.read(appPreferencesProvider).themeMode, ThemeMode.dark);
      expect(
        restored.read(appPreferencesProvider).palette,
        StudySharePalette.blue,
      );
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets('Lỗi ghi sau khi rời trang khôi phục giao diện và báo lỗi', (
    tester,
  ) async {
    final store = ControlledPreferencesStore();
    final container = await startSettings(tester, store: store);
    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await frames(tester);
    expect(container.read(appPreferencesProvider).themeMode, ThemeMode.dark);
    expect(find.text('Đang lưu…'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await frames(tester);
    expect(find.byType(SettingsPage), findsNothing);
    store.writes.single.result.complete(false);
    await frames(tester);
    expect(container.read(appPreferencesProvider).themeMode, ThemeMode.system);
    expect(
      find.text(
        'Không lưu được lựa chọn. Đã khôi phục cài đặt đã lưu trước đó.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
  });
}
