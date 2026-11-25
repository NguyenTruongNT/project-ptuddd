import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/issue.dart';
import 'package:studyshare/core/contracts/models/transaction.dart';
import 'package:studyshare/core/mock/mock_repositories.dart';

MockTransactionQueryRepository _repo(String viewer) =>
    MockTransactionQueryRepository(demoViewerId: viewer);

void main() {
  group('Quyền xem (SON-T12, SON-E09)', () {
    test('A và B đều thấy 3 giao dịch với đúng vai trò', () async {
      final a = await _repo(MockFixtures.userA).getMyTransactions();
      final b = await _repo(MockFixtures.userB).getMyTransactions();
      expect(a.length, 3);
      expect(b.length, 3);
      expect(a.every((d) => d.viewerRole == TransactionViewerRole.owner), isTrue);
      expect(b.every((d) => d.viewerRole == TransactionViewerRole.receiver), isTrue);
    });

    test('C và người ngoài không đọc được giao dịch hay timeline', () async {
      for (final viewer in [MockFixtures.userC, MockFixtures.outsider]) {
        final repo = _repo(viewer);
        expect(await repo.getMyTransactions(), isEmpty);
        expect(await repo.getTransactionDetails('txn-borrow-01'), isNull);
        expect(await repo.getTimeline('txn-borrow-01'), isEmpty);
      }
    });
  });

  group('Read model', () {
    test('BORROW có BorrowingRecord, không có payment', () async {
      final details =
          (await _repo(MockFixtures.userB).getTransactionDetails('txn-borrow-01'))!;
      expect(details.materialTitle, 'Giáo trình Giải tích');
      expect(details.borrowing?.dueDateVn, '2026-11-28');
      expect(details.payment, isNull);
      expect(details.openIssueCount, 0);
    });

    test('SELL có payment: B đã báo nhưng A chưa xác nhận', () async {
      final details =
          (await _repo(MockFixtures.userA).getTransactionDetails('txn-sell-01'))!;
      expect(details.borrowing, isNull);
      expect(details.payment?.buyerReportedAt, isNotNull);
      expect(details.payment?.isSellerConfirmed, isFalse);
      expect(details.transaction.status, TransactionStatus.awaitingPayment);
    });
  });

  group('allowedActions (gợi ý UI, server vẫn kiểm tra lại)', () {
    test('Chỉ A có gợi ý xác nhận tiền SELL (SON-T07)', () async {
      final a = (await _repo(MockFixtures.userA).getTransactionDetails('txn-sell-01'))!;
      final b = (await _repo(MockFixtures.userB).getTransactionDetails('txn-sell-01'))!;
      expect(a.can(TransactionAction.confirmSellerPayment), isTrue);
      expect(b.can(TransactionAction.confirmSellerPayment), isFalse);
      // B đã báo chuyển khoản rồi nên không gợi ý báo lại.
      expect(b.can(TransactionAction.reportBuyerTransfer), isFalse);
    });

    test('SELL chưa có xác nhận tiền thì không ai được bắt đầu bàn giao (AC-14)', () async {
      for (final viewer in [MockFixtures.userA, MockFixtures.userB]) {
        final d = (await _repo(viewer).getTransactionDetails('txn-sell-01'))!;
        expect(d.can(TransactionAction.startHandover), isFalse);
      }
    });

    test('DONATE chờ bàn giao: A bắt đầu bàn giao, B thì không', () async {
      final a = (await _repo(MockFixtures.userA).getTransactionDetails('txn-delivery-01'))!;
      final b = (await _repo(MockFixtures.userB).getTransactionDetails('txn-delivery-01'))!;
      expect(a.can(TransactionAction.startHandover), isTrue);
      expect(b.can(TransactionAction.startHandover), isFalse);
    });

    test('BORROW đang mượn: chỉ B được gợi ý yêu cầu trả', () async {
      final a = (await _repo(MockFixtures.userA).getTransactionDetails('txn-borrow-01'))!;
      final b = (await _repo(MockFixtures.userB).getTransactionDetails('txn-borrow-01'))!;
      expect(b.can(TransactionAction.requestReturn), isTrue);
      expect(a.can(TransactionAction.requestReturn), isFalse);
      expect(a.can(TransactionAction.reportIssue), isTrue);
    });
  });

  group('Báo sự cố sau COMPLETED (BR-34, hạn 7 ngày lịch VN)', () {
    // Hoàn tất lúc 03:00 UTC ngày 22/11 = 10:00 ngày 22/11 giờ VN; hạn hết ngày 29/11.
    MockTransactionQueryRepository repoAt(DateTime now, String viewer,
        {TransactionStatus status = TransactionStatus.completed}) {
      var clock = DateTime.utc(2026, 11, 22, 3);
      final store = MockTransactionStore.fromFixtures(clock: () => clock);
      store.appendEvent(
          transactionId: 'txn-borrow-01',
          eventType: 'TRANSACTION_COMPLETED',
          safeDescription: 'Hoàn tất.');
      store.setStatus('txn-borrow-01', status);
      clock = now;
      return MockTransactionQueryRepository(demoViewerId: viewer, store: store);
    }

    test('Trong hạn: A và B được gợi ý báo sự cố, không có thao tác nào khác',
        () async {
      for (final viewer in [MockFixtures.userA, MockFixtures.userB]) {
        // 23:59 ngày 29/11 giờ VN vẫn còn hạn.
        final d = (await repoAt(DateTime.utc(2026, 11, 29, 16, 59), viewer)
            .getTransactionDetails('txn-borrow-01'))!;
        expect(d.allowedActions, {TransactionAction.reportIssue});
      }
    });

    test('Quá hạn (00:00 ngày 30/11 giờ VN): không còn gợi ý', () async {
      final d = (await repoAt(DateTime.utc(2026, 11, 29, 17), MockFixtures.userB)
          .getTransactionDetails('txn-borrow-01'))!;
      expect(d.allowedActions, isEmpty);
    });

    test('Giao dịch đã hủy: không gợi ý báo sự cố', () async {
      final d = (await repoAt(DateTime.utc(2026, 11, 23), MockFixtures.userB,
              status: TransactionStatus.cancelled)
          .getTransactionDetails('txn-borrow-01'))!;
      expect(d.allowedActions, isEmpty);
    });
  });

  group('Timeline cùng thời điểm giữ thứ tự sự kiện thực tế', () {
    test('Sự kiện giao dịch 10, 11, 12 không nhảy lên trước 2–9', () async {
      final at = DateTime.utc(2026, 11, 22, 3);
      final store = MockTransactionStore.fromFixtures(clock: () => at);
      final ids = [
        for (var i = 0; i < 12; i++)
          store.appendEvent(
              transactionId: 'txn-borrow-01',
              eventType: 'NOTE',
              safeDescription: 'Sự kiện ${i + 1}'),
      ];
      final repo = MockTransactionQueryRepository(
          demoViewerId: MockFixtures.userA, store: store);
      final timeline = (await repo.getTimeline('txn-borrow-01'))
          .where((e) => e.eventType == 'NOTE')
          .map((e) => e.id)
          .toList();
      expect(timeline, ids); // evt-mock-1 … evt-mock-12 đúng thứ tự ghi.
    });

    test('Sự kiện Issue cùng thời điểm cũng giữ thứ tự ghi', () async {
      final at = DateTime.utc(2026, 11, 22, 3);
      final store = MockTransactionStore.fromFixtures(
          clock: () => at,
          seedIssues: [
            Issue(
              id: 'issue-t',
              transactionId: 'txn-borrow-01',
              reporterId: MockFixtures.userB,
              type: IssueType.wrongCondition,
              reason: 'x',
              status: IssueStatus.open,
              openedAt: at,
            ),
          ]);
      final ids = [
        for (var i = 0; i < 12; i++)
          store.appendIssueEvent(
              issueId: 'issue-t', eventType: 'NOTE', safeDescription: '$i'),
      ];
      final repo = MockIssueQueryRepository(
          demoViewerId: MockFixtures.userA, store: store);
      expect((await repo.getTimeline('issue-t')).map((e) => e.id).toList(), ids);
    });
  });

  test('Timeline sắp xếp tăng dần theo thời điểm server', () async {
    final events = await _repo(MockFixtures.userA).getTimeline('txn-borrow-01');
    expect(events.map((e) => e.id).toList(),
        ['evt-borrow-01', 'evt-borrow-02', 'evt-borrow-03']);
    for (var i = 1; i < events.length; i++) {
      expect(events[i].serverAt.isBefore(events[i - 1].serverAt), isFalse);
    }
  });
}
