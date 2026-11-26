import '../core/auth/auth_repository.dart';
import 'app_routes.dart';

/// Chỉ giữ đường dẫn nội bộ và ID được cho phép; bỏ token/fragment/query khác.
String safeAuthDestination(String? raw) {
  if (raw == null) return AppRoutes.home;
  if (raw.split('/').any((p) => p == '..' || p == '.')) return AppRoutes.home;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !raw.startsWith('/') ||
      raw.startsWith('//') ||
      raw.contains('\\') ||
      uri.pathSegments.any((p) => p == '..' || p == '.')) {
    return AppRoutes.home;
  }
  final path = uri.path;
  const roots = {
    '/home',
    '/explore',
    '/publish',
    '/transactions',
    '/profile',
    '/settings',
    '/materials',
    '/materials/new',
    '/listings/new',
    '/listings/select-material',
    '/requests',
    '/deliveries',
    '/deliveries/new',
    '/issues',
    '/issues/new',
    '/notifications',
  };
  final details = RegExp(
    r'^/(materials|listings|transactions|deliveries|issues)/[a-zA-Z0-9_-]+$',
  );
  final handover = RegExp(r'^/handovers/[a-zA-Z0-9_-]+/(prepare|scan|ack)$');
  final request = RegExp(r'^/requests/new/[a-zA-Z0-9_-]+$');
  final materialEdit = RegExp(r'^/materials/[a-zA-Z0-9_-]+/edit$');
  if (path == AppRoutes.listingForm) {
    // SCR-10 dùng query cho ID: bỏ toàn bộ sẽ mất tài liệu/tin khi đăng nhập lại.
    // Chỉ giữ UUID đơn của hai trường này; không mang token hay cờ điều hướng qua Auth.
    final ids = <String, String>{};
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    for (final name in ['materialId', 'listingId']) {
      final values = uri.queryParametersAll[name];
      if (values != null &&
          values.length == 1 &&
          uuid.hasMatch(values.single)) {
        ids[name] = values.single;
      }
    }
    return Uri(
      path: path,
      queryParameters: ids.isEmpty ? null : ids,
    ).toString();
  }
  return roots.contains(path) ||
          details.hasMatch(path) ||
          handover.hasMatch(path) ||
          request.hasMatch(path) ||
          materialEdit.hasMatch(path)
      ? path
      : AppRoutes.home;
}

String? authRedirect({
  required Uri location,
  required AuthSnapshot? session,
  required bool loading,
  required bool demo,
}) {
  final path = location.path;
  final isAuth = {
    AppRoutes.signIn,
    AppRoutes.signUp,
    AppRoutes.forgotPassword,
    AppRoutes.checkEmail,
    AppRoutes.resetPassword,
    AppRoutes.authCallback,
  }.contains(path);
  final from = location.queryParameters['from'];
  if (loading) {
    if (path == AppRoutes.splash) return null;
    return Uri(
      path: AppRoutes.splash,
      queryParameters: {
        'from': safeAuthDestination(isAuth ? from : location.toString()),
      },
    ).toString();
  }
  if (session?.recovering ?? false) {
    return path == AppRoutes.resetPassword ? null : AppRoutes.resetPassword;
  }
  if (demo && !(session?.configured ?? false)) {
    if (path == AppRoutes.splash) return safeAuthDestination(from);
    return null;
  }
  if (!(session?.isAuthenticated ?? false)) {
    if (isAuth &&
        path != AppRoutes.resetPassword &&
        path != AppRoutes.authCallback) {
      return null;
    }
    return Uri(
      path: AppRoutes.signIn,
      queryParameters: {
        'from': safeAuthDestination(
          path == AppRoutes.splash ? from : location.toString(),
        ),
      },
    ).toString();
  }
  if (isAuth || path == AppRoutes.splash) return safeAuthDestination(from);
  return null;
}
