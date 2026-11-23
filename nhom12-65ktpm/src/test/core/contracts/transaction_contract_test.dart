import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/transaction.dart';

void main() {
  test('TransactionAction đọc đúng mã server và từ chối mã lạ', () {
    for (final action in TransactionAction.values) {
      expect(TransactionAction.fromWire(action.wire), action);
    }
    expect(TransactionAction.confirmSellerPayment.wire,
        'CAN_CONFIRM_SELLER_PAYMENT');
    expect(() => TransactionAction.fromWire('CAN_FORCE_COMPLETE'),
        throwsFormatException);
  });

  test('TransactionDetails.can chỉ phản ánh gợi ý server trả về', () {
    final details = TransactionDetails(
      transaction: const StudyTransaction(
        id: 'txn-x', listingId: 'l', requestId: 'r', materialId: 'm',
        type: OfferType.sell, ownerAtAcceptance: 'a', receiverId: 'b',
        status: TransactionStatus.awaitingPayment, agreedPriceVnd: 1000,
      ),
      materialTitle: 'Sách',
      materialSubject: 'Môn',
      ownerDisplayName: 'A',
      receiverDisplayName: 'B',
      viewerRole: TransactionViewerRole.receiver,
      createdAt: DateTime.utc(2026, 11, 20),
      allowedActions: const {TransactionAction.reportBuyerTransfer},
    );
    expect(details.id, 'txn-x');
    expect(details.can(TransactionAction.reportBuyerTransfer), isTrue);
    expect(details.can(TransactionAction.confirmSellerPayment), isFalse);
  });
}
