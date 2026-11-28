import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../providers/notification_providers.dart';

// Chuông trên AppBar (Home → Bell → SCR-24) kèm badge số chưa đọc.
// MVP chỉ có thông báo trong ứng dụng (BR-48): tải lại khi app quay về
// foreground và khi rời hộp thư, không dùng push/realtime.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (mounted) refreshNotifications(ref);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadNotificationCountProvider) ?? 0;
    final label = unread > 99 ? '99+' : '$unread';
    return IconButton(
      tooltip: unread > 0 ? 'Thông báo ($unread chưa đọc)' : 'Thông báo',
      onPressed: () async {
        await context.push(AppRoutes.notifications);
        if (mounted) refreshNotifications(ref);
      },
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(label),
        child: Icon(
          unread > 0
              ? Icons.notifications_active_outlined
              : Icons.notifications_outlined,
        ),
      ),
    );
  }
}
