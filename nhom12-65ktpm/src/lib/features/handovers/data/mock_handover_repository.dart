import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/handover.dart';
import '../../../core/contracts/models/issue.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/mock/mock_fixtures.dart';
import '../../../core/mock/mock_transaction_store.dart';
import '../domain/handover_feature_repository.dart';

/// Triển khai Mock Repository cho Handover và QR.
class MockHandoverRepository implements HandoverFeatureRepository {
  MockHandoverRepository({
    required this.actorId,
    required this.store,
  });

  final String actorId;
  final MockTransactionStore store;

  // Dùng Map tĩnh dùng chung để mọi instance của người giao và người nhận đều chia sẻ cùng dữ liệu
  static final Map<String, Handover> _handovers = {
    for (final h in MockFixtures.handovers) h.id: h,
    'handover-delivery-h1': const Handover(
      id: 'handover-delivery-h1',
      transactionId: 'txn-delivery-01',
      fromUserId: MockFixtures.userA,
      toUserId: MockFixtures.userC,
      status: HandoverStatus.pending,
      evidencePhotoCount: 0,
    ),
    'handover-delivery-h2': const Handover(
      id: 'handover-delivery-h2',
      transactionId: 'txn-delivery-01',
      fromUserId: MockFixtures.userC,
      toUserId: MockFixtures.userB,
      status: HandoverStatus.pending,
      evidencePhotoCount: 0,
    ),
  };

  static int _issueCounter = 100;

  @override
  Future<Handover?> getHandover(String handoverId) async {
    return _handovers[handoverId];
  }

  @override
  Future<CommandResult<bool>> verifyMaterialCode(
    String handoverId,
    String scannedCode, {
    required String idempotencyKey,
  }) async {
    final handover = _handovers[handoverId];
    if (handover == null) {
      return CommandError(
        DomainErrorCode.invalidInput,
        'Không tìm thấy lượt bàn giao.',
      );
    }

    final code = scannedCode.trim();
    if (code.isEmpty) {
      return CommandError(
        DomainErrorCode.invalidInput,
        'Mã quét không được để trống.',
      );
    }

    final txn = store.transaction(handover.transactionId);
    final validMaterialId = txn?.materialId ?? 'mat-default';

    final isMatch = code == validMaterialId ||
        code == handoverId ||
        code == 'VALID-QR-CODE' ||
        code.startsWith('mat-borrow') ||
        code.startsWith('mat-delivery');

    if (!isMatch) {
      return CommandError(
        DomainErrorCode.qrMismatch,
        'Mã QR không khớp với tài liệu hoặc chặng bàn giao này. Vui lòng kiểm tra lại tài liệu vật lý.',
      );
    }

    return CommandOk(true, 'evt-qr-verified-$handoverId');
  }

  @override
  Future<CommandResult<Handover>> submitEvidence(
    SubmitHandoverEvidenceInput input, {
    required String idempotencyKey,
  }) async {
    final handover = _handovers[input.handoverId];
    if (handover == null) {
      return CommandError(
        DomainErrorCode.invalidInput,
        'Không tìm thấy lượt bàn giao.',
      );
    }

    if (handover.fromUserId != actorId) {
      return CommandError(
        DomainErrorCode.forbidden,
        'Chỉ người giao tài liệu mới có quyền gửi ảnh minh chứng.',
      );
    }

    if (input.uploadedEvidenceIds.isEmpty) {
      return CommandError(
        DomainErrorCode.evidenceRequired,
        'Bắt buộc phải chụp và tải lên ít nhất 1 ảnh minh chứng trước khi chuyển giao.',
      );
    }

    final updated = Handover(
      id: handover.id,
      transactionId: handover.transactionId,
      fromUserId: handover.fromUserId,
      toUserId: handover.toUserId,
      status: HandoverStatus.awaitingReceiverConfirmation,
      deliveryTaskId: handover.deliveryTaskId,
      evidencePhotoCount: input.uploadedEvidenceIds.length,
    );

    _handovers[handover.id] = updated;

    store.appendEvent(
      transactionId: handover.transactionId,
      eventType: 'HANDOVER_EVIDENCE_SUBMITTED',
      safeDescription:
          'Người giao đã nộp ${input.uploadedEvidenceIds.length} ảnh minh chứng. Đang chờ người nhận xác nhận.',
      actorDisplay: MockFixtures.displayNames[actorId] ?? actorId,
    );

    return CommandOk(updated, 'evt-evidence-submitted-${handover.id}');
  }

