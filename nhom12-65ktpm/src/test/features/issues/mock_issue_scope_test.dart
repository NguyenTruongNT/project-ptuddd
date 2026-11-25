import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/issue.dart';
import 'package:studyshare/core/contracts/models/handover.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/core/mock/mock_issue_query_repository.dart';
import 'package:studyshare/core/mock/mock_transaction_store.dart';
import 'package:studyshare/core/providers/mock_query_providers.dart';
import 'package:studyshare/features/issues/data/mock_issue_command_runner.dart';
import 'package:studyshare/features/issues/data/mock_issue_repository.dart';

// Phạm vi người liên quan của Issue (SS-BR §9.3, CONTRACTS.md §8):
// - A/B của giao dịch luôn ĐỌC được Issue của giao dịch;
// - C chỉ liên quan khi là một đầu của chặng (handover) mà Issue gắn vào;
// - Chỉ các bên bị ảnh hưởng trực tiếp mới đề xuất/xác nhận phương án.
const _delivery = 'txn-delivery-01'; // A -> B, có giao hộ qua C.
const _hAtoC = 'handover-a-to-c'; // Chặng đi: A giao cho C.
const _hCtoB = 'handover-c-to-b'; // Chặng cuối: C giao cho B.
const _hDirect = 'handover-direct'; // A giao thẳng cho B, không qua C.

const _a = MockFixtures.userA;
const _b = MockFixtures.userB;
const _c = MockFixtures.userC;
const _outsider = MockFixtures.outsider;

List<Handover> _handovers() => [
      ...MockFixtures.handovers,
      const Handover(
          id: _hAtoC, transactionId: _delivery, fromUserId: _a, toUserId: _c,
          status: HandoverStatus.confirmed),
      const Handover(
          id: _hCtoB, transactionId: _delivery, fromUserId: _c, toUserId: _b,
          status: HandoverStatus.disputed),
      const Handover(
          id: _hDirect, transactionId: _delivery, fromUserId: _a, toUserId: _b,
          status: HandoverStatus.confirmed),
    ];

class _World {
  _World({List<Issue>? seedIssues})
      : store = MockTransactionStore.fromFixtures(
          clock: () => DateTime.utc(2026, 11, 23, 3),
          seedIssues: seedIssues,
          seedHandovers: _handovers(),
        );

  final MockTransactionStore store;

  MockIssueRepository repo(String actor) => MockIssueRepository(
      MockIssueCommandRunner(store: store, actorId: actor));

  MockIssueQueryRepository query(String actor) =>
      MockIssueQueryRepository(demoViewerId: actor, store: store);

  Future<IssueDetails> report(
    String actor, {
    String txn = _delivery,
    String? handoverId,
    String key = 'k',
  }) async =>
      expectOk(await repo(actor).reportIssue(
        CreateIssueInput(
            transactionId: txn,
            type: IssueType.deliveryFailed,
            reason: 'Giao không thành công.',
            handoverId: handoverId),
        idempotencyKey: key,
      ));
}

IssueDetails expectOk(CommandResult<IssueDetails> result) {
  expect(result, isA<CommandOk<IssueDetails>>(),
      reason: result is CommandError<IssueDetails> ? result.safeMessage : null);
  return (result as CommandOk<IssueDetails>).data;
}

void expectError(CommandResult<IssueDetails> result, DomainErrorCode code) {
  expect(result, isA<CommandError<IssueDetails>>(),
      reason: result is CommandOk<IssueDetails> ? 'đáng lẽ phải lỗi' : null);
  expect((result as CommandError<IssueDetails>).code, code);
}

