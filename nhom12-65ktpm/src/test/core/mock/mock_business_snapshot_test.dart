import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';

void main() {
  test('Cùng là tài liệu nhưng mỗi bản vật lý có ID riêng', () {
    final ids = MockFixtures.materials.map((material) => material.id).toSet();
    expect(ids.length, MockFixtures.materials.length);
    final sameTitle = MockFixtures.materials
        .where((material) => material.title == 'Giáo trình Giải tích')
        .toList();
    expect(sameTitle.length, 2);
    expect(sameTitle.first.id, isNot(sameTitle.last.id));
  });

  test('SELL chỉ B báo chuyển tiền chưa được phép xem là A xác nhận', () {
    final payment = MockFixtures.payments.single;
    expect(payment.buyerReportedAt, isNotNull);
    expect(payment.isSellerConfirmed, false);
    final txn = MockFixtures.transactions.singleWhere(
      (item) => item.type == OfferType.sell,
    );
    expect(txn.status, TransactionStatus.awaitingPayment);
  });

  test('BORROW do server snapshot hạn, không tính tự động ở client', () {
    final record = MockFixtures.borrowingRecords.single;
    expect(record.dueDateVn, '2026-11-28');
    expect(record.reHandoverDueDateVn, isNull);
  });

  test('B giữ bản BORROW; owner A không bị đổi khi B nhận', () {
    final material = MockFixtures.materials.singleWhere(
      (item) => item.id == 'mat-borrow-01',
    );
    expect(material.ownerId, MockFixtures.userA);
    expect(material.holderId, MockFixtures.userB);
  });
}