  @override
  Future<CommandResult<StudyTransaction>> confirmReceipt(
    String handoverId, {
    required String idempotencyKey,
  }) async {
    final handover = _handovers[handoverId];
    if (handover == null) {
      return CommandError(
        DomainErrorCode.invalidInput,
        'Không tìm thấy lượt bàn giao.',
      );
    }

    if (handover.toUserId != actorId) {
      return CommandError(
        DomainErrorCode.invalidHandoverParticipant,
        'Chỉ người nhận chỉ định mới có quyền xác nhận nhận tài liệu.',
      );
    }

    if (handover.status != HandoverStatus.awaitingReceiverConfirmation) {
      return CommandError(
        DomainErrorCode.receiverConfirmationRequired,
        'Lượt bàn giao chưa sẵn sàng hoặc chưa được người giao nộp ảnh minh chứng.',
      );
    }

    final updatedHandover = Handover(
      id: handover.id,
      transactionId: handover.transactionId,
      fromUserId: handover.fromUserId,
      toUserId: handover.toUserId,
      status: HandoverStatus.confirmed,
      deliveryTaskId: handover.deliveryTaskId,
      evidencePhotoCount: handover.evidencePhotoCount,
    );
    _handovers[handoverId] = updatedHandover;

    final txn = store.transaction(handover.transactionId);
    if (txn != null) {
      if (txn.type == OfferType.borrow && handover.toUserId == txn.receiverId) {
        store.setStatus(txn.id, TransactionStatus.borrowing);
      } else if (txn.type == OfferType.donate && handover.toUserId == txn.receiverId) {
        store.setStatus(txn.id, TransactionStatus.completed);
      }

      store.appendEvent(
        transactionId: txn.id,
        eventType: 'HANDOVER_CONFIRMED',
        safeDescription: 'Người nhận đã xác nhận nhận tài liệu thành công.',
        actorDisplay: MockFixtures.displayNames[actorId] ?? actorId,
      );
    }

    final finalTxn = store.transaction(handover.transactionId) ??
        StudyTransaction(
          id: handover.transactionId,
          listingId: 'list-unknown',
          requestId: 'req-unknown',
          materialId: 'mat-unknown',
          type: OfferType.borrow,
          ownerAtAcceptance: handover.fromUserId,
          receiverId: handover.toUserId,
          status: TransactionStatus.borrowing,
        );

    return CommandOk(finalTxn, 'evt-receipt-confirmed-$handoverId');
  }

  @override
  Future<CommandResult<Issue>> refuseReceipt(
    RefuseHandoverInput input, {
    required String idempotencyKey,
  }) async {
    final handover = _handovers[input.handoverId];
    if (handover == null) {
      return CommandError(
        DomainErrorCode.invalidInput,
        'Không tìm thấy lượt bàn giao.',
      );
    }

    if (input.reason.trim().isEmpty) {
      return CommandError(
        DomainErrorCode.invalidInput,
        'Bắt buộc phải cung cấp lý do từ chối nhận tài liệu.',
      );
    }

    final updatedHandover = Handover(
      id: handover.id,
      transactionId: handover.transactionId,
      fromUserId: handover.fromUserId,
      toUserId: handover.toUserId,
      status: HandoverStatus.disputed,
      deliveryTaskId: handover.deliveryTaskId,
      evidencePhotoCount: handover.evidencePhotoCount,
    );
    _handovers[input.handoverId] = updatedHandover;

    _issueCounter++;
    final issue = Issue(
      id: 'issue-handover-$_issueCounter',
      transactionId: handover.transactionId,
      reporterId: actorId,
      type: IssueType.wrongMaterial,
      reason: input.reason.trim(),
      handoverId: handover.id,
      status: IssueStatus.open,
      openedAt: store.clock(),
    );

    store.putIssue(issue);
    store.appendEvent(
      transactionId: handover.transactionId,
      eventType: 'HANDOVER_DISPUTED',
      safeDescription:
          'Người nhận đã từ chối nhận tài liệu. Lý do: ${input.reason.trim()}',
      actorDisplay: MockFixtures.displayNames[actorId] ?? actorId,
    );

    return CommandOk(issue, 'evt-receipt-refused-${input.handoverId}');
  }

  @override
  Future<CommandResult<Handover>> createHandover({
    required String transactionId,
    required String toUserId,
    String? deliveryTaskId,
    required String idempotencyKey,
  }) async {
    if (transactionId.trim().isEmpty || toUserId.trim().isEmpty) {
      return CommandError(DomainErrorCode.invalidInput, 'Thiếu thông tin giao dịch hoặc người nhận.');
    }
    if (actorId == toUserId) {
      return CommandError(DomainErrorCode.invalidInput, 'Người giao và người nhận không thể trùng nhau.');
    }
    final id = 'handover-mock-${_handovers.length + 1}';
    final handover = Handover(
      id: id,
      transactionId: transactionId,
      fromUserId: actorId,
      toUserId: toUserId,
      deliveryTaskId: deliveryTaskId,
      status: HandoverStatus.pending,
      evidencePhotoCount: 0,
    );
    _handovers[id] = handover;
    return CommandOk(handover, 'evt-handover-created-$id');
  }

  @override
  Future<CommandResult<bool>> verifyWithFallback(
    String handoverId,
    String reason, {
    required String idempotencyKey,
  }) async {
    if (reason.trim().isEmpty) {
      return CommandError(DomainErrorCode.invalidInput, 'Vui lòng nhập lý do đối chiếu thủ công.');
    }
    return CommandOk(true, 'evt-fallback-verified-$handoverId');
  }
}
