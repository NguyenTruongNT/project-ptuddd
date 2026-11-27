// Chỉ đưa preview an toàn lên UI; không chứa dữ liệu nhạy cảm.
// Thông báo là DẪN XUẤT từ Event của server, không phải nguồn trạng thái:
// đọc thông báo không bao giờ thay thế việc tải lại Transaction/Issue.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.safePreview,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String recipientId;
  // Mã sự kiện gốc (vd. PAYMENT_REPORTED). Cột server là text tự do nên giữ
  // nguyên chuỗi; UI ánh xạ nhãn và rơi về nhãn chung khi gặp mã lạ.
  final String type;
  // Tham chiếu tài nguyên cho deep link: chỉ loại + ID opaque, màn đích phải
  // tải lại và kiểm tra quyền trước khi hiển thị (CONTRACTS.md, SEC-02).
  final NotificationEntityType entityType;
  final String entityId;
  final String safePreview;
  final DateTime createdAt;
  // Do server ghi khi người nhận đánh dấu đã đọc.
  final DateTime? readAt;

  bool get isRead => readAt != null;
}

// Loại tài nguyên mà thông báo trỏ tới (cột `entity_type`).
// Khác các enum trong domain_enums.dart: cột này chưa có CHECK ở server, nên
// mã lạ chuyển thành `unknown` thay vì ném lỗi, để một thông báo mới không làm
// hỏng cả hộp thư. Thông báo `unknown` vẫn hiển thị nhưng không mở được.
enum NotificationEntityType {
  transaction('TRANSACTION'),
  issue('ISSUE'),
  request('REQUEST'),
  deliveryTask('DELIVERY_TASK'),
  handover('HANDOVER'),
  unknown('');

  const NotificationEntityType(this.wire);
  final String wire;

  static NotificationEntityType parse(String raw) {
    final normalized = raw.trim().toUpperCase();
    for (final value in values) {
      if (value != unknown && value.wire == normalized) return value;
    }
    return unknown;
  }
}
