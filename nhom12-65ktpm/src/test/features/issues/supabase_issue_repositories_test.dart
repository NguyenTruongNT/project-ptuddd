import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/issue.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/features/issues/data/supabase_issue_repositories.dart';
import 'package:studyshare/features/transactions/data/supabase_rpc_gateway.dart';

// JSON mẫu theo dạng RPC Supabase dev trả về; chỉ dùng ID/tên giả.
Map<String, dynamic> _issueJson() => {
  'issue': {
    'id': 'issue-1',
    'type': 'DELIVERY_FAILED',
    'reason': 'Sách bị ướt.',
    'status': 'OPEN',
    'openedAt': '2026-11-24T03:00:00+00:00',
    'handoverId': 'handover-1',
    'reporterId': 'user-a',
    'resolvedAt': null,
    'transactionId': 'txn-1',
  },
  'proposal': {
    'summary': 'Hai bên đối chiếu và tiếp tục.',
    'consents': [
      {
        'approvedAt': '2026-11-24T04:30:00+00:00',
        'participantDisplayName': 'Người B',
      },
      {'approvedAt': null, 'participantDisplayName': 'Người A'},
    ],
    'revision': 2,
    'proposedAt': '2026-11-24T04:00:00+00:00',
    'proposedByDisplayName': 'Người B',
  },
  'relation': 'COUNTERPARTY',
  'evidenceCount': 0,
  'materialTitle': 'Đại số tuyến tính',
  'allowedActions': ['CAN_CONFIRM_ISSUE_RESOLUTION'],
  'canViewEvidence': false,
  'canViewTransaction': false,
  'reporterDisplayName': 'Người A',
  'counterpartyDisplayName': 'Người B',
};

void main() {
  late List<(String, Map<String, dynamic>)> calls;
  late Object? Function(String, Map<String, dynamic>) respond;

  SupabaseRpcGateway gateway() => SupabaseRpcGateway(
    invoke: (function, params) async {
      calls.add((function, params));
      return respond(function, params);
    },
    sessionValid: () => true,
  );

  setUp(() {
    calls = [];
    respond = (_, _) => null;
  });

  test('parse Issue, phương án theo revision và xác nhận từng bên', () {
    final details = parseIssueDetails(_issueJson());
    expect(details.issue.type, IssueType.deliveryFailed);
    expect(details.issue.status, IssueStatus.open);
    expect(details.relation, IssueRelation.counterparty);
    expect(details.proposal!.revision, 2);
    expect(details.proposal!.approvedCount, 1);
    expect(details.proposal!.isFullyApproved, isFalse);
    expect(details.canViewTransaction, isFalse);
    expect(details.can(IssueAction.confirmResolution), isTrue);
  });

  test('truy vấn gọi đúng RPC; null/rỗng khi không có quyền', () async {
    respond = (function, _) => switch (function) {
      'get_my_issues' => [_issueJson()],
      'get_issue_timeline' => <Object?>[],
      _ => null,
    };
    final repo = SupabaseIssueQueryRepository(gateway());
    expect(await repo.getMyIssues(), hasLength(1));
    expect(await repo.getIssueDetails('issue-hidden'), isNull);
    expect(await repo.getTimeline('issue-hidden'), isEmpty);
    expect(calls[1].$2, {'p_issue_id': 'issue-hidden'});
  });

  test('báo sự cố gửi loại theo wire và handover tùy chọn', () async {
    respond = (_, _) => {
      'ok': true,
      'data': _issueJson(),
      'event_id': 'event-1',
    };
    final repo = SupabaseIssueRepository(gateway());
    final result = await repo.reportIssue(
      const CreateIssueInput(
        transactionId: 'txn-1',
        type: IssueType.wrongCondition,
        reason: '  Bìa rách  ',
      ),
      idempotencyKey: 'k1',
    );
    expect(result, isA<CommandOk<IssueDetails>>());
    expect(calls.single.$1, 'report_issue');
    expect(calls.single.$2, {
      'p_transaction_id': 'txn-1',
      'p_issue_type': 'WRONG_CONDITION',
      'p_reason': 'Bìa rách',
      'p_handover_id': null,
      'p_idempotency_key': 'k1',
    });
  });

  test('xác nhận sai revision trả CONFLICT từ server', () async {
    respond = (_, _) => {
      'ok': false,
      'code': 'CONFLICT',
      'message': 'Phương án đã thay đổi. Hãy xem lại bản mới nhất.',
    };
    final repo = SupabaseIssueRepository(gateway());
    final result = await repo.confirmResolution(
      'issue-1',
      1,
      idempotencyKey: 'k2',
    );
    expect((result as CommandError).code, DomainErrorCode.conflict);
    expect(calls.single.$1, 'confirm_issue_resolution');
    expect(calls.single.$2['p_resolution_revision'], 1);
  });

  test('đề xuất phương án gọi propose_issue_resolution', () async {
    respond = (_, _) => {
      'ok': true,
      'data': _issueJson(),
      'event_id': 'event-2',
    };
    final repo = SupabaseIssueRepository(gateway());
    final result = await repo.proposeResolution(
      'issue-1',
      'Đổi sách',
      idempotencyKey: 'k3',
    );
    expect((result as CommandOk).serverEventId, 'event-2');
    expect(calls.single.$2, {
      'p_issue_id': 'issue-1',
      'p_summary': 'Đổi sách',
      'p_idempotency_key': 'k3',
    });
  });
}
