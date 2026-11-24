import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/issue.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/core/mock/mock_issue_query_repository.dart';
import 'package:studyshare/core/mock/mock_transaction_store.dart';
import 'package:studyshare/features/issues/data/mock_issue_command_runner.dart';
import 'package:studyshare/features/issues/data/mock_issue_repository.dart';
import 'package:studyshare/features/transactions/data/mock_command_runner.dart';
import 'package:studyshare/features/transactions/data/mock_transaction_cancellation_repository.dart';

const _borrow = 'txn-borrow-01';
const _sell = 'txn-sell-01';

// Một "server" mock dùng chung cho các actor; đồng hồ chỉnh được để thử hạn 7 ngày.
class _World {
  DateTime now = DateTime.utc(2026, 11, 22, 3);
  late final store = MockTransactionStore.fromFixtures(clock: () => now);

  MockIssueRepository repo(String actor) => MockIssueRepository(
      MockIssueCommandRunner(store: store, actorId: actor));

  MockIssueQueryRepository query(String actor) =>
      MockIssueQueryRepository(demoViewerId: actor, store: store);

  MockTransactionCancellationRepository cancel(String actor) =>
      MockTransactionCancellationRepository(
          MockCommandRunner(store: store, actorId: actor));
}

CreateIssueInput _input({
  String transactionId = _borrow,
  String reason = 'Sách bị rách bìa.',
  String? handoverId,
}) =>
    CreateIssueInput(
      transactionId: transactionId,
      type: IssueType.wrongCondition,
      reason: reason,
      handoverId: handoverId,
    );

void expectError(CommandResult<IssueDetails> result, DomainErrorCode code) {
  expect(result, isA<CommandError<IssueDetails>>(),
      reason: result is CommandOk<IssueDetails> ? 'đáng lẽ phải lỗi' : null);
  expect((result as CommandError<IssueDetails>).code, code);
}

IssueDetails expectOk(CommandResult<IssueDetails> result) {
  expect(result, isA<CommandOk<IssueDetails>>(),
      reason: result is CommandError<IssueDetails> ? result.safeMessage : null);
  return (result as CommandOk<IssueDetails>).data;
}

