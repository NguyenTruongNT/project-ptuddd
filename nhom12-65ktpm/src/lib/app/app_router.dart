import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/tab_content.dart';
import 'studyshare_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            StudyShareShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (context, state) =>
                const TabContent(title: 'Trang chủ', icon: 'home')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/explore', builder: (context, state) =>
                const TabContent(title: 'Khám phá', icon: 'search')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/publish', builder: (context, state) =>
                const TabContent(title: 'Đăng tin', icon: 'publish')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/transactions', builder: (context, state) =>
                const TabContent(title: 'Giao dịch', icon: 'swap')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (context, state) =>
                const TabContent(title: 'Cá nhân', icon: 'person')),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
