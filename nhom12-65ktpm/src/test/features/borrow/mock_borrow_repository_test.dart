import 'package:flutter_test/flutter_test.dart';

import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/transaction.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/core/mock/mock_transaction_store.dart';
import 'package:studyshare/features/borrow/data/mock_borrow_repository.dart';

void main() {
  const String borrowTransactionId = 'txn-borrow-01';
  const String sellTransactionId = 'txn-sell-01';

  group('MockBorrowRepository.requestReturn', () {
    test(
      'B yêu cầu trả khi đang BORROWING thì chuyển RETURN_PENDING',
      () async {
        final MockTransactionStore store = MockTransactionStore.fromFixtures();

        final MockBorrowRepository repository = MockBorrowRepository(
          store,
          MockFixtures.userB,
        );

        final CommandResult<StudyTransaction> result = await repository
            .requestReturn(
              borrowTransactionId,
              idempotencyKey: 'return-key-01',
            );

        expect(result, isA<CommandOk<StudyTransaction>>());

        final CommandOk<StudyTransaction> success =
            result as CommandOk<StudyTransaction>;

        expect(success.data.status, TransactionStatus.returnPending);

        expect(success.serverEventId, isNotNull);

        expect(
          store.transaction(borrowTransactionId)?.status,
          TransactionStatus.returnPending,
        );
      },
    );

    test('yêu cầu trả chỉ ghi một sự kiện RETURN_REQUESTED', () async {
      final MockTransactionStore store = MockTransactionStore.fromFixtures();

      final int eventCountBefore = store.events(borrowTransactionId).length;

      final MockBorrowRepository repository = MockBorrowRepository(
        store,
        MockFixtures.userB,
      );

      await repository.requestReturn(
        borrowTransactionId,
        idempotencyKey: 'return-key-02',
      );

      final List<TransactionEventItem> events = store.events(
        borrowTransactionId,
      );

      expect(events.length, eventCountBefore + 1);

      expect(events.last.eventType, 'RETURN_REQUESTED');

      expect(events.last.safeDescription, contains('yêu cầu trả'));
    });

    test('retry cùng key không nhân đôi sự kiện', () async {
      final MockTransactionStore store = MockTransactionStore.fromFixtures();

      final MockBorrowRepository repository = MockBorrowRepository(
        store,
        MockFixtures.userB,
      );

      final int eventCountBefore = store.events(borrowTransactionId).length;

      final CommandResult<StudyTransaction> first = await repository
          .requestReturn(
            borrowTransactionId,
            idempotencyKey: 'return-retry-key',
          );

      final CommandResult<StudyTransaction> retry = await repository
          .requestReturn(
            borrowTransactionId,
            idempotencyKey: 'return-retry-key',
          );

      expect(first, isA<CommandOk<StudyTransaction>>());

      expect(retry, isA<CommandOk<StudyTransaction>>());

      final CommandOk<StudyTransaction> firstOk =
          first as CommandOk<StudyTransaction>;

      final CommandOk<StudyTransaction> retryOk =
          retry as CommandOk<StudyTransaction>;

      expect(retryOk.serverEventId, firstOk.serverEventId);

      expect(store.events(borrowTransactionId).length, eventCountBefore + 1);
    });

    test('key mới sau khi đã yêu cầu trả bị từ chối', () async {
      final MockTransactionStore store = MockTransactionStore.fromFixtures();

      final MockBorrowRepository repository = MockBorrowRepository(
        store,
        MockFixtures.userB,
      );

      await repository.requestReturn(
        borrowTransactionId,
        idempotencyKey: 'return-first-key',
      );

      final CommandResult<StudyTransaction> result = await repository
          .requestReturn(
            borrowTransactionId,
            idempotencyKey: 'return-second-key',
          );

      expect(result, isA<CommandError<StudyTransaction>>());

      final CommandError<StudyTransaction> error =
          result as CommandError<StudyTransaction>;

      expect(error.code, DomainErrorCode.invalidTransactionTransition);

      expect(
        store.transaction(borrowTransactionId)?.status,
        TransactionStatus.returnPending,
      );
    });

    test('A không được yêu cầu trả thay B', () async {
      final MockTransactionStore store = MockTransactionStore.fromFixtures();

      final MockBorrowRepository repository = MockBorrowRepository(
        store,
        MockFixtures.userA,
      );

      final CommandResult<StudyTransaction> result = await repository
          .requestReturn(
            borrowTransactionId,
            idempotencyKey: 'owner-return-key',
          );

      expect(result, isA<CommandError<StudyTransaction>>());

      final CommandError<StudyTransaction> error =
          result as CommandError<StudyTransaction>;

      expect(error.code, DomainErrorCode.forbidden);

      expect(
        store.transaction(borrowTransactionId)?.status,
        TransactionStatus.borrowing,
      );
    });

    test('người ngoài không được biết giao dịch tồn tại', () async {
      final MockTransactionStore store = MockTransactionStore.fromFixtures();

      final MockBorrowRepository repository = MockBorrowRepository(
        store,
        MockFixtures.outsider,
      );

      final CommandResult<StudyTransaction> result = await repository
          .requestReturn(
            borrowTransactionId,
            idempotencyKey: 'outsider-return-key',
          );

      expect(result, isA<CommandError<StudyTransaction>>());

      final CommandError<StudyTransaction> error =
          result as CommandError<StudyTransaction>;

      expect(error.code, DomainErrorCode.forbidden);
    });

    test('SELL không thể dùng nghiệp vụ yêu cầu trả BORROW', () async {
      final MockTransactionStore store = MockTransactionStore.fromFixtures();

      final MockBorrowRepository repository = MockBorrowRepository(
        store,
        MockFixtures.userB,
      );

      final CommandResult<StudyTransaction> result = await repository
          .requestReturn(sellTransactionId, idempotencyKey: 'sell-return-key');

      expect(result, isA<CommandError<StudyTransaction>>());

      final CommandError<StudyTransaction> error =
          result as CommandError<StudyTransaction>;

      expect(error.code, DomainErrorCode.invalidTransactionTransition);

      expect(
        store.transaction(sellTransactionId)?.status,
        TransactionStatus.awaitingPayment,
      );
    });

    test('transactionId rỗng bị từ chối trước khi đọc store', () async {
      final MockTransactionStore store = MockTransactionStore.fromFixtures();

      final MockBorrowRepository repository = MockBorrowRepository(
        store,
        MockFixtures.userB,
      );

      final CommandResult<StudyTransaction> result = await repository
          .requestReturn('   ', idempotencyKey: 'empty-id-key');

      expect(result, isA<CommandError<StudyTransaction>>());

      final CommandError<StudyTransaction> error =
          result as CommandError<StudyTransaction>;

      expect(error.code, DomainErrorCode.invalidInput);
    });

    test('idempotency key rỗng bị từ chối', () async {
      final MockTransactionStore store = MockTransactionStore.fromFixtures();

      final MockBorrowRepository repository = MockBorrowRepository(
        store,
        MockFixtures.userB,
      );

      final CommandResult<StudyTransaction> result = await repository
          .requestReturn(borrowTransactionId, idempotencyKey: '   ');

      expect(result, isA<CommandError<StudyTransaction>>());

      final CommandError<StudyTransaction> error =
          result as CommandError<StudyTransaction>;

      expect(error.code, DomainErrorCode.invalidInput);

      expect(
        store.transaction(borrowTransactionId)?.status,
        TransactionStatus.borrowing,
      );
    });

    test('yêu cầu trả không tự hoàn tất giao dịch', () async {
      final MockTransactionStore store = MockTransactionStore.fromFixtures();

      final MockBorrowRepository repository = MockBorrowRepository(
        store,
        MockFixtures.userB,
      );

      await repository.requestReturn(
        borrowTransactionId,
        idempotencyKey: 'not-completed-key',
      );

      final StudyTransaction transaction = store.transaction(
        borrowTransactionId,
      )!;

      expect(transaction.status, TransactionStatus.returnPending);

      expect(transaction.status, isNot(TransactionStatus.completed));

      expect(transaction.ownerAtAcceptance, MockFixtures.userA);

      expect(transaction.receiverId, MockFixtures.userB);
    });
  });
}
