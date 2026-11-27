import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../core/auth/auth_session_providers.dart';
import '../../core/auth/profile_repository.dart';
import '../../design_system/widgets/study_error.dart';
import '../../design_system/widgets/study_loading.dart';
import '../../l10n/app_localizations.dart';
import '../auth/presentation/logout_button.dart';
import 'profile_edit_dialog.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Widget _link(
    BuildContext context,
    IconData icon,
    String title,
    String route, {
    String? subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: scheme.primary),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => context.push(route),
    );
  }

  Widget _activity(
    BuildContext context,
    AppLocalizations text,
    bool demo,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(text.profileActivity, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Card(
        child: Column(
          children: [
            _link(
              context,
              Icons.menu_book_outlined,
              text.profileMyMaterials,
              AppRoutes.myMaterials,
              subtitle: text.profileMaterialsHint,
            ),
            const Divider(height: 1, indent: 80, endIndent: 20),
            _link(
              context,
              Icons.swap_horiz,
              text.profileMyTransactions,
              AppRoutes.transactions,
              subtitle: text.profileTransactionsHint,
            ),
            const Divider(height: 1, indent: 80, endIndent: 20),
            _link(
              context,
              Icons.local_shipping_outlined,
              text.profileMyDeliveries,
              AppRoutes.deliveries,
              subtitle: text.profileDeliveriesHint,
            ),
            const Divider(height: 1, indent: 80, endIndent: 20),
            _link(
              context,
              Icons.report_outlined,
              text.profileMyIssues,
              AppRoutes.issues,
              subtitle: text.profileIssuesHint,
            ),
            const Divider(height: 1, indent: 80, endIndent: 20),
            _link(
              context,
              Icons.notifications_outlined,
              text.profileNotifications,
              AppRoutes.notifications,
              subtitle: text.profileNotificationsHint,
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text(text.profileAccount, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _link(
              context,
              Icons.settings_outlined,
              text.settingsTitle,
              AppRoutes.settings,
            ),
            if (demo) ...[
              _link(
                context,
                Icons.route_outlined,
                'Danh mục 26 màn hình (demo)',
                AppRoutes.screenCatalog,
              ),
              _link(
                context,
                Icons.storage_outlined,
                'Xem dữ liệu mô phỏng (demo)',
                AppRoutes.mockPreview,
              ),
            ],
            const Divider(height: 1, indent: 20, endIndent: 20),
            const Padding(padding: EdgeInsets.all(20), child: LogoutButton()),
          ],
        ),
      ),
    ],
  );

  Widget _identity(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
    AppLocalizations text,
  ) {
    final identity = ref.watch(authSnapshotProvider).asData?.value.identity;
    if (identity?.id != profile.userId) return const StudyLoading();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.person_outline,
                  size: 40,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              profile.displayName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (identity?.email != null) ...[
              const SizedBox(height: 6),
              Text(
                identity!.email!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const ValueKey('profile-edit'),
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => ProfileEditDialog(profile: profile),
              ),
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: Text(text.profileEdit),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context)!;
    final demo = ref.watch(demoModeProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  text.profileTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  text.profileSubtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (demo)
                  _activity(context, text, true)
                else
                  ref
                      .watch(currentProfileProvider)
                      .when(
                        loading: () => const StudyLoading(),
                        error: (_, _) => StudyError(
                          message: text.profileLoadError,
                          onRetry: () => ref.invalidate(currentProfileProvider),
                        ),
                        data: (profile) => profile == null
                            ? Text(text.authLoginNeeded)
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final identity = _identity(
                                    context,
                                    ref,
                                    profile,
                                    text,
                                  );
                                  final activity = _activity(
                                    context,
                                    text,
                                    false,
                                  );
                                  return constraints.maxWidth >= 720
                                      ? Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: 320,
                                              child: identity,
                                            ),
                                            const SizedBox(width: 24),
                                            Expanded(child: activity),
                                          ],
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            identity,
                                            const SizedBox(height: 24),
                                            activity,
                                          ],
                                        );
                                },
                              ),
                      ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
