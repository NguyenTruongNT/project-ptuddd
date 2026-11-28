import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/notification_item.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/core/mock/mock_notification_query_repository.dart';
import 'package:studyshare/core/mock/mock_transaction_store.dart';
import 'package:studyshare/features/issues/data/mock_issue_command_runner.dart';
import 'package:studyshare/features/issues/data/mock_issue_repository.dart';
import 'package:studyshare/features/notifications/data/mock_notification_repository.dart';
import 'package:studyshare/features/notifications/domain/notification_labels.dart';
import 'package:studyshare/features/transactions/data/mock_command_runner.dart';
import 'package:studyshare/features/transactions/data/mock_seller_payment_repository.dart';

const a = MockFixtures.userA;
const b = MockFixtures.userB;
const c = MockFixtures.userC;

final _now = DateTime.utc(2026, 11, 23, 3);

MockTransactionStore _store() => MockTransactionStore.fromFixtures(clock: () => _now);

Future<List<AppNotification>> _inbox(MockTransactionStore store, String viewer) =>
    MockNotificationQueryRepository(demoViewerId: viewer, store: store)
        .getMyNotifications();

MockNotificationRepository _repo(MockTransactionStore store, String actor) =>
    MockNotificationRepository(store: store, actorId: actor);

T _ok<T>(CommandResult<T> result) {
  expect(result, isA<CommandOk<T>>());
  return (result as CommandOk<T>).data;
}

