import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:studyshare/app/app_routes.dart';
import 'package:studyshare/core/auth/auth_session_providers.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/listing_workspace.dart';
import 'package:studyshare/core/contracts/models/listing.dart';
import 'package:studyshare/core/contracts/models/material.dart' as model;
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/core/preferences/app_preferences.dart';
import 'package:studyshare/features/home/domain/home_repository.dart';
import 'package:studyshare/features/home/presentation/home_page.dart';
import 'package:studyshare/features/home/providers/home_providers.dart';
import 'package:studyshare/features/listings/data/listing_preview_repository.dart';
import 'package:studyshare/features/listings/providers/listing_providers.dart';
import 'package:studyshare/l10n/app_localizations.dart';

class _Preferences extends AppPreferencesController {
  @override
  AppPreferences build() =>
      const AppPreferences(showGrid: false, showLeaves: false);
}

class _Overview implements HomeRepository {
  int calls = 0;
  bool fail = false;
  @override
  Future<HomeOverview> getOverview() async {
    calls++;
    if (fail) throw const AppError(DomainErrorCode.networkUnavailable, '');
    return HomeOverview(
      materialCount: 57,
      publishedCount: 31,
      draftCount: 8,
      hiddenCount: 2,
      activeTransactionCount: 4,
      serverAt: DateTime.utc(2026, 11, 27),
    );
  }
}

class _Listings extends ListingPreviewRepository {
  int? recentLimit, draftLimit;
  String? draftStatus;
  @override
  Future<ListingPage<ListingCardModel>> searchPage({
    String keyword = '',
    int offset = 0,
    int limit = 20,
  }) async {
    recentLimit = limit;
    return const ListingPage([
      ListingCardModel(
        listingId: 'listing-public',
        materialId: 'material',
        title: 'Sách công khai',
        subject: 'Tin học',
        offerType: OfferType.borrow,
        isRequestable: false,
        isReserved: true,
      ),
    ], hasMore: false);
  }

  @override
  Future<ListingPage<ManagedListing>> searchMine({
    String status = 'all',
    String query = '',
    int offset = 0,
    int limit = 20,
  }) async {
    draftStatus = status;
    draftLimit = limit;
    return const ListingPage([
      ManagedListing(
        listing: Listing(
          id: 'draft-1',
          materialId: 'material',
          offerType: OfferType.donate,
          status: ListingStatus.draft,
        ),
        materialRevision: 1,
        title: 'Nháp đang viết',
      ),
    ], hasMore: false);
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Overview overview,
  _Listings listings,
) async {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: HomePage()),
      ),
      GoRoute(
        path: '/listings/:id',
        builder: (_, _) =>
            Scaffold(appBar: AppBar(title: const Text('Chi tiết công khai'))),
      ),
      GoRoute(
        path: AppRoutes.materialForm,
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.pop(
              const model.Material(
                id: 'new-material',
                ownerId: 'A',
                holderId: 'A',
                title: 'Sách mới',
                subject: 'Tin học',
                condition: 'Tốt',
              ),
            ),
            child: const Text('Lưu ACK từ form'),
          ),
        ),
      ),
      GoRoute(
        path: '/materials/:id',
        builder: (_, _) =>
            Scaffold(appBar: AppBar(title: const Text('Tài liệu đã lưu'))),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeRepositoryProvider.overrideWithValue(overview),
        listingWorkspaceProvider.overrideWithValue(listings),
        currentProfileProvider.overrideWith((ref) async => null),
        appPreferencesProvider.overrideWith(_Preferences.new),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Home đếm tổng server độc lập trang 6 tin và 3 nháp; RESERVED vẫn hiện',
    (tester) async {
      final listings = _Listings();
      await _mount(tester, _Overview(), listings);
      expect(find.text('57'), findsOneWidget);
      expect(listings.recentLimit, 6);
      expect(listings.draftLimit, 3);
      expect(listings.draftStatus, 'DRAFT');
      await tester.scrollUntilVisible(find.text('Sách công khai'), 200);
      final t = AppLocalizations.of(tester.element(find.byType(HomePage)))!;
      expect(find.text(t.listingReserved), findsOneWidget);
      await tester.tap(find.text('Sách công khai'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết công khai'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    },
  );

  testWidgets(
    'Một khối lỗi vẫn đọc được nháp/tin; retry chỉ gọi lại khối lỗi',
    (tester) async {
      final overview = _Overview()..fail = true;
      final listings = _Listings();
      await _mount(tester, overview, listings);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Nháp đang viết'), findsOneWidget);
      overview.fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('57'), findsOneWidget);
      expect(overview.calls, 2);
      expect(find.text('Thử lại'), findsNothing);
    },
  );

  testWidgets(
    'Thêm từ Home: ACK mở detail, Back về Home và không trở lại form đã lưu',
    (tester) async {
      await _mount(tester, _Overview(), _Listings());
      await tester.tap(find.text('Thêm tài liệu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu ACK từ form'));
      await tester.pumpAndSettle();
      expect(find.text('Tài liệu đã lưu'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Lưu ACK từ form'), findsNothing);
    },
  );

  testWidgets('Home mobile 360px và chữ lớn không tràn bố cục', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _mount(tester, _Overview(), _Listings());
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Sách công khai'), 250);
    expect(tester.takeException(), isNull);
  });
}
