import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_session_providers.dart';
import '../../core/auth/profile_repository.dart';
import '../../design_system/widgets/study_confirm.dart';
import '../../design_system/widgets/study_feedback.dart';
import '../../l10n/app_localizations.dart';
import '../auth/domain/auth_validation.dart';
import '../auth/presentation/auth_error_message.dart';
import '../auth/presentation/auth_page_layout.dart';

class ProfileEditDialog extends ConsumerStatefulWidget {
  const ProfileEditDialog({super.key, required this.profile});
  final UserProfile profile;
  @override
  ConsumerState<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends ConsumerState<ProfileEditDialog> {
  late final _name = TextEditingController(text: widget.profile.displayName);
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  bool _closing = false;
  bool _allowPop = false;
  String? _error;
  bool get _changed => _name.text.trim() != widget.profile.displayName;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_busy || _closing) return;
    _closing = true;
    final text = AppLocalizations.of(context)!;
    final discard =
        !_changed ||
        await showStudyConfirm(
          context,
          title: text.commonDiscardTitle,
          message: text.commonDiscardBody,
          confirmLabel: text.commonDiscard,
          destructive: true,
        );
    if (mounted && discard) {
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
    _closing = false;
  }

  Future<void> _save() async {
    if (_busy || !_changed || !(_form.currentState?.validate() ?? false))
      return;
    final text = AppLocalizations.of(context)!;
    final feedback = StudyFeedbackHost.of(context);
    final value = _name.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    FocusScope.of(context).unfocus();
    try {
      final confirmed = await showStudyConfirm(
        context,
        title: text.profileSave,
        message: text.profileNameConfirm(value),
        confirmLabel: text.profileSave,
        icon: Icons.edit_outlined,
      );
      if (!confirmed || !mounted) return;
      if (ref.read(authSnapshotProvider).asData?.value.identity?.id !=
          widget.profile.userId)
        return;
      final repository = ref.read(profileRepositoryProvider);
      if (repository == null) return;
      await repository.updateMyDisplayName(value);
      if (!mounted ||
          ref.read(authSnapshotProvider).asData?.value.identity?.id !=
              widget.profile.userId)
        return;
      ref.invalidate(currentProfileProvider);
      feedback?.show(text.profileSaved);
      setState(() => _allowPop = true);
      Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error, text));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    ref.listen(authSnapshotProvider, (_, next) {
      if (next.asData?.value.identity?.id != widget.profile.userId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ModalRoute.of(context)?.isCurrent == true)
            Navigator.pop(context);
        });
      }
    });
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _close();
      },
      child: AlertDialog(
        key: const ValueKey('profile-edit-dialog'),
        scrollable: true,
        title: Text(text.profileEdit),
        content: SizedBox(
          width: 400,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(text.profileEditHint),
                const SizedBox(height: 24),
                TextFormField(
                  key: const ValueKey('profile-name'),
                  controller: _name,
                  autofocus: true,
                  enabled: !_busy,
                  maxLength: 100,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: text.authDisplayName,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _save(),
                  validator: (v) => AuthValidation.validName(v ?? '')
                      ? null
                      : text.authInvalidName,
                ),
                if (_error != null) AuthMessage(_error!, error: true),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _close,
            child: Text(text.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('profile-save'),
            onPressed:
                _busy || !_changed || !AuthValidation.validName(_name.text)
                ? null
                : _save,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(text.profileSave),
          ),
        ],
      ),
    );
  }
}