void main() {
  group('Sinh thông báo từ lệnh mock', () {
    test('A xác nhận đã nhận tiền: chỉ B nhận thông báo, trỏ tới giao dịch', () async {
      final store = _store();
      final aBefore = (await _inbox(store, a)).length;
      final payments = MockSellerPaymentRepository(
          MockCommandRunner(store: store, actorId: a));

      _ok(await payments.confirmSellerPayment('txn-sell-01',
          idempotencyKey: 'pay-1'));

      final inboxB = await _inbox(store, b);
      final notice = inboxB.first;
      expect(notice.type, 'SELLER_PAYMENT_CONFIRMED');
      expect(notice.entityType, NotificationEntityType.transaction);
      expect(notice.entityId, 'txn-sell-01');
      expect(notice.isRead, isFalse);
      expect(notice.createdAt, _now);
      expect(notice.safePreview, startsWith('Nhập môn Python: '));
      // Người thực hiện không tự nhận thông báo; C không liên quan.
      expect((await _inbox(store, a)).length, aBefore);
      expect(await _inbox(store, c), isEmpty);
    });

    test('Retry cùng key không sinh thông báo lần hai', () async {
      final store = _store();
      final payments = MockSellerPaymentRepository(
          MockCommandRunner(store: store, actorId: a));
      _ok(await payments.confirmSellerPayment('txn-sell-01',
          idempotencyKey: 'pay-1'));
      final once = (await _inbox(store, b)).length;
      _ok(await payments.confirmSellerPayment('txn-sell-01',
          idempotencyKey: 'pay-1'));
      expect((await _inbox(store, b)).length, once);
    });

    test('Lệnh bị từ chối không sinh thông báo', () async {
      final store = _store();
      final before = (await _inbox(store, a)).length;
      // B không được xác nhận thay người bán.
      final result = await MockSellerPaymentRepository(
              MockCommandRunner(store: store, actorId: b))
          .confirmSellerPayment('txn-sell-01', idempotencyKey: 'pay-b');
      expect(result, isA<CommandError>());
      expect((await _inbox(store, a)).length, before);
    });

    test('B mở sự cố: A nhận đúng một thông báo trỏ tới Issue', () async {
      final store = _store();
      final before = (await _inbox(store, a)).length;
      final issues = MockIssueRepository(
          MockIssueCommandRunner(store: store, actorId: b));

      final details = _ok(await issues.reportIssue(
        const CreateIssueInput(
          transactionId: 'txn-borrow-01',
          type: IssueType.wrongCondition,
          reason: 'Bìa sách bị rách.',
        ),
        idempotencyKey: 'issue-1',
      ));

      final inboxA = await _inbox(store, a);
      // Event ISSUE_OPENED ghi ở cả nhật ký Issue lẫn giao dịch nhưng chỉ báo một lần.
      expect(inboxA.length, before + 1);
      expect(inboxA.first.entityType, NotificationEntityType.issue);
      expect(inboxA.first.entityId, details.id);
      expect(inboxA.first.type, 'ISSUE_OPENED');
      expect(await _inbox(store, c), isEmpty);
    });
  });

  group('Đánh dấu đã đọc', () {
    test('Người nhận đánh dấu đã đọc; gọi lại giữ nguyên mốc cũ', () async {
      var clock = _now;
      final store = MockTransactionStore.fromFixtures(clock: () => clock);
      final first = _ok(await _repo(store, a)
          .markRead('notice-a-01', idempotencyKey: 'r1'));
      expect(first.readAt, _now);

      clock = _now.add(const Duration(hours: 1));
      final again = _ok(await _repo(store, a)
          .markRead('notice-a-01', idempotencyKey: 'r2'));
      expect(again.readAt, _now);
      expect((await _inbox(store, a)).single.isRead, isTrue);
    });

    test('Không phân biệt thông báo của người khác với ID không tồn tại', () async {
      final store = _store();
      final other = await _repo(store, b)
          .markRead('notice-a-01', idempotencyKey: 'r1');
      final missing = await _repo(store, b)
          .markRead('notice-khong-co', idempotencyKey: 'r2');
      for (final result in [other, missing]) {
        expect(result, isA<CommandError>());
        final error = result as CommandError;
        expect(error.code, DomainErrorCode.forbidden);
        expect(error.safeMessage, notificationUnavailableMessage);
      }
      expect((await _inbox(store, a)).single.isRead, isFalse);
    });

    test('Thiếu key hoặc dùng key cho thông báo khác bị từ chối', () async {
      final store = _store();
      final missingKey =
          await _repo(store, a).markRead('notice-a-01', idempotencyKey: ' ');
      expect((missingKey as CommandError).code, DomainErrorCode.invalidInput);

      store.appendNotification(
        recipientId: a,
        type: 'CANCELLATION_PROPOSED',
        entityType: NotificationEntityType.transaction,
        entityId: 'txn-sell-01',
        safePreview: 'Nhập môn Python: B đề nghị hủy.',
      );
      final newest = (await _inbox(store, a)).first;
      _ok(await _repo(store, a).markRead('notice-a-01', idempotencyKey: 'k'));
      final reused =
          await _repo(store, a).markRead(newest.id, idempotencyKey: 'k');
      expect((reused as CommandError).code, DomainErrorCode.conflict);
    });

    test('Đánh dấu tất cả chỉ đổi thông báo của mình, retry trả cùng kết quả', () async {
      final store = _store();
      store.appendNotification(
        recipientId: a,
        type: 'ISSUE_OPENED',
        entityType: NotificationEntityType.issue,
        entityId: 'issue-x',
        safePreview: 'Có sự cố.',
      );
      expect(_ok(await _repo(store, a).markAllRead(idempotencyKey: 'all')), 2);
      expect(_ok(await _repo(store, a).markAllRead(idempotencyKey: 'all')), 2);
      expect((await _inbox(store, a)).every((n) => n.isRead), isTrue);
      // Thông báo của B (đã đọc sẵn trong fixture) không bị đổi mốc.
      expect((await _inbox(store, b)).single.readAt, DateTime.utc(2026, 11, 20, 9));
      expect(_ok(await _repo(store, a).markAllRead(idempotencyKey: 'all-2')), 0);
    });
  });

  group('Nhãn và deep link', () {
    AppNotification notice(NotificationEntityType type, {String id = 'x-1'}) =>
        AppNotification(
          id: 'n',
          recipientId: a,
          type: 'KHONG_BIET',
          entityType: type,
          entityId: id,
          safePreview: 'Xem trước',
          createdAt: _now,
        );

    test('Mã lạ không làm hỏng hộp thư', () {
      expect(NotificationEntityType.parse('transaction'),
          NotificationEntityType.transaction);
      expect(NotificationEntityType.parse('SOMETHING_NEW'),
          NotificationEntityType.unknown);
      expect(notificationTitleVi('KHONG_BIET'), 'Thông báo');
    });

    test('Không khẳng định đã thanh toán khi B mới báo chuyển khoản', () {
      final title = notificationTitleVi('PAYMENT_REPORTED');
      expect(title, contains('báo'));
      expect(title.toLowerCase(), isNot(contains('thành công')));
    });

    test('Deep link chỉ dựng từ loại + ID, loại lạ không điều hướng', () {
      expect(notificationTargetRoute(notice(NotificationEntityType.transaction)),
          '/transactions/x-1');
      expect(notificationTargetRoute(notice(NotificationEntityType.issue)),
          '/issues/x-1');
      expect(notificationTargetRoute(notice(NotificationEntityType.unknown)),
          isNull);
      expect(
          notificationTargetRoute(
              notice(NotificationEntityType.transaction, id: ' ')),
          isNull);
    });
  });
}
