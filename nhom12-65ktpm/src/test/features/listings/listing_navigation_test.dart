import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/app/app_router.dart';
import 'package:studyshare/app/app_routes.dart';
import 'package:studyshare/app/studyshare_app.dart';
import 'package:studyshare/core/auth/auth_session_providers.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/listing_workspace.dart';
import 'package:studyshare/core/contracts/material_workspace.dart';
import 'package:studyshare/core/contracts/models/listing.dart';
import 'package:studyshare/core/contracts/models/material.dart' as model;
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/core/preferences/app_preferences.dart';
import 'package:studyshare/features/listings/data/listing_preview_repository.dart';
import 'package:studyshare/features/listings/presentation/listing_details_page.dart';
import 'package:studyshare/features/listings/presentation/listing_form_page.dart';
import 'package:studyshare/features/listings/presentation/listing_material_picker_page.dart';
import 'package:studyshare/features/listings/providers/listing_providers.dart';
import 'package:studyshare/features/materials/data/material_draft_store.dart';
import 'package:studyshare/features/materials/data/mock_material_workspace.dart';
import 'package:studyshare/features/materials/data/material_qr_repository.dart';
import 'package:studyshare/features/materials/presentation/material_qr_panel.dart';
import 'package:studyshare/features/home/presentation/home_page.dart';
import 'package:studyshare/features/materials/presentation/material_form_page.dart';
import 'package:studyshare/features/materials/providers/material_providers.dart';

const _materialId = 'e3300000-0000-4000-8000-000000000001';
const _listingId = 'e3300000-0000-4000-8000-000000000002';
const _material = model.Material(
  id: _materialId,
  ownerId: 'A',
  holderId: 'A',
  title: 'Giải tích',
  subject: 'Toán',
  condition: 'Tốt',
);

class _QuietPreferences extends AppPreferencesController {
  @override
  AppPreferences build() =>
      const AppPreferences(showLeaves: false, showGrid: false);
}

class _Drafts extends MaterialDraftStore {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    values[key] = value;
  }
}

class _Listings extends ListingPreviewRepository {
  final queries = <({String status, String query, int offset, int limit})>[];
  final commands = <ListingCommand>[];
  DomainErrorCode? failure;
  bool published = false;
  int rowCount = 1;
  @override
  Future<ListingPage<ManagedListing>> searchMine({
    String status = 'all',
    String query = '',
    int offset = 0,
    int limit = 20,
  }) async {
    queries.add((status: status, query: query, offset: offset, limit: limit));
    if (failure != null) throw AppError(failure!, '');
    final rows = !published
        ? <ManagedListing>[]
        : List.generate(
            rowCount,
            (i) => rowCount == 1
                ? managed
                : ManagedListing(
                    listing: managed.listing,
                    materialRevision: 1,
                    title: 'Tin $i',
                    canHide: true,
                  ),
          );
    return ListingPage(
      rows.skip(offset).take(limit).toList(),
      hasMore: offset + limit < rows.length,
    );
  }

  ManagedListing get managed => const ManagedListing(
    listing: Listing(
      id: _listingId,
      materialId: _materialId,
      offerType: OfferType.donate,
      status: ListingStatus.published,
    ),
    materialRevision: 1,
    title: 'Giải tích',
    canHide: true,
  );
  @override
  Future<ManagedListing?> getManaged({
    String? listingId,
    String? materialId,
  }) async => published ? managed : null;
  @override
  Future<CommandResult<ManagedListing>> execute(ListingCommand command) async {
    commands.add(command);
    published = true;
    return CommandOk.receipt(managed, commandId: 'receipt', serverRevision: 1);
  }

