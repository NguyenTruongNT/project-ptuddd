import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/widgets/study_feedback.dart';
import '../../l10n/app_localizations.dart';
import 'app_preferences.dart';

/// Feedback belongs to the app, so leaving Settings never interrupts a save.
class PreferencesFeedback extends ConsumerStatefulWidget {
  const PreferencesFeedback({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<PreferencesFeedback> createState() =>
      _PreferencesFeedbackState();
}

class _PreferencesFeedbackState extends ConsumerState<PreferencesFeedback> {
  Timer? _quietPeriod;
  @override
  void dispose() {
    _quietPeriod?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(preferencesSaveStateProvider, (_, next) {
      _quietPeriod?.cancel();
      if (next.phase == PreferencesSavePhase.saved) {
        _quietPeriod = Timer(const Duration(milliseconds: 650), () {
          if (mounted) {
            StudyFeedbackHost.of(context)
                ?.show(AppLocalizations.of(context)!.preferencesSaved);
          }
        });
      } else if (next.phase == PreferencesSavePhase.failed) {
        // Let the restored locale/theme rebuild before resolving the error text.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              ref.read(preferencesSaveStateProvider).revision ==
                  next.revision) {
            StudyFeedbackHost.of(context)?.show(
              AppLocalizations.of(context)!.preferencesSaveRestored,
              error: true,
            );
          }
        });
      }
    });
    return widget.child;
  }
}
