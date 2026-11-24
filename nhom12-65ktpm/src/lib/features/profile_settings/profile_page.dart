import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../core/auth/auth_session_providers.dart';
import '../../core/auth/profile_repository.dart';
import '../../design_system/widgets/study_error.dart';
import '../../design_system/widgets/study_loading.dart';
import '../../l10n/app_localizations.dart';
import '../auth/domain/auth_validation.dart';
import '../auth/presentation/auth_error_message.dart';
import '../auth/presentation/logout_button.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _loadedUser;
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    final repository = ref.read(profileRepositoryProvider);
    if (repository == null) return;
    final text = AppLocalizations.of(context)!;
    final userId = ref.read(authSnapshotProvider).asData?.value.identity?.id;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await repository.updateMyDisplayName(_name.text.trim());
      if (!mounted ||
          ref.read(authSnapshotProvider).asData?.value.identity?.id != userId) {
        return;
      }
      ref.invalidate(currentProfileProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(text.profileSaved)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authErrorMessage(error, text))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _links(AppLocalizations text, bool demo) => Column(
    children: [
      _link(
        Icons.menu_book_outlined,
        text.profileMyMaterials,
        AppRoutes.myMaterials,
      ),
      _link(
        Icons.swap_horiz,
        text.profileMyTransactions,
        AppRoutes.transactions,
      ),
      _link(
        Icons.local_shipping_outlined,
        text.profileMyDeliveries,
        AppRoutes.deliveries,
      ),
      _link(Icons.report_outlined, text.profileMyIssues, AppRoutes.issues),
      _link(Icons.settings_outlined, text.settingsTitle, AppRoutes.settings),
      if (demo) ...[
        _link(
          Icons.route_outlined,
          'Danh mục 26 màn hình (demo)',
          AppRoutes.screenCatalog,
        ),
        _link(
          Icons.storage_outlined,
          'Xem dữ liệu mô phỏng (demo)',
          AppRoutes.mockPreview,
        ),
      ],
      const SizedBox(height: 16),
      const LogoutButton(),
    ],
  );
  Widget _link(IconData icon, String title, String route) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push(route),
  );

  Widget _profile(UserProfile profile, AppLocalizations text) {
    final identity = ref.watch(authSnapshotProvider).asData?.value.identity;
    if (identity?.id != profile.userId) return const StudyLoading();
    if (_loadedUser != profile.userId) {
      _loadedUser = profile.userId;
      _name.text = profile.displayName;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: CircleAvatar(radius: 32, child: Icon(Icons.person, size: 36)),
        ),
        const SizedBox(height: 12),
        Text(
          profile.displayName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (identity?.email != null)
          Text(identity!.email!, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Form(
          key: _form,
          child: TextFormField(
            key: const ValueKey('profile-name'),
            controller: _name,
            enabled: !_saving,
            maxLength: 100,
            decoration: InputDecoration(labelText: text.authDisplayName),
            validator: (v) =>
                AuthValidation.validName(v ?? '') ? null : text.authInvalidName,
          ),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(text.profileSave),
        ),
        const Divider(height: 32),
        _links(text, false),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final demo = ref.watch(demoModeProvider);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            text.profileTitle,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          if (demo) ...[
            Text(text.authDemoNotice),
            const SizedBox(height: 16),
            _links(text, true),
          ] else
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
                      : _profile(profile, text),
                ),
        ],
      ),
    );
  }
}
