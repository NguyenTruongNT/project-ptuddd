import '../../../core/backend/workflow_json.dart';
import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/issue.dart';
import '../../../core/contracts/repositories/issue_repository.dart';

IssueDetails issueDetailsFromRpc(Object? raw) {
  final r = WorkflowJson.object(raw);
  final i = WorkflowJson.object(r['issue']);
  final proposal = r['proposal'] == null
      ? null
      : WorkflowJson.object(r['proposal']);
  return IssueDetails(
    issue: Issue(
      id: WorkflowJson.text(i['id']),
      transactionId: WorkflowJson.text(i['transactionId']),
      reporterId: WorkflowJson.text(i['reporterId']),
      type: IssueType.fromWire(WorkflowJson.text(i['type'])),
      reason: WorkflowJson.text(i['reason']),
      status: IssueStatus.fromWire(WorkflowJson.text(i['status'])),
      openedAt: WorkflowJson.timestamp(i['openedAt']),
      handoverId: WorkflowJson.optionalText(i['handoverId']),
      resolvedAt: WorkflowJson.optionalTimestamp(i['resolvedAt']),
    ),
    materialTitle: WorkflowJson.text(r['materialTitle']),
    reporterDisplayName: WorkflowJson.text(r['reporterDisplayName']),
    counterpartyDisplayName: WorkflowJson.text(r['counterpartyDisplayName']),
    relation: switch (r['relation']) {
      'REPORTER' => IssueRelation.reporter,
      'COUNTERPARTY' => IssueRelation.counterparty,
      _ => throw const FormatException('Invalid issue relation'),
    },
    proposal: proposal == null
        ? null
        : IssueResolutionProposal(
            revision: WorkflowJson.integer(proposal['revision']),
            summary: WorkflowJson.text(proposal['summary']),
            proposedByDisplayName: WorkflowJson.text(
              proposal['proposedByDisplayName'],
            ),
            proposedAt: WorkflowJson.timestamp(proposal['proposedAt']),
            consents: List.unmodifiable(
              WorkflowJson.list(proposal['consents']).map((value) {
                final consent = WorkflowJson.object(value);
                return IssueConsent(
                  participantDisplayName: WorkflowJson.text(
                    consent['participantDisplayName'],
                  ),
                  approvedAt: WorkflowJson.optionalTimestamp(
                    consent['approvedAt'],
                  ),
                );
              }),
            ),
          ),
    evidenceCount: WorkflowJson.integer(r['evidenceCount']),
    canViewEvidence: WorkflowJson.boolean(r['canViewEvidence']),
    canViewTransaction: WorkflowJson.boolean(r['canViewTransaction']),
    allowedActions: Set.unmodifiable(
      WorkflowJson.list(r['allowedActions'])
          .map((a) => IssueAction.fromWire(WorkflowJson.text(a))),
    ),
  );
}

class SupabaseIssueQueryRepository implements IssueQueryRepository {
  const SupabaseIssueQueryRepository(this.rpc);
  final WorkflowRpc rpc;
  @override
  Future<List<IssueDetails>> getMyIssues() => rpc.read(
    'get_my_issues',
    {},
    (raw) => List.unmodifiable(WorkflowJson.list(raw).map(issueDetailsFromRpc)),
  );
  @override
  Future<IssueDetails?> getIssueDetails(String issueId) => rpc.read(
    'get_issue_details',
    {'p_issue_id': issueId},
    (raw) => raw == null ? null : issueDetailsFromRpc(raw),
  );
  @override
  Future<List<IssueEventItem>> getTimeline(String issueId) => rpc.read(
    'get_issue_timeline',
    {'p_issue_id': issueId},
    (raw) => List.unmodifiable(
      WorkflowJson.list(raw).map((value) {
        final r = WorkflowJson.object(value);
        return IssueEventItem(
          id: WorkflowJson.text(r['id']),
          issueId: WorkflowJson.text(r['issueId']),
          eventType: WorkflowJson.text(r['eventType']),
          serverAt: WorkflowJson.timestamp(r['serverAt']),
          safeDescription: WorkflowJson.text(r['safeDescription']),
          actorDisplay: WorkflowJson.optionalText(r['actorDisplay']),
        );
      }),
    ),
  );
}

class SupabaseIssueRepository implements IssueRepository {
  const SupabaseIssueRepository(this.rpc);
  final WorkflowRpc rpc;
  String? _invalid(String id, String key, {String? text}) {
    if (id.trim().isEmpty || key.trim().isEmpty) {
      return 'Thiếu sự cố/giao dịch hoặc mã thao tác.';
    }
    if (text != null && (text.trim().isEmpty || text.trim().length > 1000)) {
      return 'Nội dung cần từ 1 đến 1000 ký tự.';
    }
    return null;
  }

  @override
  Future<CommandResult<IssueDetails>> reportIssue(
    CreateIssueInput input, {
    required String idempotencyKey,
  }) => rpc.command(
    'report_issue',
    {
      'p_transaction_id': input.transactionId,
      'p_issue_type': input.type.wire,
      'p_reason': input.reason.trim(),
      'p_handover_id': input.handoverId,
      'p_idempotency_key': idempotencyKey,
    },
    issueDetailsFromRpc,
    validationMessage: _invalid(
      input.transactionId,
      idempotencyKey,
      text: input.reason,
    ),
  );
  @override
  Future<CommandResult<IssueDetails>> proposeResolution(
    String issueId,
    String summary, {
    required String idempotencyKey,
  }) => rpc.command(
    'propose_issue_resolution',
    {
      'p_issue_id': issueId,
      'p_summary': summary.trim(),
      'p_idempotency_key': idempotencyKey,
    },
    issueDetailsFromRpc,
    validationMessage: _invalid(issueId, idempotencyKey, text: summary),
  );
  @override
  Future<CommandResult<IssueDetails>> confirmResolution(
    String issueId,
    int resolutionRevision, {
    required String idempotencyKey,
  }) => rpc.command(
    'confirm_issue_resolution',
    {
      'p_issue_id': issueId,
      'p_resolution_revision': resolutionRevision,
      'p_idempotency_key': idempotencyKey,
    },
    issueDetailsFromRpc,
    validationMessage:
        _invalid(issueId, idempotencyKey) ??
        (resolutionRevision <= 0
            ? 'Phiên bản phương án không hợp lệ. Hãy tải lại.'
            : null),
  );
}
