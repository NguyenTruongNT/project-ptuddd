import 'package:flutter/material.dart';

import '../../../../core/contracts/models/notification_item.dart';
import '../../../transactions/domain/transaction_labels.dart';
import '../../domain/notification_labels.dart';

// Một dòng thông báo (NotificationCard, UI-17). Chỉ hiện preview an toàn do
// server soạn; chưa đọc thì đậm, có nền nhấn và chấm tròn.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notice,
    required this.onTap,
    this.busy = false,
  });

  final AppNotification notice;
  final VoidCallback? onTap;
  // Đang gửi lệnh đánh dấu đã đọc cho chính thông báo này.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unread = !notice.isRead;
    final title = notificationTitleVi(notice.type);

    return Card(
      margin: EdgeInsets.zero,
      color: unread ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: busy ? null : onTap,
        child: Semantics(
          label: unread ? 'Chưa đọc' : 'Đã đọc',
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: scheme.secondaryContainer,
                  child: Icon(notificationIcon(notice),
                      color: scheme.onSecondaryContainer, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notice.safePreview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatServerTimeVn(notice.createdAt),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (unread)
                  Container(
                    key: const ValueKey('notification-unread-dot'),
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
