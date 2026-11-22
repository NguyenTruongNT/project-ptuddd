import '../contracts/domain_enums.dart';
import '../contracts/models/models.dart';

// Dữ liệu ẢO, ID cố định để cả nhóm test. Không dùng dữ liệu sinh viên thật.
class MockFixtures {
  MockFixtures._();

  static const userA = 'demo-user-a'; // Chủ sách A
  static const userB = 'demo-user-b'; // Người yêu cầu B
  static const userC = 'demo-user-c'; // Người giao hộ C
  static const outsider = 'demo-user-outsider';

  static List<Material> get materials => const [
    Material(id: 'mat-borrow-01', ownerId: userA, holderId: userB,
        title: 'Giáo trình Giải tích', subject: 'Toán cao cấp', condition: 'Tốt'),
    Material(id: 'mat-borrow-02', ownerId: userA, holderId: userA,
        title: 'Giáo trình Giải tích', subject: 'Toán cao cấp', condition: 'Như mới'),
    Material(id: 'mat-sell-01', ownerId: userA, holderId: userA,
        title: 'Nhập môn Python', subject: 'Lập trình', condition: 'Như mới'),
    Material(id: 'mat-donate-01', ownerId: userA, holderId: userA,
        title: 'Cấu trúc dữ liệu', subject: 'CNTT', condition: 'Đã sử dụng'),
    Material(id: 'mat-delivery-01', ownerId: userA, holderId: userA,
        title: 'Mạng máy tính', subject: 'Mạng', condition: 'Tốt'),
  ];

  static List<Listing> get listings => const [
    Listing(id: 'list-borrow-01', materialId: 'mat-borrow-01',
        offerType: OfferType.borrow, status: ListingStatus.published),
    Listing(id: 'list-sell-01', materialId: 'mat-sell-01',
        offerType: OfferType.sell, status: ListingStatus.published,
        askingPriceVnd: 90000),
    Listing(id: 'list-donate-01', materialId: 'mat-donate-01',
        offerType: OfferType.donate, status: ListingStatus.published),
    Listing(id: 'list-delivery-01', materialId: 'mat-delivery-01',
        offerType: OfferType.donate, status: ListingStatus.published),
  ];

  static List<ExchangeRequest> get requests => [
    ExchangeRequest(id: 'req-borrow-01', listingId: 'list-borrow-01',
        requesterId: userB, status: ExchangeRequestStatus.accepted,
        requestedBorrowDays: 7, createdAt: DateTime.utc(2026, 11, 20)),
    ExchangeRequest(id: 'req-sell-01', listingId: 'list-sell-01',
        requesterId: userB, status: ExchangeRequestStatus.accepted,
        createdAt: DateTime.utc(2026, 11, 20)),
    ExchangeRequest(id: 'req-donate-01', listingId: 'list-donate-01',
        requesterId: userB, status: ExchangeRequestStatus.pending,
        createdAt: DateTime.utc(2026, 11, 21)),
    ExchangeRequest(id: 'req-delivery-01', listingId: 'list-delivery-01',
        requesterId: userB, status: ExchangeRequestStatus.accepted,
        createdAt: DateTime.utc(2026, 11, 20)),
  ];

  static List<StudyTransaction> get transactions => const [
    StudyTransaction(id: 'txn-borrow-01', listingId: 'list-borrow-01',
        requestId: 'req-borrow-01', materialId: 'mat-borrow-01',
        type: OfferType.borrow, ownerAtAcceptance: userA, receiverId: userB,
        status: TransactionStatus.borrowing, agreedBorrowDays: 7),
    StudyTransaction(id: 'txn-sell-01', listingId: 'list-sell-01',
        requestId: 'req-sell-01', materialId: 'mat-sell-01',
        type: OfferType.sell, ownerAtAcceptance: userA, receiverId: userB,
        status: TransactionStatus.awaitingPayment, agreedPriceVnd: 90000),
    StudyTransaction(id: 'txn-delivery-01', listingId: 'list-delivery-01',
        requestId: 'req-delivery-01', materialId: 'mat-delivery-01',
        type: OfferType.donate, ownerAtAcceptance: userA, receiverId: userB,
        status: TransactionStatus.awaitingHandover),
  ];

  static List<BorrowingRecord> get borrowingRecords => [
    BorrowingRecord(transactionId: 'txn-borrow-01',
      startedAt: DateTime.utc(2026, 11, 21, 9), dueDateVn: '2026-11-28'),
  ];

  static List<PaymentConfirmation> get payments => [
    PaymentConfirmation(transactionId: 'txn-sell-01',
      buyerReportedAt: DateTime.utc(2026, 11, 21)),
  ];

  static List<DeliveryTask> get deliveryTasks => const [
    DeliveryTask(id: 'task-donate-01', transactionId: 'txn-delivery-01',
      senderId: userA, finalReceiverId: userB, status: DeliveryTaskStatus.open),
  ];

  static List<Handover> get handovers => const [
    Handover(id: 'handover-borrow-01', transactionId: 'txn-borrow-01',
      fromUserId: userA, toUserId: userB,
      status: HandoverStatus.confirmed, evidencePhotoCount: 1),
  ];

  static List<AppNotification> get notifications => [
    AppNotification(id: 'notice-b-01', recipientId: userB,
      safePreview: 'Yêu cầu mượn đã được duyệt.',
      createdAt: DateTime.utc(2026, 11, 21)),
  ];
}
