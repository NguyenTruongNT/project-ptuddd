import 'package:flutter/material.dart';

import '../../../../core/contracts/models/transaction.dart';
import '../../domain/transaction_labels.dart';

// Timeline đọc từ TransactionEvent do server ghi; không dùng giờ điện thoại.
class TransactionTimeline extends StatelessWidget {
  const TransactionTimeline({super.key, required this.events});
  final List<TransactionEventItem> events;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      Icon(Icons.circle, size: 12, color: scheme.primary),
                      if (i < events.length - 1)
                        Expanded(
                          child: Container(width: 2, color: scheme.outlineVariant),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(events[i].safeDescription, style: textTheme.bodyMedium),
                        const SizedBox(height: 2),
                        Text(
                          [
                            formatServerTimeVn(events[i].serverAt),
                            if (events[i].actorDisplay != null)
                              events[i].actorDisplay!,
                          ].join(' · '),
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
