import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../core/contracts/repositories/transaction_repository.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/mock/mock_fixtures.dart';
import '../../../core/mock/mock_transaction_store.dart';

/// Mô phỏng command `request_borrow_return`.
///
/// Repository sử dụng chung [MockTransactionStore] với module Transaction.
/// Thao tác này chỉ ghi nhận ý định trả tài liệu:
///
/// - Chuyển `BORROWING` sang `RETURN_PENDING`.
/// - Ghi đúng một sự kiện `RETURN_REQUESTED`.
/// - Lưu receipt để retry cùng idempotency key không ghi trùng.
///
/// Repository không thay đổi chủ sở hữu, người giữ, hạn trả hoặc tự hoàn tất
/// giao dịch. Backend thật vẫn phải kiểm tra lại quyền và trạng thái.
class MockBorrowRepository implements BorrowRepository {
  MockBorrowRepository(this._store, this._actorId);

  static const String _command = 'request_borrow_return';

  final MockTransactionStore _store;
  final String _actorId;

  @override
  Future<CommandResult<StudyTransaction>> requestReturn(
    String transactionId, {
    required String idempotencyKey,
  }) async {
    final String normalizedTransactionId = transactionId.trim();
    final String normalizedKey = idempotencyKey.trim();

    if (normalizedTransactionId.isEmpty) {
      return const CommandError<StudyTransaction>(
        DomainErrorCode.invalidInput,
        'Thiếu mã giao dịch.',
      );
    }

    if (normalizedKey.isEmpty) {
      return const CommandError<StudyTransaction>(
        DomainErrorCode.invalidInput,
        'Thiếu mã thao tác, vui lòng thử lại.',
      );
    }

    final StudyTransaction? transaction = _store.transaction(
      normalizedTransactionId,
    );

    // Không phân biệt giao dịch không tồn tại và giao dịch không có quyền.
    // Cách xử lý này tránh làm lộ dữ liệu cho tài khoản không liên quan.
    if (transaction == null ||
        (transaction.ownerAtAcceptance != _actorId &&
            transaction.receiverId != _actorId)) {
      return const CommandError<StudyTransaction>(
        DomainErrorCode.forbidden,
        'Bạn không có quyền thực hiện thao tác này.',
      );
    }

    final String payloadHash = '$_command|$normalizedTransactionId';

    final MockCommandReceipt? previousReceipt = _store.receipt(
      _actorId,
      _command,
      normalizedKey,
    );

    if (previousReceipt != null) {
      if (previousReceipt.payloadHash != payloadHash) {
        return const CommandError<StudyTransaction>(
          DomainErrorCode.conflict,
          'Mã thao tác đã được dùng cho nội dung khác.',
        );
      }

      // Retry cùng key trả lại kết quả đã được mock server ghi nhận.
      // Không chuyển trạng thái hoặc ghi thêm sự kiện.
      return CommandOk<StudyTransaction>(
        _store.transaction(normalizedTransactionId)!,
        previousReceipt.eventId,
      );
    }

    if (transaction.type != OfferType.borrow) {
      return const CommandError<StudyTransaction>(
        DomainErrorCode.invalidTransactionTransition,
        'Chỉ giao dịch cho mượn mới có thể yêu cầu trả.',
      );
    }

    // Chủ tài liệu không được yêu cầu trả thay người đang mượn.
    if (transaction.receiverId != _actorId) {
      return const CommandError<StudyTransaction>(
        DomainErrorCode.forbidden,
        'Chỉ người đang mượn mới có thể yêu cầu trả tài liệu.',
      );
    }

    if (transaction.status != TransactionStatus.borrowing) {
      return const CommandError<StudyTransaction>(
        DomainErrorCode.invalidTransactionTransition,
        'Giao dịch không ở trạng thái đang mượn.',
      );
    }

    // Một command mock thực hiện trọn vẹn:
    //
    // BORROWING -> RETURN_PENDING
    // + TransactionEvent
    // + command receipt
    //
    // Không thay owner, holder, dueDate hoặc chuyển sang COMPLETED.
    _store.setStatus(normalizedTransactionId, TransactionStatus.returnPending);

    final String eventId = _store.appendEvent(
      transactionId: normalizedTransactionId,
      eventType: 'RETURN_REQUESTED',
      safeDescription: 'Người mượn đã gửi yêu cầu trả tài liệu.',
      actorDisplay: MockFixtures.displayNames[_actorId],
    );

    _store.saveReceipt(
      _actorId,
      _command,
      normalizedKey,
      MockCommandReceipt(
        payloadHash: payloadHash,
        eventId: eventId,
        entityId: normalizedTransactionId,
      ),
    );

    final StudyTransaction updatedTransaction = _store.transaction(
      normalizedTransactionId,
    )!;

    return CommandOk<StudyTransaction>(updatedTransaction, eventId);
  }
}
