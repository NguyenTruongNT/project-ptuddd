import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/deliveries/presentation/create_delivery_page.dart';
import '../features/deliveries/presentation/delivery_details_page.dart';
import '../features/deliveries/presentation/delivery_list_page.dart';
import '../features/handovers/presentation/prepare_handover_page.dart';
import '../features/handovers/presentation/qr_scanner_page.dart';
import '../features/handovers/presentation/receiver_ack_page.dart';
import '../features/home/mock_data_preview_page.dart';
import '../features/home/tab_content.dart';
import '../features/issues/presentation/create_issue_page.dart';
import '../features/issues/presentation/issue_details_page.dart';
import '../features/issues/presentation/issues_list_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/profile_settings/settings_page.dart';
import '../features/transactions/presentation/my_transactions_page.dart';
import '../features/transactions/presentation/transaction_details_page.dart';
import 'app_routes.dart';
import 'route_catalog_page.dart';
import 'shared_screen_placeholder.dart';
import 'studyshare_shell.dart';
import '../core/auth/auth_session_providers.dart';
import '../features/auth/presentation/auth_form_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/profile_settings/profile_page.dart';
import 'auth_redirect.dart';
import '../features/materials/presentation/my_materials_page.dart';
import '../features/materials/presentation/material_form_page.dart';
import '../features/materials/presentation/material_details_page.dart';
import '../features/listings/presentation/publish_page.dart';
import '../features/listings/presentation/listing_form_page.dart';
import '../features/listings/presentation/listing_details_page.dart';
import '../features/listings/presentation/listing_material_picker_page.dart';

class _AuthRouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

