// Các giá trị bên dưới phải khớp với SS-BR v2.0 và STATE_MACHINES.md.
// Không bổ sung RESERVED, OVERDUE hay NEEDS_RESOLUTION vào status:
// đó là các nhãn dẫn xuất từ dữ liệu server.

T _fromWire<T>(List<T> choices, String raw, String Function(T) wireOf) {
  for (final choice in choices) {
    if (wireOf(choice) == raw) return choice;
  }
  throw FormatException('Giá trị trạng thái không hợp lệ: $raw');
}

enum OfferType {
  borrow('BORROW'), sell('SELL'), donate('DONATE');
  const OfferType(this.wire);
  final String wire;
  static OfferType fromWire(String raw) =>
      _fromWire(values, raw, (value) => value.wire);
}

enum ListingStatus {
  draft('DRAFT'), published('PUBLISHED'), hidden('HIDDEN'), archived('ARCHIVED');
  const ListingStatus(this.wire);
  final String wire;
  static ListingStatus fromWire(String raw) =>
      _fromWire(values, raw, (value) => value.wire);
}

enum ExchangeRequestStatus {
  pending('PENDING'), accepted('ACCEPTED'), rejected('REJECTED'), cancelled('CANCELLED');
  const ExchangeRequestStatus(this.wire);
  final String wire;
  static ExchangeRequestStatus fromWire(String raw) =>
      _fromWire(values, raw, (value) => value.wire);
}

enum TransactionStatus {
  awaitingPayment('AWAITING_PAYMENT'),
  awaitingHandover('AWAITING_HANDOVER'),
  handoverInProgress('HANDOVER_IN_PROGRESS'),
  borrowing('BORROWING'),
  returnPending('RETURN_PENDING'),
  returnInProgress('RETURN_IN_PROGRESS'),
  completed('COMPLETED'),
  cancelled('CANCELLED');
  const TransactionStatus(this.wire);
  final String wire;
  static TransactionStatus fromWire(String raw) =>
      _fromWire(values, raw, (value) => value.wire);

  // Chỉ giúp hiển thị và tạo fixture; không dùng thay kiểm tra transaction ở server.
  bool get isTerminal => this == completed || this == cancelled;
}

enum HandoverStatus {
  pending('PENDING'),
  awaitingReceiverConfirmation('AWAITING_RECEIVER_CONFIRMATION'),
  confirmed('CONFIRMED'),
  disputed('DISPUTED');
  const HandoverStatus(this.wire);
  final String wire;
  static HandoverStatus fromWire(String raw) =>
      _fromWire(values, raw, (value) => value.wire);
}

enum DeliveryTaskStatus {
  open('OPEN'), assigned('ASSIGNED'), pickedUp('PICKED_UP'),
  deliveryPendingConfirmation('DELIVERY_PENDING_CONFIRMATION'),
  completed('COMPLETED'), failed('FAILED'), cancelled('CANCELLED');
  const DeliveryTaskStatus(this.wire);
  final String wire;
  static DeliveryTaskStatus fromWire(String raw) =>
      _fromWire(values, raw, (value) => value.wire);
}

enum DeliveryApplicationStatus {
  pending('PENDING'), accepted('ACCEPTED'), rejected('REJECTED'), withdrawn('WITHDRAWN');
  const DeliveryApplicationStatus(this.wire);
  final String wire;
  static DeliveryApplicationStatus fromWire(String raw) =>
      _fromWire(values, raw, (value) => value.wire);
}

enum IssueStatus {
  open('OPEN'), resolved('RESOLVED');
  const IssueStatus(this.wire);
  final String wire;
  static IssueStatus fromWire(String raw) =>
      _fromWire(values, raw, (value) => value.wire);
}

// Loại sự cố để phân loại và hiển thị; KHÔNG quyết định trạng thái hay chủ sở hữu.
// SS-BR v2.0 chưa khóa danh sách; đây là bộ tối thiểu cho MVP, chờ nhóm trưởng duyệt.
enum IssueType {
  wrongMaterial('WRONG_MATERIAL'),
  wrongCondition('WRONG_CONDITION'),
  notReceived('NOT_RECEIVED'),
  deliveryFailed('DELIVERY_FAILED'),
  uncooperative('UNCOOPERATIVE'),
  other('OTHER');
  const IssueType(this.wire);
  final String wire;
  static IssueType fromWire(String raw) =>
      _fromWire(values, raw, (value) => value.wire);
}
