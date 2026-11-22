import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';

void main() {
  test('Giữ đúng mã trạng thái nghiệp vụ SS-BR', () {
    expect(ListingStatus.published.wire, 'PUBLISHED');
    expect(ExchangeRequestStatus.accepted.wire, 'ACCEPTED');
    expect(TransactionStatus.awaitingPayment.wire, 'AWAITING_PAYMENT');
    expect(HandoverStatus.awaitingReceiverConfirmation.wire,
        'AWAITING_RECEIVER_CONFIRMATION');
    expect(DeliveryTaskStatus.deliveryPendingConfirmation.wire,
        'DELIVERY_PENDING_CONFIRMATION');
    expect(IssueStatus.resolved.wire, 'RESOLVED');
  });

  test('Đọc dữ liệu từ server và từ chối mã không hợp lệ', () {
    expect(OfferType.fromWire('BORROW'), OfferType.borrow);
    expect(ListingStatus.fromWire('PUBLISHED'), ListingStatus.published);
    expect(() => ListingStatus.fromWire('RESERVED'), throwsFormatException);
    expect(() => TransactionStatus.fromWire('OVERDUE'), throwsFormatException);
    expect(() => IssueStatus.fromWire('CLOSED'), throwsFormatException);
  });

  test('Trạng thái kết thúc không bao gồm BORROWING', () {
    expect(TransactionStatus.borrowing.isTerminal, false);
    expect(TransactionStatus.completed.isTerminal, true);
    expect(TransactionStatus.cancelled.isTerminal, true);
  });
}
