import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:studyshare/core/auth/auth_session_providers.dart';
import 'package:studyshare/core/config/supabase_settings.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/design_system/theme/studyshare_theme.dart';
import 'package:studyshare/design_system/widgets/study_feedback.dart';
import 'package:studyshare/features/materials/data/material_draft_store.dart';
import 'package:studyshare/features/materials/data/mock_material_workspace.dart';
import 'package:studyshare/features/materials/presentation/material_form_page.dart';
import 'package:studyshare/features/materials/presentation/material_details_page.dart';
import 'package:studyshare/features/materials/presentation/my_materials_page.dart';
import 'package:studyshare/features/materials/providers/material_providers.dart';
import 'package:studyshare/l10n/app_localizations.dart';

import '../../support/material_image_fixtures.dart';

class FixturePicker extends ImagePicker {
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    bool requestFullMetadata = true,
    int? limit,
  }) async => [
    XFile.fromData(
      materialJpegFixture(),
      name: 'cover.jpg',
      mimeType: 'image/jpeg',
    ),
  ];
}

class MemoryDraftStore extends MaterialDraftStore {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

Widget app(
  MockMaterialWorkspace repo, {
  String initial = '/materials/new',
  double scale = 1,
  Brightness brightness = Brightness.light,
  String locale = 'vi',
  MemoryDraftStore? drafts,
  ImagePicker? picker,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/materials/new',
        builder: (_, _) => const MaterialFormPage(),
      ),
      GoRoute(
        path: '/materials/:id/edit',
        builder: (_, s) =>
            MaterialFormPage(materialId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/materials/:id',
        builder: (_, s) =>
            MaterialDetailsPage(materialId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/materials', builder: (_, _) => const MyMaterialsPage()),
    ],
  );
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      supabaseSettingsProvider.overrideWithValue(
        const SupabaseSettings(url: '', publishableKey: ''),
      ),
      sessionBoundaryProvider.overrideWithValue(MockFixtures.userA),
      materialWorkspaceProvider.overrideWithValue(repo),
      materialDraftStoreProvider.overrideWithValue(
        drafts ?? MemoryDraftStore(),
      ),
      if (picker != null) materialImagePickerProvider.overrideWithValue(picker),
    ],
    child: MaterialApp.router(
      theme: StudyShareTheme.build(brightness),
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c)
            .copyWith(textScaler: TextScaler.linear(scale), padding: padding),
        child: StudyFeedbackHost(child: child!),
      ),
    ),
  );
}

Future<void> fill(WidgetTester tester) async {
  for (final pair in [
    ('material-title', 'Giáo trình mới'),
    ('material-subject', 'Toán'),
    ('material-condition', 'Có ghi chú'),
  ]) {
    final finder = find.byKey(ValueKey(pair.$1));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, pair.$2);
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Danh sách tôn trọng status bar khi mở từ Cá nhân không AppBar', (
    tester,
  ) async {
    final repo = MockMaterialWorkspace(MockMaterialStore(), MockFixtures.userA);
    await tester.pumpWidget(
      app(repo, initial: '/materials', padding: const EdgeInsets.only(top: 44)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Tài liệu của tôi')).dy,
      greaterThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Ảnh upload lỗi giữ preview; retry lưu đúng ảnh, không thành công giả',
    (tester) async {
      final repo = MockMaterialWorkspace(
        MockMaterialStore(seeded: false),
        MockFixtures.userA,
      )..failUpload = true;
      await tester.pumpWidget(app(repo, picker: FixturePicker()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('material-add-photo')),
      );
      await tester.tap(find.byKey(const ValueKey('material-add-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn từ thư viện'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ảnh bìa'), findsOneWidget);
      await fill(tester);
      await tester.tap(find.byKey(const ValueKey('material-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-action')));
      await tester.pumpAndSettle();
      expect(repo.store.values, isEmpty);
      expect(find.textContaining('Không thể tải ảnh'), findsWidgets);
      repo.failUpload = false;
      await tester.tap(find.byKey(const ValueKey('material-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-action')));
      await tester.pumpAndSettle();
      expect(repo.store.values, hasLength(1));
      expect(repo.store.values.values.single.images, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Tạo phải confirm; hủy giữ form, đồng ý mới lưu và mở detail', (
    tester,
  ) async {
    final repo = MockMaterialWorkspace(
      MockMaterialStore(seeded: false),
      MockFixtures.userA,
    );
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('material-save')))
          .onPressed,
      isNull,
    );
    await fill(tester);
    await tester.tap(find.byKey(const ValueKey('material-save')));
    await tester.pumpAndSettle();
    expect(repo.store.values, isEmpty);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(repo.store.values, isEmpty);
    await tester.tap(find.byKey(const ValueKey('material-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-action')));
    await tester.pumpAndSettle();
    expect(repo.store.values, hasLength(1));
    expect(find.text('Chi tiết tài liệu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Lỗi lưu giữ form; rời form lưu nháp theo tài khoản', (
    tester,
  ) async {
    final repo = MockMaterialWorkspace(
      MockMaterialStore(seeded: false),
      MockFixtures.userA,
    )..failSave = true;
    final drafts = MemoryDraftStore();
    await tester.pumpWidget(app(repo, drafts: drafts));
    await tester.pumpAndSettle();
    await fill(tester);
    await tester.tap(find.byKey(const ValueKey('material-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-action')));
    await tester.pumpAndSettle();
    expect(repo.store.values, isEmpty);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('material-title')))
          .controller!
          .text,
      'Giáo trình mới',
    );
    expect(drafts.values.keys, contains('${MockFixtures.userA}:new'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Chi tiết có giao dịch không có nút chỉnh sửa', (tester) async {
    final repo = MockMaterialWorkspace(MockMaterialStore(), MockFixtures.userA);
    await tester.pumpWidget(app(repo, initial: '/materials/mat-borrow-01'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('material-edit')), findsNothing);
    expect(find.textContaining('đang có giao dịch'), findsOneWidget);
  });
  for (final size in [
    (320.0, 568.0, 2.0),
    (360.0, 800.0, 1.0),
    (1440.0, 1000.0, 1.0),
  ]) {
    testWidgets('Material responsive $size', (tester) async {
      tester.view.physicalSize = Size(size.$1, size.$2);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final route in [
        '/materials',
        '/materials/new',
        '/materials/mat-borrow-01',
      ]) {
        final repo = MockMaterialWorkspace(
          MockMaterialStore(),
          MockFixtures.userA,
        );
        await tester.pumpWidget(
          app(
            repo,
            initial: route,
            scale: size.$3,
            brightness: Brightness.dark,
            locale: 'en',
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
        if (route.endsWith('/new')) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester
                .getBottomRight(find.byKey(const ValueKey('material-save')))
                .dy,
            lessThanOrEqualTo(size.$2 - 280),
            reason: 'Save stays visible above the keyboard',
          );
          tester.view.resetViewInsets();
        }
      }
    });
  }
}
