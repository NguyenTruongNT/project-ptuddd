import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:studyshare/core/auth/auth_session_providers.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/material_qr.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/features/materials/presentation/material_qr_panel.dart';
import 'package:studyshare/features/materials/providers/material_providers.dart';
import 'package:studyshare/l10n/app_localizations.dart';

const _id = 'e4400000-0000-4000-8000-000000000001';
final _qr = MaterialQr(
  materialId: _id,
  title: 'Giáo trình',
  payload: 'studyshare:material:1:$_id:${'a' * 64}',
  version: 1,
  issuedAt: DateTime.utc(2026, 11, 27),
);

class _Boundary extends Notifier<String> {
  @override
  String build() => 'owner';
  void change(String actor) => state = actor;
}

final _boundary = NotifierProvider<_Boundary, String>(_Boundary.new);

class _QrRepo implements MaterialQrRepository {
  final keys = <String>[];
  Future<CommandResult<MaterialQr>> Function() reply = () async =>
      CommandOk(_qr, null);
  @override
  Future<CommandResult<MaterialQr>> ensureQr(
    String id, {
    required String idempotencyKey,
  }) {
    keys.add(idempotencyKey);
    return reply();
  }
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _QrRepo repo, {
  bool enabled = true,
  bool page = false,
}) async {
  final container = ProviderContainer(
    overrides: [
      materialQrRepositoryProvider.overrideWithValue(repo),
      sessionBoundaryProvider.overrideWith((ref) => ref.watch(_boundary)),
    ],
  );
  final router = GoRouter(
    initialLocation: '/materials/$_id/qr',
    routes: [
      GoRoute(
        path: '/materials/:id/qr',
        builder: (_, _) => page
            ? const MaterialQrPage(materialId: _id)
            : Scaffold(
                body: SingleChildScrollView(
                  child: MaterialQrPanel(materialId: _id, enabled: enabled),
                ),
              ),
      ),
      GoRoute(
        path: '/materials/:id',
        builder: (_, _) => const Scaffold(body: Text('Trang tài liệu')),
      ),
    ],
  );
  addTearDown(() {
    router.dispose();
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    'Chỉ xin QR khi bấm mở, retry giữ key và không lộ payload dạng chữ',
    (tester) async {
      final repo = _QrRepo();
      await _mount(tester, repo);
      expect(repo.keys, isEmpty);
      repo.reply = () async =>
          const CommandError(DomainErrorCode.timeoutUnknown, '');
      await tester.tap(find.byKey(const ValueKey('material-qr-load')));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      repo.reply = () async => CommandOk(_qr, null);
      await tester.tap(find.byKey(const ValueKey('material-qr-load')));
      await tester.pumpAndSettle();
      expect(repo.keys.toSet(), hasLength(1));
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text(_qr.payload), findsNothing);
      expect(find.text('Giáo trình'), findsOneWidget);
    },
  );

  testWidgets('Dữ liệu Material offline không cho xin QR', (tester) async {
    final repo = _QrRepo();
    await _mount(tester, repo, enabled: false);
    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('material-qr-load')),
    );
    expect(button.onPressed, isNull);
    expect(repo.keys, isEmpty);
  });

  testWidgets(
    'Ra nền xóa QR; mở lại kiểm tra server và vẫn cùng ý định phát hành',
    (tester) async {
      final repo = _QrRepo();
      await _mount(tester, repo);
      await tester.tap(find.byKey(const ValueKey('material-qr-load')));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      await tester.tap(find.byKey(const ValueKey('material-qr-load')));
      await tester.pumpAndSettle();
      expect(repo.keys.toSet(), hasLength(1));
      expect(find.byType(QrImageView), findsOneWidget);
    },
  );

  testWidgets('Đổi phiên trong lúc đang tải không hiển thị QR trả về muộn', (
    tester,
  ) async {
    final pending = Completer<CommandResult<MaterialQr>>();
    final repo = _QrRepo()..reply = () => pending.future;
    final container = await _mount(tester, repo);
    await tester.tap(find.byKey(const ValueKey('material-qr-load')));
    await tester.pump();
    container.read(_boundary.notifier).change('another-owner');
    await tester.pump();
    pending.complete(CommandOk(_qr, null));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    repo.reply = () async => const CommandError(DomainErrorCode.forbidden, '');
    await tester.tap(find.byKey(const ValueKey('material-qr-load')));
    await tester.pumpAndSettle();
    expect(repo.keys.toSet(), hasLength(2));
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets(
    'URL QR trực tiếp luôn có Back về Material kể cả khi server lỗi',
    (tester) async {
      final repo = _QrRepo()
        ..reply = () async => const CommandError(DomainErrorCode.forbidden, '');
      await _mount(tester, repo, page: true);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Trang tài liệu'), findsOneWidget);
    },
  );
}
