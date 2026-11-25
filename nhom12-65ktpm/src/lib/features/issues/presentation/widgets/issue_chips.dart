import 'package:flutter/material.dart';

import '../../../../core/contracts/domain_enums.dart';
import '../../../../core/contracts/models/issue.dart';
import '../../domain/issue_labels.dart';

// Chip trạng thái và loại Issue; màu theo semantic, không phụ thuộc palette.
class IssueChips extends StatelessWidget {
  const IssueChips({super.key, required this.details});
  final IssueDetails details;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final issue = details.issue;
    final open = issue.status == IssueStatus.open;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _IssueChip(
          label: issueStatusLabelVi(issue.status),
          icon: open ? Icons.report_outlined : Icons.check_circle_outline,
          background: open ? scheme.errorContainer : scheme.primaryContainer,
          foreground: open ? scheme.onErrorContainer : scheme.onPrimaryContainer,
        ),
        _IssueChip(
          label: issueTypeLabelVi(issue.type),
          background: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
        ),
        if (needsMyResponse(details))
          _IssueChip(
            label: 'Cần phản hồi',
            icon: Icons.notifications_active_outlined,
            background: scheme.tertiaryContainer,
            foreground: scheme.onTertiaryContainer,
          ),
      ],
    );
  }
}

class _IssueChip extends StatelessWidget {
  const _IssueChip({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          // Flexible: nhãn dài co lại thay vì tràn ngang trên màn 360px.
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
