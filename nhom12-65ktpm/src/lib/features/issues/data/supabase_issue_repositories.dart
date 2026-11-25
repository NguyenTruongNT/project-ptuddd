import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/issue.dart';
import '../../../core/contracts/repositories/issue_repository.dart';
import '../../transactions/data/supabase_rpc_gateway.dart';

// Repository Issue gọi RPC Supabase thật. Server kiểm tra quyền, revision
// và đồng thuận; client không tự đóng Issue hay đổi holder/owner/payment.

class SupabaseIssueQueryRepository implements IssueQueryRepository {
  const SupabaseIssueQueryRepository(this._rpc);

  final SupabaseRpcGateway _rpc;

  @override
  Future<List<IssueDetails>> getMyIssues() => _rpc.query(
    'get_my_issues',
    const {},
    (raw) => List.unmodifiable(asJsonList(raw).map(parseIssueDetails)),
  );

  // Server trả null cả khi không tồn tại lẫn không có quyền.
  @override
  Future<IssueDetails?> getIssueDetails(String issueId) => _rpc.query(
    'get_issue_details',
    {'p_issue_id': issueId},
    (raw) => raw == null ? null : parseIssueDetails(asJsonMap(raw)),
  );

  @override
  Future<List<IssueEventItem>> getTimeline(String issueId) => _rpc.query(
    'get_issue_timeline',
    {'p_issue_id': issueId},
    (raw) => List.unmodifiable(asJsonList(raw).map(parseIssueEvent)),
  );
}

class SupabaseIssueRepository implements IssueRepository {
  const SupabaseIssueRepository(this._rpc);

  final SupabaseRpcGateway _rpc;

  @override
  Future<CommandResult<IssueDetails>> reportIssue(
    CreateIssueInput input, {
    required String idempotencyKey,
  }) => _rpc.command('report_issue', {
    'p_transaction_id': input.transactionId,
    'p_issue_type': input.type.wire,
    'p_reason': input.reason.trim(),
    'p_handover_id': input.handoverId,
    'p_idempotency_key': idempotencyKey,
  }, parseIssueDetails);

  @override
  Future<CommandResult<IssueDetails>> proposeResolution(
    String issueId,
    String summary, {
    required String idempotencyKey,
  }) => _rpc.command('propose_issue_resolution', {
    'p_issue_id': issueId,
    'p_summary': summary.trim(),
    'p_idempotency_key': idempotencyKey,
  }, parseIssueDetails);

  // Gửi đúng revision đang hiển thị; server trả CONFLICT nếu đã đổi.
  @override
  Future<CommandResult<IssueDetails>> confirmResolution(
    String issueId,
    int resolutionRevision, {
    required String idempotencyKey,
  }) => _rpc.command('confirm_issue_resolution', {
    'p_issue_id': issueId,
    'p_resolution_revision': resolutionRevision,
    'p_idempotency_key': idempotencyKey,
  }, parseIssueDetails);
}

// ---------- Đọc JSON (camelCase, khớp DTO trong core/contracts) ----------

IssueRelation _parseRelation(Object? raw) => switch (raw) {
  'REPORTER' => IssueRelation.reporter,
  'COUNTERPARTY' => IssueRelation.counterparty,
  _ => throw FormatException('Quan hệ sự cố không hợp lệ: $raw'),
};

IssueDetails parseIssueDetails(Map<String, dynamic> json) {
  final proposal = json['proposal'];
  return IssueDetails(
    issue: _parseIssue(asJsonMap(json['issue'])),
    materialTitle: json['materialTitle'] as String? ?? '',
    reporterDisplayName: json['reporterDisplayName'] as String? ?? '',
    counterpartyDisplayName: json['counterpartyDisplayName'] as String? ?? '',
    relation: _parseRelation(json['relation']),
    proposal: proposal == null ? null : _parseProposal(asJsonMap(proposal)),
    evidenceCount: parseOptionalInt(json['evidenceCount']) ?? 0,
    canViewEvidence: json['canViewEvidence'] == true,
    // Mặc định không mở lối tắt giao dịch khi server không nói rõ.
    canViewTransaction: json['canViewTransaction'] == true,
    allowedActions: parseAllowedActions(
      json['allowedActions'],
      IssueAction.fromWire,
    ),
  );
}

Issue _parseIssue(Map<String, dynamic> json) => Issue(
  id: json['id'] as String,
  transactionId: json['transactionId'] as String,
  reporterId: json['reporterId'] as String,
  type: IssueType.fromWire(json['type'] as String),
  reason: json['reason'] as String? ?? '',
  status: IssueStatus.fromWire(json['status'] as String),
  openedAt: parseServerTime(json['openedAt']),
  handoverId: json['handoverId'] as String?,
  resolvedAt: parseOptionalServerTime(json['resolvedAt']),
);

IssueResolutionProposal _parseProposal(Map<String, dynamic> json) =>
    IssueResolutionProposal(
      revision: (json['revision'] as num).toInt(),
      summary: json['summary'] as String? ?? '',
      proposedByDisplayName: json['proposedByDisplayName'] as String? ?? '',
      proposedAt: parseServerTime(json['proposedAt']),
      consents: List.unmodifiable(
        asJsonList(json['consents']).map(
          (c) => IssueConsent(
            participantDisplayName:
                c['participantDisplayName'] as String? ?? '',
            approvedAt: parseOptionalServerTime(c['approvedAt']),
          ),
        ),
      ),
    );

IssueEventItem parseIssueEvent(Map<String, dynamic> json) => IssueEventItem(
  id: json['id'] as String,
  issueId: json['issueId'] as String,
  eventType: json['eventType'] as String,
  serverAt: parseServerTime(json['serverAt']),
  safeDescription: json['safeDescription'] as String? ?? '',
  actorDisplay: json['actorDisplay'] as String?,
);
