import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/tab_content.dart';
import '../features/profile_settings/settings_page.dart';
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
                const TabContent(section: TabSection.home)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/explore', builder: (context, state) =>
                const TabContent(section: TabSection.explore)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/publish', builder: (context, state) =>
                const TabContent(section: TabSection.publish)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/transactions', builder: (context, state) =>
                const TabContent(section: TabSection.transactions)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (context, state) =>
                const TabContent(section: TabSection.profile)),
          ]),
        ],
      ),
      // Nằm ngoài shell: trang chi tiết không có bottom navigation.
      GoRoute(path: '/settings', builder: (context, state) =>
          const SettingsPage()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
