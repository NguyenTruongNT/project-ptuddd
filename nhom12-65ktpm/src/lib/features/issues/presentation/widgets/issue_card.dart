import 'package:flutter/material.dart';

import '../../../../core/contracts/models/issue.dart';
import '../../../transactions/domain/transaction_labels.dart' show formatServerTimeVn;
import '../../domain/issue_labels.dart';
import 'issue_chips.dart';

// Card cho SCR-21: tài liệu, người báo, trạng thái xử lý và dấu "Cần phản hồi".
class IssueCard extends StatelessWidget {
  const IssueCard({super.key, required this.details, required this.onTap});

  final IssueDetails details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
                '${issueRelationLabelVi(details)} · '
                '${formatServerTimeVn(details.issue.openedAt)}',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              IssueChips(details: details),
              const SizedBox(height: 8),
              Text(
                details.issue.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(issueProgressVi(details), style: textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
