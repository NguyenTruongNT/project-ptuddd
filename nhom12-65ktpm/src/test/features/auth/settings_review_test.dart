import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyshare/app/app_router.dart';
import 'package:studyshare/app/studyshare_app.dart';
import 'package:studyshare/core/auth/auth_session_providers.dart';
import 'package:studyshare/core/preferences/app_preferences.dart';

import 'auth_flow_test.dart' show frames;

void main() {
  testWidgets(
    'Cài đặt là nháp, Hủy confirm không ghi, Lưu confirm mới ghi toàn bộ',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [preferencesStoreProvider.overrideWithValue(store)],
          child: const StudyShareApp(),
        ),
      );
      await frames(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(StudyShareApp)),
      );
      container.read(demoModeProvider.notifier).enable();
      await frames(tester);
      container.read(appRouterProvider).push('/settings');
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('theme-dark')));
      await frames(tester);
      expect(
        container.read(appPreferencesProvider).themeMode,
        ThemeMode.system,
      );
      final save = find.byKey(const ValueKey('settings-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await frames(tester);
      expect(store.getString('ui.preferences.v1'), isNull);
      await tester.tap(find.text('Hủy').last);
      await frames(tester);
      expect(
        container.read(appPreferencesProvider).themeMode,
        ThemeMode.system,
      );
      await tester.tap(save);
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('confirm-action')));
      await frames(tester);
      expect(container.read(appPreferencesProvider).themeMode, ThemeMode.dark);
      expect(store.getString('ui.preferences.v1'), contains('dark'));
      expect(find.text('Đã lưu cài đặt.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets('Back có nháp: Hủy giữ trang, bỏ thay đổi mới rời trang', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: StudyShareApp()));
    await frames(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StudyShareApp)),
    );
    container.read(demoModeProvider.notifier).enable();
    await frames(tester);
    container.read(appRouterProvider).push('/settings');
    await frames(tester);
    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await frames(tester);
    await tester.tap(find.byTooltip('Quay lại'));
    await frames(tester);
    expect(find.text('Bỏ thay đổi chưa lưu?'), findsOneWidget);
    await tester.tap(find.text('Hủy').last);
    await frames(tester);
    expect(find.byKey(const ValueKey('theme-dark')), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await frames(tester);
    await tester.tap(find.byKey(const ValueKey('confirm-action')));
    await frames(tester);
    expect(find.byKey(const ValueKey('theme-dark')), findsNothing);
    expect(container.read(appPreferencesProvider).themeMode, ThemeMode.system);
  });
}
