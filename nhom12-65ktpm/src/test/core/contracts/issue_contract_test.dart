import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/issue.dart';

IssueDetails _details({
  IssueStatus status = IssueStatus.open,
  Set<IssueAction> actions = const {},
  IssueResolutionProposal? proposal,
}) =>
    IssueDetails(
      issue: Issue(
        id: 'issue-x',
        transactionId: 'txn-x',
        reporterId: 'b',
        type: IssueType.wrongMaterial,
        reason: 'Sách không đúng tên môn.',
        status: status,
        openedAt: DateTime.utc(2026, 11, 22),
      ),
      materialTitle: 'Giáo trình',
      reporterDisplayName: 'B',
      counterpartyDisplayName: 'A',
      relation: IssueRelation.reporter,
      proposal: proposal,
      allowedActions: actions,
    );

void main() {
  test('IssueType đọc đúng mã server và từ chối mã lạ', () {
    for (final type in IssueType.values) {
      expect(IssueType.fromWire(type.wire), type);
    }
    expect(IssueType.wrongMaterial.wire, 'WRONG_MATERIAL');
    expect(() => IssueType.fromWire('FORCE_CLOSE'), throwsFormatException);
  });

  test('IssueAction đọc đúng mã server và từ chối mã lạ', () {
    for (final action in IssueAction.values) {
      expect(IssueAction.fromWire(action.wire), action);
    }
    expect(IssueAction.confirmResolution.wire, 'CAN_CONFIRM_ISSUE_RESOLUTION');
    expect(() => IssueAction.fromWire('CAN_FORCE_CLOSE'), throwsFormatException);
  });

  test('Issue.isOpen chỉ đúng khi status là OPEN', () {
    expect(_details().issue.isOpen, isTrue);
    expect(_details(status: IssueStatus.resolved).issue.isOpen, isFalse);
  });

  test('IssueDetails.can chỉ phản ánh gợi ý server trả về', () {
    final details = _details(actions: const {IssueAction.proposeResolution});
    expect(details.id, 'issue-x');
    expect(details.can(IssueAction.proposeResolution), isTrue);
    expect(details.can(IssueAction.confirmResolution), isFalse);
  });

  test('IssueDetails mặc định cho xem giao dịch và không có action nào', () {
    final details = _details();
    expect(details.canViewTransaction, isTrue);
    expect(details.allowedActions, isEmpty);
    expect(details.canViewEvidence, isFalse);
    expect(details.evidenceCount, 0);
  });

  test('IssueResolutionProposal đếm đủ xác nhận khi mọi bên đã đồng ý', () {
    final proposal = IssueResolutionProposal(
      revision: 2,
      summary: 'A đổi sách đúng môn.',
      proposedByDisplayName: 'A',
      proposedAt: DateTime.utc(2026, 11, 23),
      consents: [
        IssueConsent(
            participantDisplayName: 'A', approvedAt: DateTime.utc(2026, 11, 23)),
        const IssueConsent(participantDisplayName: 'B'),
      ],
    );
    expect(proposal.approvedCount, 1);
    expect(proposal.isFullyApproved, isFalse);

    final done = IssueResolutionProposal(
      revision: 2,
      summary: proposal.summary,
      proposedByDisplayName: 'A',
      proposedAt: proposal.proposedAt,
      consents: [
        IssueConsent(
            participantDisplayName: 'A', approvedAt: DateTime.utc(2026, 11, 23)),
        IssueConsent(
            participantDisplayName: 'B', approvedAt: DateTime.utc(2026, 11, 24)),
      ],
    );
    expect(done.isFullyApproved, isTrue);
  });
}
