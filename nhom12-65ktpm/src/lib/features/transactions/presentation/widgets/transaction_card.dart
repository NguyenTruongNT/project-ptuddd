import 'package:flutter/material.dart';

import '../../../../core/contracts/models/transaction.dart';
import '../../domain/transaction_labels.dart';
import 'transaction_status_chip.dart';

// Card cho SCR-13: tên tài liệu, vai trò, đối tác, trạng thái và việc đang chờ.
class TransactionCard extends StatelessWidget {
  const TransactionCard({
    super.key,
    required this.details,
    required this.nowUtc,
    required this.onTap,
  });

  final TransactionDetails details;
  final DateTime nowUtc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final txn = details.transaction;
    final isOwner = details.viewerRole == TransactionViewerRole.owner;
    final counterpart =
        isOwner ? details.receiverDisplayName : details.ownerDisplayName;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(details.materialTitle, style: textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                '${isOwner ? 'Bạn là người đăng' : 'Bạn là người nhận'}'
                ' · Với $counterpart',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TransactionChips(
                type: txn.type,
                status: txn.status,
                overdue: isOverdue(details, nowUtc),
                reHandoverOverdue: isReHandoverOverdue(details, nowUtc),
                hasOpenIssue: needsResolution(details),
              ),
              const SizedBox(height: 8),
              Text(waitingOnVi(details), style: textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
