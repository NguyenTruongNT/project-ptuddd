import 'domain_enums.dart';

// Các input chỉ truyền dữ liệu nghiệp vụ. Không truyền actorId, ownerId,
// holderId hoặc status mới: server phải tự xác định từ session và dữ liệu DB.
class CreateMaterialInput {
  const CreateMaterialInput({
    required this.title,
    required this.subject,
    required this.condition,
    this.isbn,
    this.description,
    this.imageIds = const [],
  });
  final String title;
  final String subject;
  final String condition;
  final String? isbn;
  final String? description;
  final List<String> imageIds;
}

class CreateListingInput {
  const CreateListingInput({
    required this.materialId,
    required this.offerType,
    this.askingPriceVnd,
  });
  final String materialId;
  final OfferType offerType;
  final int? askingPriceVnd;
}

class CreateRequestInput {
  const CreateRequestInput({required this.listingId, this.requestedBorrowDays});
  final String listingId;
  final int? requestedBorrowDays;
}

class CreateDeliveryTaskInput {
  const CreateDeliveryTaskInput({
    required this.transactionId,
    required this.finalReceiverId,
  });
  final String transactionId;
  final String finalReceiverId;
}

class SubmitHandoverEvidenceInput {
  const SubmitHandoverEvidenceInput({
    required this.handoverId,
    required this.uploadedEvidenceIds,
  });
  final String handoverId;
  // IDs do Storage/server trả về sau khi upload; đường dẫn ảnh local không đủ.
  final List<String> uploadedEvidenceIds;
}

class RefuseHandoverInput {
  const RefuseHandoverInput({required this.handoverId, required this.reason});
  final String handoverId;
  final String reason;
}

class CreateIssueInput {
  const CreateIssueInput({
    required this.transactionId,
    required this.type,
    required this.reason,
    this.handoverId,
  });
  final String transactionId;
  final IssueType type;
  final String reason;
  final String? handoverId;
}