// Mọi màn hình chưa có module riêng sẽ sử dụng placeholder.
GoRoute _placeholder(String path, String code, String title) => GoRoute(
  path: path,
  builder: (context, state) => SharedScreenPlaceholder(
    code: code,
    title: title,
    recordId: state.pathParameters.isEmpty
        ? null
        : state.pathParameters.values.first,
  ),
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRouterRefresh();
  ref.listen(authSnapshotProvider, (_, _) => refresh.refresh());
  ref.listen(demoModeProvider, (_, _) => refresh.refresh());
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authSnapshotProvider);
      return authRedirect(
        location: state.uri,
        session: auth.asData?.value,
        loading: auth.isLoading,
        demo: ref.read(demoModeProvider),
      );
    },
    routes: [
      // Giữ nguyên shell 5 tab, không phá thiết kế đã duyệt.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            StudyShareShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) =>
                    const TabContent(section: TabSection.home),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.explore,
                builder: (context, state) =>
                    const TabContent(section: TabSection.explore),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.publishTab,
                builder: (context, state) => const PublishPage(),
              ),
              GoRoute(
                path: AppRoutes.myMaterials,
                builder: (_, _) => const MyMaterialsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              // SCR-13 – module Transaction (Sơn).
              GoRoute(
                path: AppRoutes.transactions,
                builder: (context, state) => const MyTransactionsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      // Các màn hình con nằm NGOÀI shell -> không có bottom navigation.
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (_, state) => AuthFormPage(
          flow: AuthFlow.signIn,
          returnTo: state.uri.queryParameters['from'],
          notice: state.extra is String ? state.extra as String : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (_, state) => AuthFormPage(
          flow: AuthFlow.signUp,
          returnTo: state.uri.queryParameters['from'],
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, state) => AuthFormPage(
          flow: AuthFlow.forgotPassword,
          returnTo: state.uri.queryParameters['from'],
        ),
      ),
      GoRoute(
        path: AppRoutes.checkEmail,
        builder: (_, state) => AuthFormPage(
          flow: AuthFlow.checkEmail,
          returnTo: state.uri.queryParameters['from'],
          email: state.extra is String ? state.extra as String : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, _) => const AuthFormPage(flow: AuthFlow.resetPassword),
      ),
      // SDK nhận deep link từ app_links, route không tự đọc token hay đổi session.
      GoRoute(
        path: AppRoutes.authCallback,
        builder: (_, _) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.listingForm,
        builder: (_, state) => ListingFormPage(
          materialId: state.uri.queryParameters['materialId'],
          listingId: state.uri.queryParameters['listingId'],
          returnPublishedResult:
              state.uri.queryParameters['completion'] == 'return',
        ),
      ),
      // Đặt route tĩnh trước /listings/:listingId để không nhầm tên bước thành ID.
      GoRoute(
        path: AppRoutes.listingMaterialPicker,
        builder: (_, _) => const ListingMaterialPickerPage(),
      ),
      GoRoute(
        path: AppRoutes.listingDetailsPattern,
        builder: (_, state) =>
            ListingDetailsPage(listingId: state.pathParameters['listingId']!),
      ),
      GoRoute(
        path: AppRoutes.materialForm,
        builder: (_, state) => MaterialFormPage(
          returnSavedResult:
              state.uri.queryParameters['completion'] == 'return',
        ),
      ),
      GoRoute(
        path: AppRoutes.materialEditPattern,
        builder: (_, state) => MaterialFormPage(
          materialId: state.pathParameters['materialId']!,
          returnSavedResult:
              state.uri.queryParameters['completion'] == 'return',
        ),
      ),
      GoRoute(
        path: AppRoutes.materialDetailsPattern,
        builder: (_, state) => MaterialDetailsPage(
          materialId: state.pathParameters['materialId']!,
        ),
      ),
      _placeholder(AppRoutes.createRequestPattern, 'SCR-11', 'Gửi yêu cầu'),
      _placeholder(AppRoutes.requestCenter, 'SCR-12', 'Trung tâm yêu cầu'),
      // SCR-14 – module Transaction (Sơn).
      GoRoute(
        path: AppRoutes.transactionDetailsPattern,
        builder: (context, state) => TransactionDetailsPage(
          transactionId: state.pathParameters['transactionId']!,
        ),
      ),
      // SCR-15/16/17/18/19/20 – module Giao hộ & Bàn giao (Vũ Hải Đăng).
      GoRoute(
        path: AppRoutes.deliveries,
        builder: (context, state) => const DeliveryListPage(),
      ),
      GoRoute(
        path: AppRoutes.createDelivery,
        builder: (context, state) => CreateDeliveryPage(
          transactionId: state.uri.queryParameters['transactionId'] ?? 'txn-delivery-01',
        ),
      ),
      GoRoute(
        path: AppRoutes.deliveryDetailsPattern,
        builder: (context, state) => DeliveryDetailsPage(
          taskId: state.pathParameters['taskId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.prepareHandoverPattern,
        builder: (context, state) => PrepareHandoverPage(
          handoverId: state.pathParameters['handoverId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.scanQrPattern,
        builder: (context, state) => QrScannerPage(
          handoverId: state.pathParameters['handoverId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.receiverAckPattern,
        builder: (context, state) => ReceiverAckPage(
          handoverId: state.pathParameters['handoverId']!,
        ),
      ),
      // SCR-21/22/23 – module Issue (Sơn). Giữ createIssue trước issueDetailsPattern.
      GoRoute(
        path: AppRoutes.createIssue,
        builder: (context, state) => CreateIssuePage(
          transactionId: state.uri.queryParameters['transactionId'],
          handoverId: state.uri.queryParameters['handoverId'],
        ),
      ),
      GoRoute(
        path: AppRoutes.issues,
        builder: (context, state) => const IssuesListPage(),
      ),
      GoRoute(
        path: AppRoutes.issueDetailsPattern,
        builder: (context, state) =>
            IssueDetailsPage(issueId: state.pathParameters['issueId']!),
      ),
      // SCR-24 – module Notification (Sơn).
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.screenCatalog,
        builder: (context, state) => const RouteCatalogPage(),
      ),
      GoRoute(
        path: AppRoutes.mockPreview,
        builder: (context, state) => const MockDataPreviewPage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  ref.onDispose(refresh.dispose);
  return router;
});
