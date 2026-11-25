// Material đại diện cho MỘT bản sách/tài liệu vật lý, không phải một lần đăng tin.
class Material {
  const Material({
    required this.id,
    required this.ownerId,
    required this.holderId,
    required this.title,
    required this.subject,
    required this.condition,
    this.isbn,
    this.description,
    this.revision = 1,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String holderId;
  final String title;
  final String subject;
  final String condition;
  final String? isbn;
  final String? description;
  final int revision;
  final DateTime? updatedAt;

  // Không cung cấp setOwner/setHolder: chỉ server được thay khi ACK hợp lệ.
}

// Read model cho danh sách tài liệu cá nhân, không chứa bí mật QR.
class MaterialSummary {
  const MaterialSummary({
    required this.id,
    required this.title,
    required this.subject,
    required this.ownerId,
    required this.holderId,
    this.coverUrl,
    this.canEdit = false,
    this.canPublish = false,
    this.listingStatus,
    this.hasActiveTransaction = false,
  });

  final String id;
  final String title;
  final String subject;
  final String ownerId;
  final String holderId;
  final String? coverUrl;
  final bool canEdit;
  final bool canPublish;
  final String? listingStatus;
  final bool hasActiveTransaction;
}
