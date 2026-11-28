import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:studyshare/core/auth/auth_session_providers.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/features/requests/presentation/request_center_page.dart';
import 'package:studyshare/l10n/app_localizations.dart';

// Demo mode (SUPABASE_ENABLED=false): workflowRpcProvider trả null, Request
// không có mock nên SCR-12 phải báo an toàn, không ra màn hình lỗi đỏ.
Widget _demoApp() {
  final router = GoRouter(
    initialLocation: '/requests',
    routes: [
      GoRoute(path: '/requests', builder: (_, _) => const RequestCenterPage()),
      GoRoute(
        path: '/explore',
        builder: (_, _) => const Scaffold(body: Text('SCR-05')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      workflowRpcProvider.overrideWithValue(null),
      sessionBoundaryProvider.overrideWithValue('demo'),
      // Cố ý KHÔNG override requestRepositoryProvider: dùng provider thật.
    ],
    child: MaterialApp.router(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('SCR-12 ở demo mode báo cần đăng nhập/kết nối, không crash', (
    tester,
  ) async {
    await tester.pumpWidget(_demoApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
