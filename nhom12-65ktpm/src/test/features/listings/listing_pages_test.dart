import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:studyshare/core/auth/auth_session_providers.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/listing_workspace.dart';
import 'package:studyshare/core/contracts/material_workspace.dart';
import 'package:studyshare/core/contracts/models/material.dart' as model;
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/features/listings/data/listing_preview_repository.dart';
import 'package:studyshare/features/listings/presentation/listing_form_page.dart';
import 'package:studyshare/features/listings/providers/listing_providers.dart';
import 'package:studyshare/features/materials/data/material_draft_store.dart';
import 'package:studyshare/features/materials/data/mock_material_workspace.dart';
import 'package:studyshare/features/materials/providers/material_providers.dart';
import 'package:studyshare/features/listings/data/supabase_listing_workspace.dart';
import 'package:studyshare/l10n/app_localizations.dart';

class _Drafts extends MaterialDraftStore {
  final entries = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async => entries[key];
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    entries[key] = value;
  }
}

class _Materials extends MockMaterialWorkspace {
  _Materials({this.photo = true}) : super(MockMaterialStore(), 'A');
  final bool photo;
  @override
  Future<MaterialDetails?> getDetails(String id) async => MaterialDetails(
    material: const model.Material(
      id: 'm',
      ownerId: 'A',
      holderId: 'A',
      title: 'Giải tích',
      subject: 'Toán',
      condition: 'Tốt',
    ),
    images: photo
        ? [const MaterialImage(id: 'image', storagePath: 'private')]
        : [],
  );
}

class _Listings extends ListingPreviewRepository {
  final commands = <ListingCommand>[];
  bool unknown = false, offline = false, alreadyPublished = false;
  bool hidden = false;
  @override
  Future<ManagedListing?> getManaged({
    String? listingId,
    String? materialId,
  }) async {
    if (offline) {
      throw const AppError(DomainErrorCode.networkUnavailable, 'offline');
    }
    return alreadyPublished || hidden ? result() : null;
  }

  ManagedListing result() => SupabaseListingWorkspace.decodeManaged({
    'id': 'l',
    'material_id': 'm',
    'offer_type': 'SELL',
    'status': hidden ? 'HIDDEN' : 'PUBLISHED',
    'can_edit': hidden,
    'can_show': hidden,
    'revision': 2,
    'material_revision': 1,
    'asking_price_vnd': 100,
  });
  @override
  Future<CommandResult<ManagedListing>> execute(ListingCommand command) async {
    commands.add(command);
    if (unknown) {
      return const CommandError(DomainErrorCode.timeoutUnknown, 'unknown');
    }
    return CommandOk.receipt(result(), commandId: 'receipt', serverRevision: 2);
  }

  @override
  Future<CommandResult<ManagedListing>?> getCommandResult(
    ListingCommand command,
  ) async =>
      CommandOk.receipt(result(), commandId: 'receipt', serverRevision: 2);
}

