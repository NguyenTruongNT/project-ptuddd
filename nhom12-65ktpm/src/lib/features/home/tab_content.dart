import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../core/preferences/app_preferences.dart';
import '../../design_system/decorations/grid_paper.dart';
import '../../design_system/decorations/leaf_fall_overlay.dart';
import '../../l10n/app_localizations.dart';

enum TabSection { home, explore, publish, transactions, profile }

class TabContent extends ConsumerWidget {
  const TabContent({super.key, required this.section});
  final TabSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final preferences = ref.watch(appPreferencesProvider);
    final heading = switch (section) {
      TabSection.home => l10n.navHome,
      TabSection.explore => l10n.navExplore,
      TabSection.publish => l10n.navPublish,
      TabSection.transactions => l10n.navTransactions,
      TabSection.profile => l10n.navProfile,
    };
    final decorate = section == TabSection.home || section == TabSection.explore;

    return Stack(
      children: [
        if (decorate && preferences.showGrid)
          const Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: GridPaperPainter())),
          ),
        if (section == TabSection.home && preferences.showLeaves)
          const Positioned.fill(child: IgnorePointer(child: LeafFallOverlay())),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (section == TabSection.home)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/branding/logo_dark_original.png',
                    height: 180,
                    fit: BoxFit.contain,
                    semanticLabel: 'StudyShare',
                  ),
                ),
              const SizedBox(height: 16),
              Text(heading, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    section == TabSection.home
                        ? l10n.welcomeMessage
                        : l10n.placeholderMessage,
                  ),
                ),
              ),
              if (section == TabSection.profile) ...[
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(l10n.settingsTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.settings),
                ),
                // Lối vào kiểm thử, sẽ được ẩn/gỡ khi hoàn thiện release.
                ListTile(
                  leading: const Icon(Icons.route_outlined),
                  title: const Text('Danh mục 26 màn hình (demo)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.screenCatalog),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