void main() {
  group('Phạm vi đọc theo Issue/chặng', () {
    test('C là một đầu của chặng: đọc được Issue của chặng đó, không thấy giao dịch',
        () async {
      final world = _World();
      final issue = await world.report(_b, handoverId: _hCtoB);

      final seenByC = (await world.query(_c).getIssueDetails(issue.id))!;
      expect(seenByC.relation, IssueRelation.counterparty);
      expect(seenByC.materialTitle, 'Mạng máy tính');
      // C không được xem toàn bộ giao dịch nên không có đường dẫn sang SCR-14.
      expect(seenByC.canViewTransaction, isFalse);
      expect((await world.query(_c).getMyIssues()).map((i) => i.id), [issue.id]);
      expect((await world.query(_c).getTimeline(issue.id)), isNotEmpty);
      // A/B vẫn thấy và được mở giao dịch.
      expect((await world.query(_a).getIssueDetails(issue.id))!.canViewTransaction,
          isTrue);
    });

    test('Issue của chặng không có C (giao thẳng A->B): C không thấy gì', () async {
      final world = _World();
      final issue = await world.report(_b, handoverId: _hDirect);

      expect(await world.query(_c).getIssueDetails(issue.id), isNull);
      expect(await world.query(_c).getMyIssues(), isEmpty);
      expect(await world.query(_c).getTimeline(issue.id), isEmpty);
      expect(await world.query(_a).getIssueDetails(issue.id), isNotNull);
    });

    test('Issue cấp giao dịch (không gắn chặng): C không thấy dù đang giao hộ',
        () async {
      final world = _World();
      final issue = await world.report(_b);

      expect(await world.query(_c).getIssueDetails(issue.id), isNull);
      expect(await world.query(_c).getMyIssues(), isEmpty);
    });

    test('Người ngoài không đọc được Issue nào, kể cả Issue có gắn chặng', () async {
      final world = _World();
      final txnLevel = await world.report(_b, key: 'k1');
      final legLevel = await world.report(_b, handoverId: _hCtoB, key: 'k2');

      for (final id in [txnLevel.id, legLevel.id, 'khong-co']) {
        expect(await world.query(_outsider).getIssueDetails(id), isNull);
        expect(await world.query(_outsider).getTimeline(id), isEmpty);
      }
      expect(await world.query(_outsider).getMyIssues(), isEmpty);
    });
  });

  group('Bên bị ảnh hưởng trực tiếp (consent)', () {
    test('Chặng C->B: consent là C và B, không bắt A xác nhận', () async {
      final world = _World();
      final issue = await world.report(_b, handoverId: _hCtoB);

      final proposed = expectOk(await world.repo(_c).proposeResolution(
          issue.id, 'C giao lại sách cho B.', idempotencyKey: 'p1'));
      expect(proposed.proposal!.consents.map((c) => c.participantDisplayName),
          unorderedEquals(['Bạn C (demo)', 'Bạn B (demo)']));

      expectOk(await world.repo(_c).confirmResolution(issue.id, 1, idempotencyKey: 'c1'));
      final done = expectOk(
          await world.repo(_b).confirmResolution(issue.id, 1, idempotencyKey: 'c2'));
      // A chưa hề xác nhận nhưng Issue vẫn RESOLVED vì A không bị ảnh hưởng trực tiếp.
      expect(done.issue.status, IssueStatus.resolved);
      expect(world.store.issueProposal(issue.id)!.approvals.containsKey(_a), isFalse);
      expect(world.store.openIssueCount(_delivery), 0);
    });

    test('Chặng A->C do C báo (từ chối nhận): consent là A và C, B chỉ đọc', () async {
      final world = _World();
      final issue = await world.report(_c, handoverId: _hAtoC);
      expect(issue.relation, IssueRelation.reporter);

      final proposed = expectOk(await world.repo(_a).proposeResolution(
          issue.id, 'A chụp lại tình trạng sách.', idempotencyKey: 'p1'));
      expect(proposed.proposal!.consents.map((c) => c.participantDisplayName),
          unorderedEquals(['Bạn A (demo)', 'Bạn C (demo)']));

      // B là người nhận cuối nên đọc được, nhưng không phải bên bị ảnh hưởng.
      final seenByB = (await world.query(_b).getIssueDetails(issue.id))!;
      expect(seenByB.allowedActions, isEmpty);
      expectError(
          await world.repo(_b).confirmResolution(issue.id, 1, idempotencyKey: 'c0'),
          DomainErrorCode.forbidden);

      expectOk(await world.repo(_a).confirmResolution(issue.id, 1, idempotencyKey: 'c1'));
      expect((await world.query(_a).getIssueDetails(issue.id))!.issue.isOpen, isTrue);
      final done = expectOk(
          await world.repo(_c).confirmResolution(issue.id, 1, idempotencyKey: 'c2'));
      expect(done.issue.status, IssueStatus.resolved);
      expect(done.allowedActions, isEmpty); // RESOLVED không còn thao tác.
    });

    test('Issue cấp giao dịch: consent vẫn là A và B', () async {
      final world = _World();
      final issue = await world.report(_b);
      final proposed = expectOk(await world.repo(_a).proposeResolution(
          issue.id, 'Hai bên gặp nhau.', idempotencyKey: 'p1'));
      expect(proposed.proposal!.consents.map((c) => c.participantDisplayName),
          unorderedEquals(['Bạn A (demo)', 'Bạn B (demo)']));
    });

    test('Người báo luôn là bên bị ảnh hưởng, kể cả khi không thuộc chặng', () async {
      final world = _World();
      // A báo về chặng C->B mà A không tham gia.
      final issue = await world.report(_a, handoverId: _hCtoB);
      final proposed = expectOk(await world.repo(_b).proposeResolution(
          issue.id, 'C giao lại.', idempotencyKey: 'p1'));
      expect(proposed.proposal!.consents.length, 3);
      expect(issue.allowedActions, contains(IssueAction.proposeResolution));
    });
  });

  group('Quyền ghi theo chặng', () {
    test('C báo được Issue của chặng mình tham gia', () async {
      final world = _World();
      final issue = await world.report(_c, handoverId: _hCtoB);
      expect(issue.issue.reporterId, _c);
      expect(issue.issue.handoverId, _hCtoB);
      expect(world.store.openIssueCount(_delivery), 1);
    });

    test('C không báo được: không gắn chặng, chặng không có C, hoặc chặng giao dịch khác',
        () async {
      final world = _World();
      for (final (i, handoverId) in <String?>[
        null,
        _hDirect,
        'handover-borrow-01', // Thuộc giao dịch khác.
        'handover-khong-co',
      ].indexed) {
        expectError(
            await world.repo(_c).reportIssue(
                CreateIssueInput(
                    transactionId: _delivery,
                    type: IssueType.other,
                    reason: 'Thử.',
                    handoverId: handoverId),
                idempotencyKey: 'k$i'),
            DomainErrorCode.forbidden);
      }
      expect(world.store.issues, isEmpty);
    });

    test('C không đề xuất/xác nhận Issue không thuộc chặng của mình', () async {
      final world = _World();
      final issue = await world.report(_b, handoverId: _hDirect);
      expectError(
          await world.repo(_c).proposeResolution(issue.id, 'x', idempotencyKey: 'p1'),
          DomainErrorCode.forbidden);
      expectError(
          await world.repo(_c).confirmResolution(issue.id, 1, idempotencyKey: 'c1'),
          DomainErrorCode.forbidden);
    });

    test('Người ngoài bị từ chối mọi lệnh Issue', () async {
      final world = _World();
      final issue = await world.report(_b, handoverId: _hCtoB);
      expectError(
          await world.repo(_outsider).reportIssue(
              const CreateIssueInput(
                  transactionId: _delivery,
                  type: IssueType.other,
                  reason: 'Thử.',
                  handoverId: _hCtoB),
              idempotencyKey: 'k1'),
          DomainErrorCode.forbidden);
      expectError(
          await world.repo(_outsider)
              .proposeResolution(issue.id, 'x', idempotencyKey: 'p1'),
          DomainErrorCode.forbidden);
    });
  });

  group('ID Issue không ghi đè Issue seed', () {
    test('Seed issue-mock-1 rồi tạo Issue mới: cả hai cùng tồn tại, nội dung cũ giữ nguyên',
        () async {
      final seeded = Issue(
        id: 'issue-mock-1',
        transactionId: 'txn-borrow-01',
        reporterId: _b,
        type: IssueType.wrongCondition,
        reason: 'Bìa sách bị rách.',
        status: IssueStatus.open,
        openedAt: DateTime.utc(2026, 11, 22),
      );
      final world = _World(seedIssues: [seeded]);
      // Phương án + xác nhận + sự kiện của Issue seed phải còn nguyên.
      world.store.putIssueProposal(
        'issue-mock-1',
        MockIssueProposal(
          revision: 3,
          summary: 'A đổi bản khác.',
          proposedBy: _a,
          proposedAt: DateTime.utc(2026, 11, 22, 5),
          approvals: {_a: DateTime.utc(2026, 11, 22, 6)},
        ),
      );
      world.store.appendIssueEvent(
          issueId: 'issue-mock-1',
          eventType: 'ISSUE_OPENED',
          safeDescription: 'Sự cố được mở.');

      final created = await world.report(_b, txn: 'txn-sell-01', key: 'k1');

      expect(created.id, isNot('issue-mock-1'));
      expect(world.store.issues.length, 2);
      final old = world.store.issue('issue-mock-1')!;
      expect(old.reason, 'Bìa sách bị rách.');
      expect(old.transactionId, 'txn-borrow-01');
      expect(world.store.issueProposal('issue-mock-1')!.revision, 3);
      expect(world.store.issueProposal('issue-mock-1')!.approvals.keys, [_a]);
      expect(world.store.issueEvents('issue-mock-1').length, 1);
      // Issue mới có timeline riêng, không lẫn vào Issue cũ.
      expect(world.store.issueEvents(created.id).length, 1);
    });

    test('Tạo nhiều Issue liên tiếp luôn cho ID khác nhau', () async {
      final world = _World();
      final ids = <String>{};
      for (var i = 0; i < 5; i++) {
        ids.add((await world.report(_b, key: 'k$i')).id);
      }
      expect(ids.length, 5);
      expect(world.store.issues.length, 5);
    });
  });

  group('Provider đọc Issue', () {
    test('C chỉ thấy Issue chặng của mình; giao dịch không lộ openIssueCount cho C',
        () async {
      final world = _World();
      await world.report(_b, handoverId: _hCtoB, key: 'k1');
      await world.report(_b, handoverId: _hDirect, key: 'k2');

      final container = ProviderContainer(overrides: [
        demoViewerIdProvider.overrideWith((ref) => _c),
        mockTransactionStoreProvider.overrideWith((ref) => world.store),
      ]);
      addTearDown(container.dispose);

      final issues = await container.read(issueQueryRepositoryProvider).getMyIssues();
      expect(issues.length, 1);
      expect(issues.single.issue.handoverId, _hCtoB);
      // C vẫn không đọc được giao dịch dù thấy Issue của chặng.
      expect(await container.read(myTransactionsPreviewProvider.future), isEmpty);
    });
  });
}
