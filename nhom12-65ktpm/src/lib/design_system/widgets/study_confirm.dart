import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

Future<bool> showStudyConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  IconData icon = Icons.task_alt_outlined,
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('study-confirm'),
        scrollable: true,
        icon: Icon(
          icon,
          color: destructive
              ? Theme.of(dialogContext).colorScheme.error
              : Theme.of(dialogContext).colorScheme.primary,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(dialogContext)!.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-action'),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor: Theme.of(dialogContext)
                        .colorScheme
                        .onError,
                  )
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;
