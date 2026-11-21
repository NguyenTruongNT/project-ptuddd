// Chỉ đưa preview an toàn lên UI; không chứa dữ liệu nhạy cảm.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.safePreview,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String recipientId;
  final String safePreview;
  final DateTime createdAt;
  final DateTime? readAt;
}
