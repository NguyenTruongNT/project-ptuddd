import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/transaction.dart';
import 'package:studyshare/features/transactions/domain/transaction_labels.dart';

TransactionDetails _details({
  OfferType type = OfferType.borrow,
  TransactionStatus status = TransactionStatus.borrowing,
  TransactionViewerRole role = TransactionViewerRole.receiver,
  BorrowingRecord? borrowing,
  PaymentConfirmation? payment,
  int openIssueCount = 0,
}) =>
    TransactionDetails(
      transaction: StudyTransaction(
        id: 'txn-t', listingId: 'l', requestId: 'r', materialId: 'm',
        type: type, ownerAtAcceptance: 'a', receiverId: 'b', status: status,
        agreedBorrowDays: type == OfferType.borrow ? 7 : null,
        agreedPriceVnd: type == OfferType.sell ? 90000 : null,
      ),
      materialTitle: 'Sách',
      materialSubject: 'Môn',
      ownerDisplayName: 'A',
      receiverDisplayName: 'B',
      viewerRole: role,
      createdAt: DateTime.utc(2026, 11, 20),
      borrowing: borrowing,
      payment: payment,
      openIssueCount: openIssueCount,
    );

final _borrow7 = BorrowingRecord(
  transactionId: 'txn-t',
  startedAt: DateTime.utc(2026, 11, 21, 2),
  dueDateVn: '2026-11-28',
);

