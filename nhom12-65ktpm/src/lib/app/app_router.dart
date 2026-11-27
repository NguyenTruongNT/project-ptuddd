import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_session_providers.dart';
import '../features/auth/presentation/auth_form_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/deliveries/presentation/create_delivery_page.dart';
import '../features/deliveries/presentation/delivery_details_page.dart';
import '../features/deliveries/presentation/delivery_list_page.dart';
import '../features/explore/presentation/explore_page.dart';
import '../features/handovers/presentation/prepare_handover_page.dart';
import '../features/handovers/presentation/qr_scanner_page.dart';
import '../features/handovers/presentation/receiver_ack_page.dart';
import '../features/home/mock_data_preview_page.dart';
import '../features/home/tab_content.dart';
import '../features/issues/presentation/create_issue_page.dart';
import '../features/issues/presentation/issue_details_page.dart';
import '../features/issues/presentation/issues_list_page.dart';
import '../features/listings/presentation/listing_details_page.dart';
import '../features/listings/presentation/listing_form_page.dart';
import '../features/listings/presentation/listing_material_picker_page.dart';
import '../features/listings/presentation/publish_page.dart';
import '../features/materials/presentation/material_details_page.dart';
import '../features/materials/presentation/material_form_page.dart';
import '../features/materials/presentation/my_materials_page.dart';
import '../features/profile_settings/profile_page.dart';
import '../features/profile_settings/settings_page.dart';
import '../features/transactions/presentation/my_transactions_page.dart';
import '../features/transactions/presentation/transaction_details_page.dart';
import 'app_routes.dart';
import 'auth_redirect.dart';
import 'route_catalog_page.dart';
import 'shared_screen_placeholder.dart';
import 'studyshare_shell.dart';

class _AuthRouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