Widget _app(
  _Listings repo,
  _Drafts drafts, {
  bool photo = true,
  double scale = 1,
}) {
  final router = GoRouter(
    initialLocation: '/listings/new?materialId=m',
    routes: [
      GoRoute(
        path: '/listings/new',
        builder: (_, _) => const ListingFormPage(materialId: 'm'),
      ),
      GoRoute(
        path: '/listings/:id',
        builder: (_, _) => const Scaffold(body: Text('SERVER DETAILS')),
      ),
      GoRoute(
        path: '/publish',
        builder: (_, _) => const Scaffold(body: Text('PUBLISH TAB')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sessionBoundaryProvider.overrideWithValue('A'),
      listingWorkspaceProvider.overrideWithValue(repo),
      materialWorkspaceProvider.overrideWithValue(_Materials(photo: photo)),
      materialDraftStoreProvider.overrideWithValue(drafts),
    ],
    child: MaterialApp.router(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    ),
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _sell(WidgetTester tester) async {
  await _tap(tester, find.byKey(const ValueKey('listing-offer-SELL')));
  await tester.enterText(find.byKey(const ValueKey('listing-price')), '100');
}

void main() {
  testWidgets(
    'Lưu local không cho hiện lại nội dung HIDDEN chưa đồng bộ server',
    (tester) async {
      final repo = _Listings()..hidden = true;
      await tester.pumpWidget(_app(repo, _Drafts()));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('listing-price')),
        '200',
      );
      await _tap(tester, find.text('Lưu nháp trên thiết bị'));
      await tester.scrollUntilVisible(
        find.text('Hiện lại tin'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Hiện lại tin'),
            )
            .onPressed,
        isNull,
      );
      expect(repo.commands, isEmpty);
    },
  );
  testWidgets(
    'Mở lại sau mất ACK vẫn thấy command lưu dưới Material ID trước khi có Listing ID',
    (tester) async {
      final repo = _Listings()..alreadyPublished = true;
      final drafts = _Drafts();
      const pending = ListingCommand(
        action: ListingAction.publish,
        materialId: 'm',
        expectedMaterialRevision: 1,
        idempotencyKey: 'original-key',
      );
      await drafts.write('listing-drafts:A', {
        'm': {
          'material_id': 'm',
          'offer': 'SELL',
          'price': '100',
          'pending': pending.toRpc(),
          'material_revision': 1,
          'listing_revision': null,
        },
      });
      await tester.pumpWidget(_app(repo, drafts));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('listing-retry-command')));
      expect(repo.commands, isEmpty);
      expect(find.text('SERVER DETAILS'), findsOneWidget);
      expect(drafts.entries['listing-drafts:A'], isEmpty);
    },
  );
  testWidgets('Thiếu ảnh chặn công bố nhưng lưu nháp trên thiết bị được', (
    tester,
  ) async {
    final repo = _Listings(), drafts = _Drafts();
    await tester.pumpWidget(_app(repo, drafts, photo: false));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('listing-publish')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('listing-publish')),
    );
    expect(button.onPressed, isNull);
    await _tap(tester, find.text('Lưu nháp trên thiết bị'));
    expect(drafts.entries, isNotEmpty);
    expect(repo.commands, isEmpty);
  });
  testWidgets('Giá sai không gửi; công bố chỉ sau confirm, cancel giữ form', (
    tester,
  ) async {
    final repo = _Listings();
    await tester.pumpWidget(_app(repo, _Drafts()));
    await tester.pumpAndSettle();
    await _sell(tester);
    await _tap(tester, find.byKey(const ValueKey('listing-offer-SELL')));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('listing-price')))
          .controller!
          .text,
      '100',
    );
    await tester.enterText(find.byKey(const ValueKey('listing-price')), '1.5');
    await _tap(tester, find.byKey(const ValueKey('listing-publish')));
    expect(repo.commands, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('listing-price')), '100');
    await _tap(tester, find.byKey(const ValueKey('listing-publish')));
    expect(repo.commands, isEmpty);
    await _tap(tester, find.text('Hủy'));
    expect(find.byKey(const ValueKey('listing-price')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('listing-publish')));
    await _tap(tester, find.byKey(const ValueKey('confirm-action')));
    expect(repo.commands.single.askingPriceVnd, 100);
    expect(find.text('SERVER DETAILS'), findsOneWidget);
  });
  testWidgets('Mất ACK giữ command/key, tra receipt thay vì tạo command mới', (
    tester,
  ) async {
    final repo = _Listings()..unknown = true;
    final drafts = _Drafts();
    await tester.pumpWidget(_app(repo, drafts));
    await tester.pumpAndSettle();
    await _sell(tester);
    await _tap(tester, find.byKey(const ValueKey('listing-publish')));
    await _tap(tester, find.byKey(const ValueKey('confirm-action')));
    expect(repo.commands.length, 1);
    expect(drafts.entries, isNotEmpty);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('listing-price')))
          .enabled,
      isFalse,
    );
    await _tap(tester, find.byKey(const ValueKey('listing-retry-command')));
    expect(repo.commands.length, 1);
    expect(find.text('SERVER DETAILS'), findsOneWidget);
  });
  testWidgets('Offline khôi phục nháp riêng và chỉ sửa local', (tester) async {
    final repo = _Listings()..offline = true;
    final drafts = _Drafts();
    await drafts.write('listing-drafts:A', {
      'm': {
        'material_id': 'm',
        'material_revision': 1,
        'listing_revision': null,
        'material': {
          'title': 'Nháp offline',
          'subject': 'Toán',
          'condition': 'Tốt',
          'holder_id': 'A',
        },
        'offer': 'SELL',
        'price': '100',
        'description': 'Nháp riêng',
        'area': '',
      },
    });
    await tester.pumpWidget(_app(repo, drafts));
    await tester.pumpAndSettle();
    expect(find.text('Nháp offline'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('listing-price')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('listing-price')))
          .enabled,
      isTrue,
    );
    expect(find.byKey(const ValueKey('listing-publish')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('listing-price')), '200');
    await _tap(tester, find.text('Lưu nháp trên thiết bị'));
    expect(repo.commands, isEmpty);
    expect((drafts.entries['listing-drafts:A']!['m'] as Map)['price'], '200');
  });
  testWidgets('SCR-10 không tràn ở màn hẹp và chữ lớn', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(_Listings(), _Drafts(), scale: 2));
    await tester.pumpAndSettle();
    await _sell(tester);
    expect(tester.takeException(), isNull);
  });
}
