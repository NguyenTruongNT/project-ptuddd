import '../../../core/backend/workflow_json.dart';
import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/handover.dart';
import '../../../core/contracts/models/issue.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../transactions/data/supabase_transaction_repository.dart';
import '../domain/handover_feature_repository.dart';

Handover _handoverFromJson(Object? raw) {
  final map = WorkflowJson.object(raw);
  return Handover(
    id: WorkflowJson.text(map['id']),
    transactionId: WorkflowJson.text(map['transaction_id']),
    fromUserId: WorkflowJson.text(map['from_user_id']),
    toUserId: WorkflowJson.text(map['to_user_id']),
    status: HandoverStatus.fromWire(WorkflowJson.text(map['status'])),
    deliveryTaskId: WorkflowJson.optionalText(map['delivery_task_id']),
    evidencePhotoCount: WorkflowJson.integer(map['evidence_photo_count']),
    qrMismatchBlocked: map['qr_mismatch_blocked'] == true,
  );
}

/// Triển khai kết nối Supabase RPC thật cho phân hệ Handover & QR.
class SupabaseHandoverRepository implements HandoverFeatureRepository {
  const SupabaseHandoverRepository(this.rpc);

  final WorkflowRpc rpc;

  @override
  Future<Handover?> getHandover(String handoverId) => rpc.read(
        'get_handover_details',
        {'p_handover_id': handoverId},
        (raw) => raw == null ? null : _handoverFromJson(raw),
      );

  @override
  Future<List<String>> getEvidencePaths(String handoverId) => rpc.read(
        'get_handover_evidence_paths',
        {'p_handover_id': handoverId},
        (raw) => List.unmodifiable(
          WorkflowJson.list(raw).map(WorkflowJson.text),
        ),
      );

  @override
  Future<CommandResult<Handover>> createHandover({
    required String transactionId,
    required String toUserId,
    String? deliveryTaskId,
    required String idempotencyKey,
  }) =>
      rpc.command(
        'create_handover',
        {
          'p_transaction_id': transactionId,
          'p_to_user_id': toUserId,
          'p_delivery_task_id': deliveryTaskId,
          'p_idempotency_key': idempotencyKey,
        },
        _handoverFromJson,
      );

  @override
  Future<CommandResult<bool>> verifyMaterialCode(
    String handoverId,
    String scannedCode, {
    required String idempotencyKey,
  }) =>
      rpc.command(
        'verify_material_code',
        {
          'p_handover_id': handoverId,
          'p_scanned_code': scannedCode,
          'p_verification_method': 'QR',
          'p_fallback_reason': null,
          'p_idempotency_key': idempotencyKey,
        },
        (_) => true,
      );

  @override
  Future<CommandResult<bool>> verifyWithFallback(
    String handoverId,
    String reason, {
    required String idempotencyKey,
  }) =>
      rpc.command(
        'verify_material_code',
        {
          'p_handover_id': handoverId,
          'p_scanned_code': '',
          'p_verification_method': 'FALLBACK',
          'p_fallback_reason': reason,
          'p_idempotency_key': idempotencyKey,
        },
        (_) => true,
      );

  @override
  Future<CommandResult<Handover>> submitEvidence(
    SubmitHandoverEvidenceInput input, {
    required String idempotencyKey,
  }) =>
      rpc.command(
        'submit_handover_evidence',
        {
          'p_handover_id': input.handoverId,
          'p_storage_paths': input.uploadedEvidenceIds,
          'p_idempotency_key': idempotencyKey,
        },
        _handoverFromJson,
      );

  @override
  Future<CommandResult<StudyTransaction>> confirmReceipt(
    String handoverId, {
    required String idempotencyKey,
  }) async {
    final res = await rpc.command(
      'confirm_handover',
      {
        'p_handover_id': handoverId,
        'p_idempotency_key': idempotencyKey,
      },
      _handoverFromJson,
    );

    switch (res) {
      case CommandError(:final code, :final safeMessage):
        return CommandError(code, safeMessage);
      case CommandOk(:final data, :final serverEventId):
        // Tải snapshot transaction mới nhất từ server nếu actor là A/B.
        final txnDetails = await rpc.read(
          'get_transaction_details',
          {'p_transaction_id': data.transactionId},
          (raw) => raw == null ? null : transactionDetailsFromRpc(raw),
        );
        final txn = txnDetails?.transaction ??
            StudyTransaction(
              id: data.transactionId,
              listingId: '',
              requestId: '',
              materialId: '',
              type: OfferType.borrow,
              ownerAtAcceptance: data.fromUserId,
              receiverId: data.toUserId,
              status: TransactionStatus.handoverInProgress,
            );
        return CommandOk(txn, serverEventId);
    }
  }

  @override
  Future<CommandResult<Issue>> refuseReceipt(
    RefuseHandoverInput input, {
    required String idempotencyKey,
  }) async {
    final res = await rpc.command(
      'refuse_handover',
      {
        'p_handover_id': input.handoverId,
        'p_reason': input.reason,
        'p_issue_type': IssueType.wrongMaterial.wire,
        'p_idempotency_key': idempotencyKey,
      },
      _handoverFromJson,
    );

    switch (res) {
      case CommandError(:final code, :final safeMessage):
        return CommandError(code, safeMessage);
      case CommandOk(:final data, :final serverEventId):
        return CommandOk(
          Issue(
            id: serverEventId ?? 'issue-${data.id}',
            transactionId: data.transactionId,
            reporterId: rpc.actor,
            type: IssueType.wrongMaterial,
            reason: input.reason,
            handoverId: data.id,
            status: IssueStatus.open,
            openedAt: DateTime.now().toUtc(),
          ),
          serverEventId,
        );
    }
  }
}
