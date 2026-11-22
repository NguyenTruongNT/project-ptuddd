import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/mock_data_preview_page.dart';
import '../features/home/tab_content.dart';
import '../features/profile_settings/settings_page.dart';
import 'app_routes.dart';
import 'route_catalog_page.dart';
import 'shared_screen_placeholder.dart';
import 'studyshare_shell.dart';

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
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      // Giữ nguyên shell 5 tab, không phá thiết kế đã duyệt.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            StudyShareShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.home,
                builder: (context, state) =>
                    const TabContent(section: TabSection.home)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.explore,
                builder: (context, state) =>
                    const TabContent(section: TabSection.explore)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.publishTab,
                builder: (context, state) =>
                    const TabContent(section: TabSection.publish)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.transactions,
                builder: (context, state) =>
                    const TabContent(section: TabSection.transactions)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.profile,
                builder: (context, state) =>
                    const TabContent(section: TabSection.profile)),
          ]),
        ],
      ),
      // Các màn hình con nằm NGOÀI shell -> không có bottom navigation.
      _placeholder(AppRoutes.splash, 'SCR-01', 'Splash'),
      _placeholder(AppRoutes.signIn, 'SCR-02', 'Đăng nhập'),
      _placeholder(AppRoutes.signUp, 'SCR-03', 'Đăng ký'),
      _placeholder(AppRoutes.listingForm, 'SCR-10', 'Tạo/sửa tin đăng'),
      _placeholder(AppRoutes.listingDetailsPattern, 'SCR-06', 'Chi tiết tin đăng'),
      _placeholder(AppRoutes.myMaterials, 'SCR-07', 'Tài liệu của tôi'),
      _placeholder(AppRoutes.materialForm, 'SCR-08', 'Tạo/sửa tài liệu'),
      _placeholder(AppRoutes.materialDetailsPattern, 'SCR-09', 'Chi tiết tài liệu/QR'),
      _placeholder(AppRoutes.createRequestPattern, 'SCR-11', 'Gửi yêu cầu'),
      _placeholder(AppRoutes.requestCenter, 'SCR-12', 'Trung tâm yêu cầu'),
      _placeholder(AppRoutes.transactionDetailsPattern, 'SCR-14', 'Chi tiết giao dịch'),
      _placeholder(AppRoutes.deliveries, 'SCR-15', 'Danh sách giao hộ'),
      _placeholder(AppRoutes.createDelivery, 'SCR-16', 'Tạo nhiệm vụ giao hộ'),
      _placeholder(AppRoutes.deliveryDetailsPattern, 'SCR-17', 'Chi tiết giao hộ'),
      _placeholder(AppRoutes.prepareHandoverPattern, 'SCR-18', 'Chuẩn bị bàn giao'),
      _placeholder(AppRoutes.scanQrPattern, 'SCR-19', 'Quét QR'),
      _placeholder(AppRoutes.receiverAckPattern, 'SCR-20', 'Xác nhận nhận / từ chối'),
      _placeholder(AppRoutes.createIssue, 'SCR-22', 'Báo cáo sự cố'),
      _placeholder(AppRoutes.issues, 'SCR-21', 'Danh sách sự cố'),
      _placeholder(AppRoutes.issueDetailsPattern, 'SCR-23', 'Chi tiết sự cố'),
      _placeholder(AppRoutes.notifications, 'SCR-24', 'Thông báo'),
      GoRoute(path: AppRoutes.settings,
          builder: (context, state) => const SettingsPage()),
      GoRoute(path: AppRoutes.screenCatalog,
          builder: (context, state) => const RouteCatalogPage()),
      GoRoute(path: AppRoutes.mockPreview,
          builder: (context, state) => const MockDataPreviewPage()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