void main() {
  const a = MockFixtures.userA;
  const b = MockFixtures.userB;

  group('reportIssue', () {
    test('B báo sự cố: Issue OPEN, giao dịch hiện nhãn cần giải quyết', () async {
      final world = _World();
      final details = expectOk(
          await world.repo(b).reportIssue(_input(), idempotencyKey: 'k1'));

      expect(details.issue.status, IssueStatus.open);
      expect(details.issue.reporterId, b);
      expect(details.issue.transactionId, _borrow);
      expect(details.relation, IssueRelation.reporter);
      expect(world.store.openIssueCount(_borrow), 1);
      // Bên còn lại cũng thấy Issue, với vai trò counterparty.
      final seenByA = (await world.query(a).getIssueDetails(details.id))!;
      expect(seenByA.relation, IssueRelation.counterparty);
    });

    test('Không đổi owner, holder, trạng thái giao dịch (INV-10)', () async {
      final world = _World();
      final txnBefore = world.store.transaction(_borrow)!;
      final holderBefore = world.store.material(txnBefore.materialId)!.holderId;

      expectOk(await world.repo(b).reportIssue(_input(), idempotencyKey: 'k1'));

      final txnAfter = world.store.transaction(_borrow)!;
      expect(txnAfter.status, txnBefore.status);
      expect(txnAfter.ownerAtAcceptance, txnBefore.ownerAtAcceptance);
      expect(world.store.material(txnAfter.materialId)!.holderId, holderBefore);
    });

    test('Ghi sự kiện ISSUE_OPENED vào timeline giao dịch và Issue', () async {
      final world = _World();
      final txnEvents = world.store.events(_borrow).length;
      final result =
          await world.repo(b).reportIssue(_input(), idempotencyKey: 'k1');
      final details = expectOk(result);

      expect(world.store.events(_borrow).length, txnEvents + 1);
      expect(world.store.events(_borrow).last.eventType, 'ISSUE_OPENED');
      final timeline = await world.query(b).getTimeline(details.id);
      expect(timeline.map((e) => e.eventType), ['ISSUE_OPENED']);
      // ACK trả về event ID của sự kiện server vừa ghi.
      expect((result as CommandOk<IssueDetails>).serverEventId,
          world.store.events(_borrow).last.id);
    });

    test('C và người ngoài bị từ chối, không tạo Issue', () async {
      final world = _World();
      for (final actor in [MockFixtures.userC, MockFixtures.outsider]) {
        expectError(
            await world.repo(actor).reportIssue(_input(), idempotencyKey: 'k-$actor'),
            DomainErrorCode.forbidden);
      }
      // Giao dịch không tồn tại cho cùng lỗi, không lộ thông tin.
      expectError(
          await world.repo(b).reportIssue(
              _input(transactionId: 'txn-khong-co'), idempotencyKey: 'k2'),
          DomainErrorCode.forbidden);
      expect(world.store.issues, isEmpty);
    });

    test('Lý do rỗng hoặc thiếu mã thao tác là đầu vào không hợp lệ', () async {
      final world = _World();
      expectError(
          await world.repo(b).reportIssue(_input(reason: '   '), idempotencyKey: 'k1'),
          DomainErrorCode.invalidInput);
      expectError(
          await world.repo(b).reportIssue(_input(), idempotencyKey: ' '),
          DomainErrorCode.invalidInput);
      expect(world.store.issues, isEmpty);
    });

    test('handoverId phải thuộc đúng giao dịch', () async {
      final world = _World();
      expectError(
          await world.repo(b).reportIssue(
              _input(handoverId: 'handover-khong-co'), idempotencyKey: 'k1'),
          DomainErrorCode.invalidInput);
      final ok = expectOk(await world.repo(b).reportIssue(
          _input(handoverId: 'handover-borrow-01'), idempotencyKey: 'k2'));
      expect(ok.issue.handoverId, 'handover-borrow-01');
    });

    test('Giao dịch đã hủy không nhận Issue', () async {
      final world = _World();
      world.store.setStatus(_borrow, TransactionStatus.cancelled);
      expectError(await world.repo(b).reportIssue(_input(), idempotencyKey: 'k1'),
          DomainErrorCode.invalidTransactionTransition);
    });

    test('Sau COMPLETED chỉ báo được trong 7 ngày lịch Việt Nam', () async {
      final world = _World();
      // Hoàn tất ngày 22/11 (giờ VN); hạn khởi tạo là hết ngày 29/11.
      world.store.appendEvent(
          transactionId: _borrow,
          eventType: 'TRANSACTION_COMPLETED',
          safeDescription: 'Hoàn tất.');
      world.store.setStatus(_borrow, TransactionStatus.completed);

      world.now = DateTime.utc(2026, 11, 29, 16, 59); // 23:59 ngày 29/11 giờ VN
      expectOk(await world.repo(b).reportIssue(_input(), idempotencyKey: 'k1'));

      world.now = DateTime.utc(2026, 11, 29, 17, 0); // 00:00 ngày 30/11 giờ VN
      expectError(await world.repo(b).reportIssue(_input(), idempotencyKey: 'k2'),
          DomainErrorCode.invalidTransactionTransition);
    });

    test('Retry cùng key không tạo Issue thứ hai; khác nội dung thì CONFLICT',
        () async {
      final world = _World();
      final first =
          expectOk(await world.repo(b).reportIssue(_input(), idempotencyKey: 'k1'));
      final events = world.store.events(_borrow).length;

      final retry =
          expectOk(await world.repo(b).reportIssue(_input(), idempotencyKey: 'k1'));
      expect(retry.id, first.id);
      expect(world.store.issues.length, 1);
      expect(world.store.events(_borrow).length, events);

      expectError(
          await world.repo(b).reportIssue(
              _input(reason: 'Nội dung khác'), idempotencyKey: 'k1'),
          DomainErrorCode.conflict);
    });

    test('Issue đang mở chặn đồng ý hủy giao dịch', () async {
      final world = _World();
      expectOk(await world.repo(b).reportIssue(_input(), idempotencyKey: 'k1'));
      await world.cancel(a).proposeCancellation(_borrow, 'Không cần nữa',
          idempotencyKey: 'c1');
      final accepted =
          await world.cancel(b).acceptCancellation(_borrow, idempotencyKey: 'c2');
      expect(accepted, isA<CommandError>());
      expect((accepted as CommandError).code, DomainErrorCode.issueBlockingAction);
    });
  });

  group('proposeResolution', () {
    Future<(_World, String)> open() async {
      final world = _World();
      final issue =
          expectOk(await world.repo(b).reportIssue(_input(), idempotencyKey: 'k1'));
      return (world, issue.id);
    }

    test('Đề xuất tạo revision 1; người đề xuất chưa tự được tính là đã xác nhận',
        () async {
      final (world, id) = await open();
      final details = expectOk(await world.repo(a).proposeResolution(
          id, 'A đổi bản sách khác.', idempotencyKey: 'p1'));

      final proposal = details.proposal!;
      expect(proposal.revision, 1);
      expect(proposal.summary, 'A đổi bản sách khác.');
      expect(proposal.consents.length, 2);
      expect(proposal.approvedCount, 0);
      expect(details.issue.status, IssueStatus.open);
    });

    test('Đề xuất mới tăng revision và xóa xác nhận cũ', () async {
      final (world, id) = await open();
      expectOk(await world.repo(a).proposeResolution(id, 'Phương án 1',
          idempotencyKey: 'p1'));
      expectOk(await world.repo(b).confirmResolution(id, 1, idempotencyKey: 'c1'));

      final again = expectOk(await world.repo(b).proposeResolution(
          id, 'Phương án 2', idempotencyKey: 'p2'));
      expect(again.proposal!.revision, 2);
      expect(again.proposal!.approvedCount, 0);
    });

    test('Người ngoài, Issue đã giải quyết và nội dung rỗng bị từ chối', () async {
      final (world, id) = await open();
      expectError(
          await world.repo(MockFixtures.outsider)
              .proposeResolution(id, 'x', idempotencyKey: 'p0'),
          DomainErrorCode.forbidden);
      expectError(
          await world.repo(a).proposeResolution(id, '  ', idempotencyKey: 'p1'),
          DomainErrorCode.invalidInput);

      expectOk(await world.repo(a).proposeResolution(id, 'OK', idempotencyKey: 'p2'));
      expectOk(await world.repo(a).confirmResolution(id, 1, idempotencyKey: 'c1'));
      expectOk(await world.repo(b).confirmResolution(id, 1, idempotencyKey: 'c2'));
      expectError(
          await world.repo(a).proposeResolution(id, 'Muộn', idempotencyKey: 'p3'),
          DomainErrorCode.invalidTransactionTransition);
    });
  });

  group('confirmResolution', () {
    test('Chỉ khi cả A và B xác nhận mới RESOLVED, không đổi giao dịch', () async {
      final world = _World();
      final id = expectOk(
              await world.repo(b).reportIssue(_input(), idempotencyKey: 'k1'))
          .id;
      expectOk(await world.repo(a).proposeResolution(id, 'Đổi sách',
          idempotencyKey: 'p1'));
      final txnBefore = world.store.transaction(_borrow)!;

      final afterA = expectOk(
          await world.repo(a).confirmResolution(id, 1, idempotencyKey: 'c1'));
      expect(afterA.issue.status, IssueStatus.open);
      expect(afterA.proposal!.approvedCount, 1);
      expect(world.store.openIssueCount(_borrow), 1);

      world.now = DateTime.utc(2026, 11, 23, 5);
      final afterB = expectOk(
          await world.repo(b).confirmResolution(id, 1, idempotencyKey: 'c2'));
      expect(afterB.issue.status, IssueStatus.resolved);
      expect(afterB.issue.resolvedAt, DateTime.utc(2026, 11, 23, 5));
      expect(afterB.allowedActions, isEmpty);
      expect(world.store.openIssueCount(_borrow), 0);

      final txnAfter = world.store.transaction(_borrow)!;
      expect(txnAfter.status, txnBefore.status);
      expect(txnAfter.ownerAtAcceptance, txnBefore.ownerAtAcceptance);
      expect(world.store.events(_borrow).last.eventType, 'ISSUE_RESOLVED');
    });

    test('Sai revision trả CONFLICT, chưa có phương án thì bị từ chối', () async {
      final world = _World();
      final id = expectOk(
              await world.repo(b).reportIssue(_input(), idempotencyKey: 'k1'))
          .id;
      expectError(await world.repo(a).confirmResolution(id, 1, idempotencyKey: 'c0'),
          DomainErrorCode.invalidTransactionTransition);

      expectOk(await world.repo(a).proposeResolution(id, 'P1', idempotencyKey: 'p1'));
      expectOk(await world.repo(a).proposeResolution(id, 'P2', idempotencyKey: 'p2'));
      // B còn nhìn thấy revision 1 trên màn hình cũ.
      expectError(await world.repo(b).confirmResolution(id, 1, idempotencyKey: 'c1'),
          DomainErrorCode.conflict);
      expect(world.store.issue(id)!.status, IssueStatus.open);
    });

    test('Một người không xác nhận hai lần; người ngoài không xác nhận được',
        () async {
      final world = _World();
      final id = expectOk(
              await world.repo(b).reportIssue(_input(), idempotencyKey: 'k1'))
          .id;
      expectOk(await world.repo(a).proposeResolution(id, 'P1', idempotencyKey: 'p1'));
      expectOk(await world.repo(a).confirmResolution(id, 1, idempotencyKey: 'c1'));
      expectError(await world.repo(a).confirmResolution(id, 1, idempotencyKey: 'c2'),
          DomainErrorCode.invalidTransactionTransition);
      expectError(
          await world.repo(MockFixtures.outsider)
              .confirmResolution(id, 1, idempotencyKey: 'c3'),
          DomainErrorCode.forbidden);
    });

    test('Retry cùng key không ghi sự kiện lần hai', () async {
      final world = _World();
      final id = expectOk(
              await world.repo(b).reportIssue(_input(), idempotencyKey: 'k1'))
          .id;
      expectOk(await world.repo(a).proposeResolution(id, 'P1', idempotencyKey: 'p1'));
      expectOk(await world.repo(a).confirmResolution(id, 1, idempotencyKey: 'c1'));
      final count = world.store.issueEvents(id).length;

      expectOk(await world.repo(a).confirmResolution(id, 1, idempotencyKey: 'c1'));
      expect(world.store.issueEvents(id).length, count);
    });
  });

  group('Repository đọc', () {
    test('Chỉ A/B thấy Issue; người ngoài không thấy gì', () async {
      final world = _World();
      final id = expectOk(
              await world.repo(b).reportIssue(_input(), idempotencyKey: 'k1'))
          .id;

      expect((await world.query(a).getMyIssues()).length, 1);
      expect((await world.query(b).getMyIssues()).length, 1);
      for (final actor in [MockFixtures.userC, MockFixtures.outsider]) {
        expect(await world.query(actor).getMyIssues(), isEmpty);
        expect(await world.query(actor).getIssueDetails(id), isNull);
        expect(await world.query(actor).getTimeline(id), isEmpty);
      }
    });

    test('allowedActions: đề xuất khi mở; xác nhận khi có phương án chưa xác nhận',
        () async {
      final world = _World();
      final id = expectOk(
              await world.repo(b).reportIssue(_input(), idempotencyKey: 'k1'))
          .id;
      var seenByA = (await world.query(a).getIssueDetails(id))!;
      expect(seenByA.can(IssueAction.proposeResolution), isTrue);
      expect(seenByA.can(IssueAction.confirmResolution), isFalse);

      expectOk(await world.repo(a).proposeResolution(id, 'P1', idempotencyKey: 'p1'));
      expectOk(await world.repo(a).confirmResolution(id, 1, idempotencyKey: 'c1'));
      seenByA = (await world.query(a).getIssueDetails(id))!;
      final seenByB = (await world.query(b).getIssueDetails(id))!;
      expect(seenByA.can(IssueAction.confirmResolution), isFalse); // đã xác nhận
      expect(seenByB.can(IssueAction.confirmResolution), isTrue);
    });

    test('Timeline Issue sắp xếp tăng dần theo thời gian server', () async {
      final world = _World();
      final id = expectOk(
              await world.repo(b).reportIssue(_input(), idempotencyKey: 'k1'))
          .id;
      world.now = world.now.add(const Duration(hours: 1));
      expectOk(await world.repo(a).proposeResolution(id, 'P1', idempotencyKey: 'p1'));
      world.now = world.now.add(const Duration(hours: 1));
      expectOk(await world.repo(b).confirmResolution(id, 1, idempotencyKey: 'c1'));

      final events = await world.query(a).getTimeline(id);
      expect(events.map((e) => e.eventType),
          ['ISSUE_OPENED', 'RESOLUTION_PROPOSED', 'RESOLUTION_CONFIRMED']);
    });

    test('SELL cũng nhận Issue (giao sách ngoài hệ thống để đối soát)', () async {
      final world = _World();
      final details = expectOk(await world.repo(a).reportIssue(
          _input(transactionId: _sell, reason: 'Sách đã giao ngoài hệ thống.'),
          idempotencyKey: 'k1'));
      expect(details.relation, IssueRelation.reporter);
      expect(world.store.openIssueCount(_sell), 1);
    });
  });
}
