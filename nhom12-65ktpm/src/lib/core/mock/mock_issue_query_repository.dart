import '../contracts/models/models.dart';
import '../contracts/repositories/issue_repository.dart';
import 'mock_fixtures.dart';
import 'mock_issue_access.dart';
import 'mock_transaction_store.dart';

// Repository ĐỌC Issue. allowedActions mô phỏng gợi ý của server,
// không phải quyết định cuối: lệnh mock vẫn kiểm tra lại quyền và trạng thái.
class MockIssueQueryRepository implements IssueQueryRepository {
  MockIssueQueryRepository({
    required this.demoViewerId,
    MockTransactionStore? store,
  }) : store = store ?? MockTransactionStore.fromFixtures();

  final String demoViewerId;
  final MockTransactionStore store;

  // A/B của giao dịch và các bên liên quan trực tiếp (vd. C ở đúng chặng).
  // Courier không xem Issue chỉ vì là courier: phải là một đầu của chặng đó.
  bool _canSee(Issue issue) => canReadIssue(store, issue, demoViewerId);

  @override
  Future<List<IssueDetails>> getMyIssues() async => List.unmodifiable(
      store.issues.where(_canSee).map(_toDetails));

  @override
  Future<IssueDetails?> getIssueDetails(String issueId) async {
    final issue = store.issue(issueId);
    if (issue == null || !_canSee(issue)) return null; // Không lộ dữ liệu.
    return _toDetails(issue);
  }

  @override
  Future<List<IssueEventItem>> getTimeline(String issueId) async {
    if (await getIssueDetails(issueId) == null) return const [];
    final events = [...store.issueEvents(issueId)]..sort((a, b) {
        final byTime = a.serverAt.compareTo(b.serverAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return List.unmodifiable(events);
  }

  IssueDetails _toDetails(Issue issue) {
    final txn = store.transaction(issue.transactionId)!;
    final parties = issueAffectedParties(store, issue);
    // Bên đối diện người báo: bên đầu tiên khác người báo trong các bên bị ảnh hưởng.
    final counterpartyId = parties.firstWhere(
      (id) => id != issue.reporterId,
      orElse: () => issue.reporterId,
    );
    final proposal = store.issueProposal(issue.id);

    return IssueDetails(
      issue: issue,
      materialTitle: store.material(txn.materialId)?.title ?? 'Tài liệu',
      reporterDisplayName: _name(issue.reporterId),
      counterpartyDisplayName: _name(counterpartyId),
      relation: issue.reporterId == demoViewerId
          ? IssueRelation.reporter
          : IssueRelation.counterparty,
      proposal: proposal == null ? null : _toProposal(parties, proposal),
      // Bằng chứng thuộc EvidenceRepository (module Handover); mock chưa có ảnh.
      canViewTransaction: canViewIssueTransaction(txn, demoViewerId),
      allowedActions: _allowedActions(issue, proposal),
    );
  }

  // Mỗi bên bị ảnh hưởng trực tiếp một dòng xác nhận (xem mock_issue_access.dart).
  IssueResolutionProposal _toProposal(
      List<String> parties, MockIssueProposal proposal) {
    return IssueResolutionProposal(
      revision: proposal.revision,
      summary: proposal.summary,
      proposedByDisplayName: _name(proposal.proposedBy),
      proposedAt: proposal.proposedAt,
      consents: [
        for (final userId in parties)
          IssueConsent(
            participantDisplayName: _name(userId),
            approvedAt: proposal.approvals[userId],
          ),
      ],
    );
  }

  Set<IssueAction> _allowedActions(Issue issue, MockIssueProposal? proposal) {
    // Chỉ bên bị ảnh hưởng trực tiếp mới được thao tác; bên chỉ đọc thì không.
    if (!issue.isOpen || !canActOnIssue(store, issue, demoViewerId)) {
      return const {};
    }
    return Set.unmodifiable({
      IssueAction.proposeResolution,
      if (proposal != null && !proposal.approvals.containsKey(demoViewerId))
        IssueAction.confirmResolution,
    });
  }

  static String _name(String userId) =>
      MockFixtures.displayNames[userId] ?? 'Người dùng';
}