  @override
  Future<ListingDetails?> getPublishedDetails(String listingId) async =>
      published
      ? const ListingDetails(
          card: ListingCardModel(
            listingId: _listingId,
            materialId: _materialId,
            title: 'Giải tích',
            subject: 'Toán',
            offerType: OfferType.donate,
            isReserved: false,
            isRequestable: false,
            isOwner: true,
          ),
          ownerId: 'A',
          ownerName: 'A',
        )
      : null;
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Listings listings, {
  double scale = 1,
  String? location,
}) async {
  final store = MockMaterialStore(seeded: false);
  store.values[_materialId] = const MaterialDetails(
    material: _material,
    images: [MaterialImage(id: 'i', storagePath: 'p')],
  );
  final container = ProviderContainer(
    overrides: [
      demoModeProvider.overrideWith(() => DemoModeController(initial: true)),
      // Router khởi tạo Home trước khi mở đích test; toàn bộ scope này là demo.
      workflowRpcProvider.overrideWithValue(null),
      sessionBoundaryProvider.overrideWithValue('A'),
      appPreferencesProvider.overrideWith(_QuietPreferences.new),
      materialWorkspaceProvider.overrideWithValue(
        MockMaterialWorkspace(store, 'A'),
      ),
      mockMaterialStoreProvider.overrideWithValue(store),
      materialQrRepositoryProvider.overrideWithValue(
        MockMaterialQrRepository(store, 'A'),
      ),
      listingWorkspaceProvider.overrideWithValue(listings),
      materialDraftStoreProvider.overrideWithValue(_Drafts()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: const StudyShareApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  container.read(appRouterProvider).go(location ?? AppRoutes.publishTab);
  await tester.pumpAndSettle();
  return container;
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

void main() {
  testWidgets(
    'Home → Material → công bố Listing → chi tiết, Back không về form cũ',
    (tester) async {
      final listings = _Listings();
      await _mount(tester, listings, location: AppRoutes.home);
      await _tap(tester, find.text('Tài liệu của tôi'));
      await _tap(tester, find.text('Giải tích'));
      await _tap(tester, find.text('Chọn tài liệu để đăng'));
      await _tap(tester, find.byKey(const ValueKey('listing-offer-DONATE')));
      await _tap(tester, find.byKey(const ValueKey('listing-publish')));
      await _tap(tester, find.byKey(const ValueKey('confirm-action')));
      expect(find.byType(ListingDetailsPage), findsOneWidget);
      expect(listings.commands, hasLength(1));
      await _tap(tester, find.byType(BackButton));
      expect(find.byType(ListingFormPage), findsNothing);
      expect(find.byKey(const ValueKey('material-qr-load')), findsOneWidget);
    },
  );
  testWidgets(
    'Router thật: Home → Material → QR, mỗi màn con Back về đúng nguồn',
    (tester) async {
      await _mount(tester, _Listings(), location: AppRoutes.home);
      await _tap(tester, find.text('Tài liệu của tôi'));
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
      await _tap(tester, find.text('Giải tích'));
      await _tap(tester, find.byKey(const ValueKey('material-qr-load')));
      await _tap(tester, find.text('Mở QR lớn'));
      expect(find.byType(MaterialQrPage), findsOneWidget);
      await _tap(tester, find.byType(BackButton));
      expect(find.byType(MaterialQrPage), findsNothing);
      await _tap(tester, find.byType(BackButton));
      expect(find.text('Tài liệu của tôi'), findsOneWidget);
      await _tap(tester, find.byType(BackButton));
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );
  testWidgets(
    'Sửa Material từ SCR-10 lưu xong về form nguồn, không chồng trang chi tiết',
    (tester) async {
      await _mount(tester, _Listings());
      await _tap(tester, find.byKey(const ValueKey('listing-create')));
      await _tap(
        tester,
        find.byKey(const ValueKey('listing-material-$_materialId')),
      );
      await _tap(tester, find.text('Chỉnh sửa'));
      expect(find.byType(MaterialFormPage), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('material-condition')),
        'Còn tốt',
      );
      await _tap(tester, find.byKey(const ValueKey('material-save')));
      await _tap(tester, find.byKey(const ValueKey('confirm-action')));
      expect(find.byType(ListingFormPage), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Còn tốt'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Còn tốt'), findsWidgets);
    },
  );
  testWidgets('Quay từ tin đã xem ở trang 2 giữ đủ dữ liệu và vị trí cuộn', (
    tester,
  ) async {
    final listings = _Listings()
      ..published = true
      ..rowCount = 45;
    await _mount(tester, listings);
    await _tap(tester, find.text('Tải thêm'));
    final row = find.text('Tin 35');
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final list = tester.widget<ListView>(
      find.byKey(const PageStorageKey('publish-A')),
    );
    final offset = list.controller!.offset;
    await tester.tap(row);
    await tester.pumpAndSettle();
    await _tap(tester, find.byType(BackButton));
    expect(listings.queries.last.limit, 40);
    expect(
      tester
          .widget<ListView>(find.byKey(const PageStorageKey('publish-A')))
          .controller!
          .offset,
      closeTo(offset, 1),
    );
  });

  testWidgets(
    'Mobile hẹp/chữ lớn: bộ lọc, bảng lựa chọn và màn con không tràn',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _mount(tester, _Listings());
      await _tap(tester, find.byKey(const ValueKey('listing-status-filter')));
      await _tap(tester, find.byKey(const ValueKey('listing-status-ARCHIVED')));
      await _tap(tester, find.byKey(const ValueKey('listing-create')));
      expect(find.byType(ListingMaterialPickerPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _tap(tester, find.byType(BackButton));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Router thật: màn chọn có Back, không có bottom nav; quay lại giữ lọc/từ khóa',
    (tester) async {
      final listings = _Listings();
      await _mount(tester, listings);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Thêm tài liệu'), findsNothing);
      expect(find.text('StudyShare'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('listing-search')),
        'Giải tích',
      );
      await _tap(tester, find.byKey(const ValueKey('listing-status-filter')));
      await _tap(tester, find.byKey(const ValueKey('listing-status-HIDDEN')));
      await _tap(tester, find.byKey(const ValueKey('listing-create')));
      expect(find.byType(ListingMaterialPickerPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Chọn tài liệu'), findsOneWidget);
      await _tap(tester, find.byType(BackButton));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('listing-search')))
            .controller!
            .text,
        'Giải tích',
      );
      expect(listings.queries.last.status, 'HIDDEN');
      expect(listings.queries.last.query, 'Giải tích');
    },
  );

  testWidgets(
    'Công bố từ màn chọn: Back ở chi tiết về tab, không lặp lại form',
    (tester) async {
      final listings = _Listings();
      await _mount(tester, listings);
      await _tap(tester, find.byKey(const ValueKey('listing-create')));
      await _tap(
        tester,
        find.byKey(const ValueKey('listing-material-$_materialId')),
      );
      expect(find.text('Tạo tin đăng'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('listing-offer-DONATE')));
      await _tap(tester, find.byKey(const ValueKey('listing-publish')));
      await _tap(tester, find.byKey(const ValueKey('confirm-action')));
      expect(listings.commands, hasLength(1));
      expect(find.byType(ListingDetailsPage), findsOneWidget);
      await _tap(tester, find.byType(BackButton));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(ListingFormPage), findsNothing);
      expect(find.byType(ListingMaterialPickerPage), findsNothing);
    },
  );

  testWidgets(
    'Thêm Material từ màn chọn: lưu ACK quay đúng bước, không tự tạo Listing',
    (tester) async {
      final listings = _Listings();
      await _mount(tester, listings);
      await _tap(tester, find.byKey(const ValueKey('listing-create')));
      await _tap(tester, find.byKey(const ValueKey('listing-add-material')));
      expect(find.byType(MaterialFormPage), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('material-title')),
        'Sách mới',
      );
      await tester.enterText(
        find.byKey(const ValueKey('material-subject')),
        'Tin học',
      );
      await tester.enterText(
        find.byKey(const ValueKey('material-condition')),
        'Tốt',
      );
      await _tap(tester, find.byKey(const ValueKey('material-save')));
      await _tap(tester, find.byKey(const ValueKey('confirm-action')));
      expect(find.byType(ListingMaterialPickerPage), findsOneWidget);
      expect(find.text('Sách mới'), findsWidgets);
      expect(listings.commands, isEmpty);
    },
  );

  testWidgets(
    'Mở màn chọn trực tiếp: Android Back trở về tab; lỗi vẫn có header',
    (tester) async {
      await _mount(
        tester,
        _Listings(),
        location: AppRoutes.listingMaterialPicker,
      );
      expect(find.byType(BackButton), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets(
    'Thiếu RPC hiện lỗi khả dụng, không báo xung đột và không giả empty',
    (tester) async {
      await _mount(
        tester,
        _Listings()..failure = DomainErrorCode.backendUnavailable,
      );
      expect(
        find.textContaining('Chức năng đăng tin tạm thời'),
        findsOneWidget,
      );
      expect(find.textContaining('Dữ liệu đã thay đổi'), findsNothing);
      expect(find.text('Chưa có tin đăng trong mục này.'), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('listing-create')));
      expect(find.byType(BackButton), findsOneWidget);
    },
  );
}
