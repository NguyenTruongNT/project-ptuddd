import '../contracts/domain_enums.dart';
import '../contracts/listing_workspace.dart';
import '../contracts/models/models.dart';

// Dữ liệu ẢO, ID cố định để cả nhóm test. Không dùng dữ liệu sinh viên thật.
class MockFixtures {
  MockFixtures._();

  static const userA = 'demo-user-a'; // Chủ sách A
  static const userB = 'demo-user-b'; // Người yêu cầu B
  static const userC = 'demo-user-c'; // Người giao hộ C
  static const outsider = 'demo-user-outsider';

  // Tên hiển thị ẢO; không dùng tên/MSSV thật.
  static const displayNames = <String, String>{
    userA: 'Bạn A (demo)',
    userB: 'Bạn B (demo)',
    userC: 'Bạn C (demo)',
  };

  static List<Material> get materials => const [
    Material(id: 'mat-borrow-01', ownerId: userA, holderId: userB,
        title: 'Giáo trình Giải tích', subject: 'Toán cao cấp', condition: 'Tốt',
        description: 'Tài liệu demo về giới hạn, đạo hàm và tích phân; có ghi chú bằng bút chì.'),
    Material(id: 'mat-borrow-02', ownerId: userA, holderId: userA,
        title: 'Giáo trình Giải tích', subject: 'Toán cao cấp', condition: 'Như mới'),
    Material(id: 'mat-sell-01', ownerId: userA, holderId: userA,
        title: 'Nhập môn Python', subject: 'Lập trình', condition: 'Như mới',
        description: 'Sách demo nhập môn Python, có ví dụ và bài tập thực hành.'),
    Material(id: 'mat-donate-01', ownerId: userA, holderId: userA,
        title: 'Cấu trúc dữ liệu', subject: 'CNTT', condition: 'Đã sử dụng',
        description: 'Tài liệu demo về danh sách, cây và đồ thị; bìa có dấu sử dụng.'),
    Material(id: 'mat-delivery-01', ownerId: userA, holderId: userA,
        title: 'Mạng máy tính', subject: 'Mạng', condition: 'Tốt',
        description: 'Tài liệu demo về các tầng mạng và giao thức TCP/IP.'),
  ];

  static List<Listing> get listings => const [
    Listing(id: 'list-borrow-01', materialId: 'mat-borrow-01',
        offerType: OfferType.borrow, status: ListingStatus.published,
        description: 'Cho mượn tài liệu demo; giữ gìn sách và trả đúng hạn.',
        meetingArea: 'Khu vực thư viện (demo)'),
    Listing(id: 'list-sell-01', materialId: 'mat-sell-01',
        offerType: OfferType.sell, status: ListingStatus.published,
        askingPriceVnd: 90000,
        description: 'Nhượng lại sách demo cho người cần học Python.',
        meetingArea: 'Khu vực cổng trường (demo)'),
    Listing(id: 'list-donate-01', materialId: 'mat-donate-01',
        offerType: OfferType.donate, status: ListingStatus.published,
        description: 'Tặng tài liệu demo cho bạn cần ôn cấu trúc dữ liệu.',
        meetingArea: 'Khu vực thư viện (demo)'),
    Listing(id: 'list-delivery-01', materialId: 'mat-delivery-01',
        offerType: OfferType.donate, status: ListingStatus.published,
        description: 'Tặng tài liệu mạng máy tính demo.',
        meetingArea: 'Khu vực sân trường (demo)'),
  ];

  // Ảnh minh họa công khai chỉ dùng trong demo; không giả làm ảnh Storage đã xác minh.
  // Card và gallery cùng lấy từ đây để bìa luôn là ảnh đầu của đúng Listing.
  static const listingImages = <String, List<ListingImage>>{
    'list-borrow-01': [
      ListingImage(id: 'demo-borrow-cover',
        url: 'https://placehold.co/600x800/png?text=Giai+tich'),
      ListingImage(id: 'demo-borrow-pages',
        url: 'https://placehold.co/800x600/png?text=Ghi+chu+Giai+tich'),
    ],
    'list-sell-01': [
      ListingImage(id: 'demo-sell-cover',
        url: 'https://placehold.co/600x800/png?text=Python'),
    ],
    'list-donate-01': [
      ListingImage(id: 'demo-donate-cover',
        url: 'https://placehold.co/600x800/png?text=Cau+truc+du+lieu'),
    ],
    'list-delivery-01': [
      ListingImage(id: 'demo-delivery-cover',
        url: 'https://placehold.co/600x800/png?text=Mang+may+tinh'),
    ],
  };

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

