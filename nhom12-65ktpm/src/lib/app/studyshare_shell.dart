import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';

class StudyShareShell extends StatelessWidget {
  const StudyShareShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: const Text('StudyShare')),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(index),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined),
              label: l10n.navHome),
          NavigationDestination(icon: const Icon(Icons.search),
              label: l10n.navExplore),
          NavigationDestination(icon: const Icon(Icons.add_box_outlined),
              label: l10n.navPublish),
          NavigationDestination(icon: const Icon(Icons.swap_horiz),
              label: l10n.navTransactions),
          NavigationDestination(icon: const Icon(Icons.person_outline),
              label: l10n.navProfile),
        ],
      ),
    );
  }
}
