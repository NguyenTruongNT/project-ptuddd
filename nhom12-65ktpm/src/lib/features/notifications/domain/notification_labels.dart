import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/models/notification_item.dart';

// Nhãn tiếng Việt theo mã sự kiện gốc. Mã lạ dùng nhãn chung, không ném lỗi.
// Câu chữ không được khẳng định quá Event: "B báo đã chuyển khoản" không phải
// "đã thanh toán"; tiền chỉ được tính khi người bán xác nhận (BR-29).
String notificationTitleVi(String type) => switch (type) {
  'REQUEST_ACCEPTED' => 'Yêu cầu đã được duyệt',
  'DELIVERY_ASSIGNED' => 'Đã có người nhận giao hộ',
  'HANDOVER_CONFIRMED' => 'Bàn giao đã được xác nhận',
  'HANDOVER_DISPUTED' => 'Bàn giao bị từ chối xác nhận',
  'HANDOVER_EVIDENCE_SUBMITTED' => 'Có bằng chứng bàn giao mới',
  'BORROW_STARTED' => 'Kỳ mượn đã bắt đầu',
  'RETURN_REQUESTED' => 'Có yêu cầu trả tài liệu',
  'PAYMENT_REPORTED' => 'Người mua báo đã chuyển khoản',
  'SELLER_PAYMENT_CONFIRMED' => 'Người bán xác nhận đã nhận tiền',
  'REFUND_REPORTED' => 'Có báo đã hoàn tiền',
  'REFUND_CONFIRMED' => 'Hoàn tiền đã được xác nhận',
  'CANCELLATION_PROPOSED' => 'Có đề nghị hủy giao dịch',
  'CANCELLATION_WITHDRAWN' => 'Đề nghị hủy đã được rút lại',
  'CANCELLATION_DECLINED' => 'Đề nghị hủy bị từ chối',
  'TRANSACTION_CANCELLED' => 'Giao dịch đã hủy',
  'TRANSACTION_COMPLETED' => 'Giao dịch đã hoàn tất',
  'ISSUE_OPENED' || 'ISSUE_REPORTED' => 'Có sự cố mới',
  'RESOLUTION_PROPOSED' => 'Có phương án giải quyết sự cố',
  'RESOLUTION_CONFIRMED' => 'Phương án giải quyết được xác nhận',
  'ISSUE_RESOLVED' => 'Sự cố đã được giải quyết',
  _ => 'Thông báo',
};

IconData notificationIcon(AppNotification notice) {
  final type = notice.type;
  if (type.startsWith('PAYMENT') ||
      type.startsWith('SELLER_PAYMENT') ||
      type.startsWith('REFUND')) {
    return Icons.payments_outlined;
  }
  if (type.startsWith('CANCELLATION') || type == 'TRANSACTION_CANCELLED') {
    return Icons.cancel_outlined;
  }
  if (type.startsWith('HANDOVER') || type.startsWith('DELIVERY')) {
    return Icons.local_shipping_outlined;
  }
  return switch (notice.entityType) {
    NotificationEntityType.issue => Icons.report_outlined,
    NotificationEntityType.request => Icons.mark_email_unread_outlined,
    NotificationEntityType.transaction => Icons.swap_horiz,
    NotificationEntityType.deliveryTask ||
    NotificationEntityType.handover => Icons.local_shipping_outlined,
    NotificationEntityType.unknown => Icons.notifications_outlined,
  };
}

/// Route nội bộ mà thông báo trỏ tới; null khi không có màn phù hợp.
/// Chỉ dựng URL từ loại + ID opaque. Màn đích tự tải lại dữ liệu theo quyền
/// hiện tại và hiện "không còn khả dụng" nếu người dùng không còn truy cập.
String? notificationTargetRoute(AppNotification notice) {
  final id = notice.entityId.trim();
  if (id.isEmpty) return null;
  return switch (notice.entityType) {
    NotificationEntityType.transaction => AppRoutes.transactionDetails(id),
    NotificationEntityType.issue => AppRoutes.issueDetails(id),
    NotificationEntityType.deliveryTask => AppRoutes.deliveryDetails(id),
    NotificationEntityType.request => AppRoutes.requestCenter,
    // Màn Handover phụ thuộc vai trò (giao/nhận) nên chưa mở thẳng được.
    NotificationEntityType.handover || NotificationEntityType.unknown => null,
  };
}