// Mọi màn hình chưa có module riêng sẽ sử dụng placeholder.
GoRoute _placeholder(String path, String code, String title) {
  return GoRoute(
    path: path,
    builder: (context, state) {
      return SharedScreenPlaceholder(
        code: code,
        title: title,
        recordId: state.pathParameters.isEmpty
            ? null
            : state.pathParameters.values.first,
      );
    },
  );
}

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
        builder: (context, state, navigationShell) {
          return StudyShareShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) {
                  return const TabContent(section: TabSection.home);
                },
              ),
            ],
          ),

          // SCR-05: Khám phá tài liệu.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.explore,
                builder: (context, state) {
                  return const ExplorePage();
                },
              ),
            ],
          ),

          // Tab đăng tin và tài liệu của tôi.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.publishTab,
                builder: (context, state) {
                  return const PublishPage();
                },
              ),
              GoRoute(
                path: AppRoutes.myMaterials,
                builder: (_, _) {
                  return const MyMaterialsPage();
                },
              ),
            ],
          ),

          // SCR-13: module Transaction của Sơn.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.transactions,
                builder: (context, state) {
                  return const MyTransactionsPage();
                },
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) {
                  return const ProfilePage();
                },
              ),
            ],
          ),
        ],
      ),

      // Các màn hình con nằm ngoài shell, không có bottom navigation.
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (_, state) {
          return AuthFormPage(
            flow: AuthFlow.signIn,
            returnTo: state.uri.queryParameters['from'],
            notice: state.extra is String ? state.extra as String : null,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (_, state) {
          return AuthFormPage(
            flow: AuthFlow.signUp,
            returnTo: state.uri.queryParameters['from'],
          );
        },
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, state) {
          return AuthFormPage(
            flow: AuthFlow.forgotPassword,
            returnTo: state.uri.queryParameters['from'],
          );
        },
      ),
      GoRoute(
        path: AppRoutes.checkEmail,
        builder: (_, state) {
          return AuthFormPage(
            flow: AuthFlow.checkEmail,
            returnTo: state.uri.queryParameters['from'],
            email: state.extra is String ? state.extra as String : null,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, _) {
          return const AuthFormPage(flow: AuthFlow.resetPassword);
        },
      ),

      // SDK nhận deep link từ app_links.
      // Route không tự đọc token hoặc đổi session.
      GoRoute(
        path: AppRoutes.authCallback,
        builder: (_, _) => const SplashPage(),
      ),

      // SCR-10: Tạo hoặc sửa Listing.
      GoRoute(
        path: AppRoutes.listingForm,
        builder: (_, state) {
          return ListingFormPage(
            materialId: state.uri.queryParameters['materialId'],
            listingId: state.uri.queryParameters['listingId'],
            returnPublishedResult:
                state.uri.queryParameters['completion'] == 'return',
          );
        },
      ),

      // Đặt route tĩnh trước /listings/:listingId
      // để không nhầm tên bước thành ID.
      GoRoute(
        path: AppRoutes.listingMaterialPicker,
        builder: (_, _) {
          return const ListingMaterialPickerPage();
        },
      ),

      // SCR-06: Chi tiết Listing công khai.
      GoRoute(
        path: AppRoutes.listingDetailsPattern,
        builder: (_, state) {
          return ListingDetailsPage(
            listingId: state.pathParameters['listingId']!,
          );
        },
      ),

      GoRoute(
        path: AppRoutes.materialForm,
        builder: (_, state) {
          return MaterialFormPage(
            returnSavedResult:
                state.uri.queryParameters['completion'] == 'return',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.materialEditPattern,
        builder: (_, state) {
          return MaterialFormPage(
            materialId: state.pathParameters['materialId']!,
            returnSavedResult:
                state.uri.queryParameters['completion'] == 'return',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.materialDetailsPattern,
        builder: (_, state) {
          return MaterialDetailsPage(
            materialId: state.pathParameters['materialId']!,
          );
        },
      ),

      // SCR-11 và SCR-12 chưa triển khai.
      _placeholder(AppRoutes.createRequestPattern, 'SCR-11', 'Gửi yêu cầu'),
      _placeholder(AppRoutes.requestCenter, 'SCR-12', 'Trung tâm yêu cầu'),

      // SCR-14: module Transaction của Sơn.
      GoRoute(
        path: AppRoutes.transactionDetailsPattern,
        builder: (context, state) {
          return TransactionDetailsPage(
            transactionId: state.pathParameters['transactionId']!,
          );
        },
      ),

      // SCR-15: Danh sách giao hộ.
      GoRoute(
        path: AppRoutes.deliveries,
        builder: (context, state) {
          return const DeliveryListPage();
        },
      ),

      // SCR-16: Tạo nhiệm vụ giao hộ.
      GoRoute(
        path: AppRoutes.createDelivery,
        builder: (context, state) {
          return CreateDeliveryPage(
            transactionId:
                state.uri.queryParameters['transactionId'] ?? 'txn-delivery-01',
          );
        },
      ),

      // SCR-17: Chi tiết giao hộ.
      GoRoute(
        path: AppRoutes.deliveryDetailsPattern,
        builder: (context, state) {
          return DeliveryDetailsPage(taskId: state.pathParameters['taskId']!);
        },
      ),

      // SCR-18: Chuẩn bị bàn giao.
      GoRoute(
        path: AppRoutes.prepareHandoverPattern,
        builder: (context, state) {
          return PrepareHandoverPage(
            handoverId: state.pathParameters['handoverId']!,
          );
        },
      ),

      // SCR-19: Quét QR.
      GoRoute(
        path: AppRoutes.scanQrPattern,
        builder: (context, state) {
          return QrScannerPage(handoverId: state.pathParameters['handoverId']!);
        },
      ),

      // SCR-20: Xác nhận nhận hoặc từ chối.
      GoRoute(
        path: AppRoutes.receiverAckPattern,
        builder: (context, state) {
          return ReceiverAckPage(
            handoverId: state.pathParameters['handoverId']!,
          );
        },
      ),

      // SCR-21/22/23: module Issue của Sơn.
      // Giữ createIssue trước issueDetailsPattern.
      GoRoute(
        path: AppRoutes.createIssue,
        builder: (context, state) {
          return CreateIssuePage(
            transactionId: state.uri.queryParameters['transactionId'],
            handoverId: state.uri.queryParameters['handoverId'],
          );
        },
      ),
      GoRoute(
        path: AppRoutes.issues,
        builder: (context, state) {
          return const IssuesListPage();
        },
      ),
      GoRoute(
        path: AppRoutes.issueDetailsPattern,
        builder: (context, state) {
          return IssueDetailsPage(issueId: state.pathParameters['issueId']!);
        },
      ),

      // SCR-24 chưa được tích hợp.
      _placeholder(AppRoutes.notifications, 'SCR-24', 'Thông báo'),

      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) {
          return const SettingsPage();
        },
      ),
      GoRoute(
        path: AppRoutes.screenCatalog,
        builder: (context, state) {
          return const RouteCatalogPage();
        },
      ),
      GoRoute(
        path: AppRoutes.mockPreview,
        builder: (context, state) {
          return const MockDataPreviewPage();
        },
      ),
    ],
  );

  ref.onDispose(router.dispose);
  ref.onDispose(refresh.dispose);

  return router;
});
