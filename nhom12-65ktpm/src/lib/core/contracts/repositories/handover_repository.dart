import '../command_inputs.dart';
import '../command_result.dart';
import '../models/handover.dart';
import '../models/issue.dart';
import '../models/transaction.dart';

abstract interface class HandoverRepository {
  Future<Handover?> getHandover(String handoverId);

  // Server đối chiếu QR; QR sai phải trả lỗi QR_MISMATCH, không fallback.
  Future<CommandResult<bool>> verifyMaterialCode(
    String handoverId, String scannedCode, {required String idempotencyKey});

  Future<CommandResult<Handover>> submitEvidence(
    SubmitHandoverEvidenceInput input, {required String idempotencyKey});

  // Chỉ người nhận của đúng chặng mới có thể xác nhận.
  Future<CommandResult<StudyTransaction>> confirmReceipt(
    String handoverId, {required String idempotencyKey});

  Future<CommandResult<Issue>> refuseReceipt(
    RefuseHandoverInput input, {required String idempotencyKey});
}
