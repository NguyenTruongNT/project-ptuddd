import 'package:flutter/material.dart';

import '../../../../core/contracts/domain_enums.dart';
import '../../domain/transaction_labels.dart';

// Chip trạng thái Transaction; không trộn với Listing/Material status.
class TransactionStatusChip extends StatelessWidget {
  const TransactionStatusChip({super.key, required this.status});
  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      TransactionStatus.completed => (scheme.primaryContainer, scheme.onPrimaryContainer),
      TransactionStatus.cancelled => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      _ => (scheme.secondaryContainer, scheme.onSecondaryContainer),
    };
    return _LabelChip(
      label: statusLabelVi(status),
      background: background,
      foreground: foreground,
    );
  }
}

class OfferTypeChip extends StatelessWidget {
  const OfferTypeChip({super.key, required this.type});
  final OfferType type;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _LabelChip(
      label: offerTypeLabelVi(type),
      background: scheme.tertiaryContainer,
      foreground: scheme.onTertiaryContainer,
    );
  }
}

// Nhãn cảnh báo dẫn xuất: Quá hạn, Có sự cố...
class WarningChip extends StatelessWidget {
  const WarningChip({super.key, required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _LabelChip(
      label: label,
      icon: icon,
      background: scheme.errorContainer,
      foreground: scheme.onErrorContainer,
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({
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
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

// Nhóm chip trạng thái + nhãn dẫn xuất, dùng chung cho card và trang chi tiết.
class TransactionChips extends StatelessWidget {
  const TransactionChips({
    super.key,
    required this.type,
    required this.status,
    required this.overdue,
    required this.hasOpenIssue,
    this.reHandoverOverdue = false,
  });

  final OfferType type;
  final TransactionStatus status;
  final bool overdue;
  final bool hasOpenIssue;
  final bool reHandoverOverdue;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        OfferTypeChip(type: type),
        TransactionStatusChip(status: status),
        if (overdue) const WarningChip(label: 'Quá hạn', icon: Icons.schedule),
        if (reHandoverOverdue)
          const WarningChip(label: 'Quá hạn tái bàn giao', icon: Icons.schedule),
        if (hasOpenIssue)
          const WarningChip(label: 'Có sự cố', icon: Icons.report_outlined),
      ],
    );
  }
}