void main() {
  group('Ngày lịch Việt Nam', () {
    test('17:00 UTC là 00:00 ngày hôm sau ở Việt Nam', () {
      expect(vnCalendarDate(DateTime.utc(2026, 11, 28, 16, 59)),
          DateTime.utc(2026, 11, 28));
      expect(vnCalendarDate(DateTime.utc(2026, 11, 28, 17)),
          DateTime.utc(2026, 11, 29));
    });

    test('Định dạng ngày, giờ và tiền', () {
      expect(formatVnDate('2026-11-28'), '28/11/2026');
      expect(formatVnDate(null), '—');
      expect(formatServerTimeVn(DateTime.utc(2026, 11, 21, 9)), '16:00 21/11/2026');
      expect(formatVnd(90000), '90.000 đ');
      expect(formatVnd(1250000), '1.250.000 đ');
      expect(formatVnd(500), '500 đ');
    });
  });

  group('OVERDUE dẫn xuất (AC-10, BR-21)', () {
    test('Hạn 28/11: 23:59 ngày 28/11 giờ VN chưa quá hạn', () {
      final d = _details(borrowing: _borrow7);
      expect(isOverdue(d, DateTime.utc(2026, 11, 28, 16, 59)), isFalse);
    });

    test('Hạn 28/11: từ 00:00 ngày 29/11 giờ VN là quá hạn', () {
      final d = _details(borrowing: _borrow7);
      expect(isOverdue(d, DateTime.utc(2026, 11, 28, 17)), isTrue);
      // Nhãn dẫn xuất không đổi status lưu trữ.
      expect(d.transaction.status, TransactionStatus.borrowing);
    });

    test('BORROW đã COMPLETED không bị gắn nhãn quá hạn', () {
      final d = _details(status: TransactionStatus.completed, borrowing: _borrow7);
      expect(isOverdue(d, DateTime.utc(2026, 12, 5)), isFalse);
    });

    test('B giao cho C chiều trả trước hạn thì không tính trễ gốc (AC-11)', () {
      final d = _details(
        status: TransactionStatus.returnInProgress,
        borrowing: BorrowingRecord(
          transactionId: 'txn-t',
          startedAt: DateTime.utc(2026, 11, 21, 2),
          dueDateVn: '2026-11-28',
          returnToCourierAt: DateTime.utc(2026, 11, 28, 10),
        ),
      );
      expect(isOverdue(d, DateTime.utc(2026, 12, 1)), isFalse);
    });

    test('Hạn tái bàn giao 3 ngày được tính riêng', () {
      final d = _details(
        status: TransactionStatus.returnPending,
        borrowing: const BorrowingRecord(
          transactionId: 'txn-t',
          dueDateVn: '2026-11-28',
          reHandoverDueDateVn: '2026-11-30',
        ),
      );
      expect(isReHandoverOverdue(d, DateTime.utc(2026, 11, 30, 16)), isFalse);
      expect(isReHandoverOverdue(d, DateTime.utc(2026, 11, 30, 17)), isTrue);
    });
  });

  test('NEEDS_RESOLUTION chỉ là nhãn suy ra từ Issue OPEN (MVP-D01)', () {
    expect(needsResolution(_details()), isFalse);
    final withIssue = _details(openIssueCount: 1);
    expect(needsResolution(withIssue), isTrue);
    expect(withIssue.transaction.status, TransactionStatus.borrowing);
    expect(belongsToTab(withIssue, TransactionTab.withIssue), isTrue);
    expect(belongsToTab(withIssue, TransactionTab.active), isTrue);
  });

  group('Câu "đang chờ" cho SELL (SON-T06)', () {
    final reported = PaymentConfirmation(
      transactionId: 'txn-t', buyerReportedAt: DateTime.utc(2026, 11, 21));

    test('B báo chuyển khoản không bao giờ hiện là thanh toán thành công', () {
      for (final role in TransactionViewerRole.values) {
        final text = waitingOnVi(_details(
          type: OfferType.sell,
          status: TransactionStatus.awaitingPayment,
          role: role,
          payment: reported,
        ));
        expect(text.toLowerCase().contains('thành công'), isFalse);
      }
    });

    test('A được nhắc tự kiểm tra tài khoản rồi xác nhận', () {
      final text = waitingOnVi(_details(
        type: OfferType.sell,
        status: TransactionStatus.awaitingPayment,
        role: TransactionViewerRole.owner,
        payment: reported,
      ));
      expect(text, contains('xác nhận đã nhận tiền'));
    });
  });

  group('Đề nghị hủy và hoàn tiền', () {
    test('Nhãn đề nghị hủy theo góc nhìn người xem', () {
      final proposal = CancellationProposal(
        proposedBy: TransactionViewerRole.owner,
        reason: 'Lý do',
        proposedAt: DateTime.utc(2026, 11, 22),
      );
      TransactionDetails withProposal(TransactionViewerRole role) => TransactionDetails(
            transaction: _details().transaction,
            materialTitle: 'Sách',
            materialSubject: 'Môn',
            ownerDisplayName: 'A',
            receiverDisplayName: 'B',
            viewerRole: role,
            createdAt: DateTime.utc(2026, 11, 20),
            cancellationProposal: proposal,
          );
      expect(hasPendingCancellation(_details()), isFalse);
      expect(cancellationStatusVi(_details()), isEmpty);
      expect(cancellationStatusVi(withProposal(TransactionViewerRole.owner)),
          startsWith('Bạn đã đề nghị hủy'));
      expect(cancellationStatusVi(withProposal(TransactionViewerRole.receiver)),
          startsWith('Bên còn lại đề nghị hủy'));
    });

    test('Tiến độ hoàn tiền chỉ có khi người bán đã nhận tiền', () {
      PaymentConfirmation pay({DateTime? confirmed, DateTime? reported, DateTime? back}) =>
          PaymentConfirmation(
            transactionId: 'txn-t',
            sellerConfirmedAt: confirmed,
            refundReportedAt: reported,
            buyerRefundConfirmedAt: back,
          );
      final t = DateTime.utc(2026, 11, 22);
      TransactionDetails sell(PaymentConfirmation p) =>
          _details(type: OfferType.sell, status: TransactionStatus.awaitingHandover, payment: p);

      expect(refundStatusVi(sell(pay())), isNull);
      expect(pay().hasOutstandingRefund, isFalse);
      expect(refundStatusVi(sell(pay(confirmed: t))), contains('cần hoàn tiền'));
      expect(pay(confirmed: t).hasOutstandingRefund, isTrue);
      expect(refundStatusVi(sell(pay(confirmed: t, reported: t))), contains('chờ người mua'));
      expect(pay(confirmed: t, reported: t).hasOutstandingRefund, isTrue);
      expect(pay(confirmed: t, reported: t, back: t).hasOutstandingRefund, isFalse);
    });
  });

  test('Mọi status đều có nhãn tiếng Việt', () {
    for (final status in TransactionStatus.values) {
      expect(statusLabelVi(status), isNotEmpty);
      expect(waitingOnVi(_details(status: status)), isNotEmpty);
    }
  });

  test('Phân tab: kết thúc gồm COMPLETED và CANCELLED', () {
    expect(belongsToTab(_details(status: TransactionStatus.completed),
        TransactionTab.completed), isTrue);
    expect(belongsToTab(_details(status: TransactionStatus.cancelled),
        TransactionTab.completed), isTrue);
    expect(belongsToTab(_details(status: TransactionStatus.borrowing),
        TransactionTab.completed), isFalse);
  });
}
