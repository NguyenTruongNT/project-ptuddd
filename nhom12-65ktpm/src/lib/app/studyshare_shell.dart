import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_session_providers.dart';
import '../features/home/providers/home_providers.dart';
import '../features/notifications/presentation/widgets/notification_bell.dart';

import '../l10n/app_localizations.dart';
import 'app_routes.dart';

class StudyShareShell extends ConsumerWidget {
  const StudyShareShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // Tab Đăng tin có AppBar riêng, tránh lặp StudyShare + tiêu đề chức năng.
      appBar:
          navigationShell.currentIndex == 4 ||
              GoRouterState.of(context).uri.path == AppRoutes.publishTab
          ? null
          : AppBar(
              title: const Text('StudyShare'),
              // Chuông lấy tổng chưa đọc riêng, không phụ thuộc dữ liệu Home.
              actions: const [NotificationBell()],
            ),
      body: Column(
        children: [
          if (ref.watch(demoModeProvider))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Text(l10n.authDemoNotice),
            ),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          // Sau khi thao tác ở tab khác, Trang chủ phải đếm lại dữ liệu server.
          if (index == 0) refreshHome(ref);
          navigationShell.goBranch(index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search),
            label: l10n.navExplore,
          ),
          NavigationDestination(
            icon: const Icon(Icons.add_box_outlined),
            label: l10n.navPublish,
          ),
          NavigationDestination(
            icon: const Icon(Icons.swap_horiz),
            label: l10n.navTransactions,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