  // Thời điểm server tạo Transaction (lúc A duyệt Request).
  static Map<String, DateTime> get transactionCreatedAt => {
    'txn-borrow-01': DateTime.utc(2026, 11, 20, 8),
    'txn-sell-01': DateTime.utc(2026, 11, 20, 10),
    'txn-delivery-01': DateTime.utc(2026, 11, 20, 12),
  };

  // Sự kiện server append-only; cố ý xếp lộn xộn để test sắp xếp theo serverAt.
  static List<TransactionEventItem> get transactionEvents => [
    TransactionEventItem(id: 'evt-borrow-03', transactionId: 'txn-borrow-01',
      eventType: 'BORROW_STARTED', serverAt: DateTime.utc(2026, 11, 21, 9, 1),
      safeDescription: 'Bắt đầu kỳ mượn 7 ngày, hạn trả 28/11/2026.'),
    TransactionEventItem(id: 'evt-borrow-01', transactionId: 'txn-borrow-01',
      eventType: 'REQUEST_ACCEPTED', serverAt: DateTime.utc(2026, 11, 20, 8),
      safeDescription: 'A đã duyệt yêu cầu mượn.', actorDisplay: 'Bạn A (demo)'),
    TransactionEventItem(id: 'evt-borrow-02', transactionId: 'txn-borrow-01',
      eventType: 'HANDOVER_CONFIRMED', serverAt: DateTime.utc(2026, 11, 21, 9),
      safeDescription: 'B đã xác nhận nhận tài liệu.', actorDisplay: 'Bạn B (demo)'),
    TransactionEventItem(id: 'evt-sell-01', transactionId: 'txn-sell-01',
      eventType: 'REQUEST_ACCEPTED', serverAt: DateTime.utc(2026, 11, 20, 10),
      safeDescription: 'A đã duyệt yêu cầu mua.', actorDisplay: 'Bạn A (demo)'),
    TransactionEventItem(id: 'evt-sell-02', transactionId: 'txn-sell-01',
      eventType: 'PAYMENT_REPORTED', serverAt: DateTime.utc(2026, 11, 21),
      safeDescription: 'B báo đã chuyển khoản. Chờ A kiểm tra và xác nhận.',
      actorDisplay: 'Bạn B (demo)'),
    TransactionEventItem(id: 'evt-delivery-01', transactionId: 'txn-delivery-01',
      eventType: 'REQUEST_ACCEPTED', serverAt: DateTime.utc(2026, 11, 20, 12),
      safeDescription: 'A đã duyệt yêu cầu nhận tặng.', actorDisplay: 'Bạn A (demo)'),
  ];

  // Chưa có Issue mẫu; module Issue sẽ bổ sung kịch bản riêng.
  static List<Issue> get issues => const [];

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

  // Thông báo khớp với sự kiện mẫu ở trên (người nhận là bên KHÔNG thực hiện).
  static List<AppNotification> get notifications => [
    AppNotification(id: 'notice-b-01', recipientId: userB,
      type: 'REQUEST_ACCEPTED',
      entityType: NotificationEntityType.transaction,
      entityId: 'txn-borrow-01',
      safePreview: 'Giáo trình Giải tích: A đã duyệt yêu cầu mượn.',
      createdAt: DateTime.utc(2026, 11, 20, 8),
      readAt: DateTime.utc(2026, 11, 20, 9)),
    AppNotification(id: 'notice-a-01', recipientId: userA,
      type: 'PAYMENT_REPORTED',
      entityType: NotificationEntityType.transaction,
      entityId: 'txn-sell-01',
      safePreview: 'Nhập môn Python: B báo đã chuyển khoản. '
          'Chờ A kiểm tra và xác nhận.',
      createdAt: DateTime.utc(2026, 11, 21)),
  ];
}
