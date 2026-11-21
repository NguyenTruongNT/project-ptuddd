// Các mã lỗi trả về từ server theo CONTRACTS.md, không tự sinh trạng thái nghiệp vụ.
enum DomainErrorCode {
  authRequired('AUTH_REQUIRED'),
  forbidden('FORBIDDEN'),
  invalidInput('INVALID_INPUT'),
  materialUnavailable('MATERIAL_UNAVAILABLE'),
  conflict('CONFLICT'),
  duplicateRequest('DUPLICATE_REQUEST'),
  duplicateActiveTransaction('DUPLICATE_ACTIVE_TRANSACTION'),
  requestNotPending('REQUEST_NOT_PENDING'),
  invalidTransactionTransition('INVALID_TRANSACTION_TRANSITION'),
  invalidHandoverParticipant('INVALID_HANDOVER_PARTICIPANT'),
  qrMismatch('QR_MISMATCH'),
  evidenceRequired('EVIDENCE_REQUIRED'),
  evidenceUploadFailed('EVIDENCE_UPLOAD_FAILED'),
  receiverConfirmationRequired('RECEIVER_CONFIRMATION_REQUIRED'),
  paymentNotConfirmed('PAYMENT_NOT_CONFIRMED'),
  issueBlockingAction('ISSUE_BLOCKING_ACTION'),
  cancellationObligationPending('CANCELLATION_OBLIGATION_PENDING'),
  networkUnavailable('NETWORK_UNAVAILABLE'),
  timeoutUnknown('TIMEOUT_UNKNOWN'); // Chỉ sinh tại client khi chưa rõ ACK.

  const DomainErrorCode(this.wire);
  final String wire;

  static DomainErrorCode fromWire(String raw) {
    for (final value in values) {
      if (value.wire == raw) return value;
    }
    // Lỗi server mới/chưa biết được hiển thị an toàn; không lộ raw payload.
    return DomainErrorCode.conflict;
  }
}

class AppError implements Exception {
  const AppError(this.code, this.safeMessage);

  final DomainErrorCode code;
  final String safeMessage;

  @override
  String toString() => 'AppError(${code.wire}): $safeMessage';
}
