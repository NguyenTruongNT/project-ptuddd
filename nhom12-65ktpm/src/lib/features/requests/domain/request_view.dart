import '../../../core/backend/workflow_json.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/exchange_request.dart';
import '../../../core/contracts/repositories/request_repository.dart';

/// Vai trò của người đang xem đối với một Request (server tính, client không tự suy).
enum RequestViewerRole {
  owner('OWNER'),
  requester('REQUESTER');

  const RequestViewerRole(this.wire);
  final String wire;
}

/// Thao tác server cho phép trên Request. Chỉ là gợi ý hiển thị nút;
/// mọi command vẫn được RPC kiểm tra lại quyền và trạng thái.
enum RequestAction {
  approve('CAN_APPROVE_REQUEST'),
  reject('CAN_REJECT_REQUEST'),
  cancel('CAN_CANCEL_REQUEST');

  const RequestAction(this.wire);
  final String wire;
}

/// Read model SCR-12 (RequestSummary trong CONTRACTS.md), riêng module Request.
///
/// Không thay contract chung [ExchangeRequest]; chỉ bổ sung dữ liệu hiển thị
/// mà RPC `get_my_exchange_requests` đã trả về.
class RequestView {
  const RequestView({
    required this.request,
    required this.materialTitle,
    required this.materialSubject,
    required this.offerType,
    required this.ownerDisplayName,
    required this.requesterDisplayName,
    required this.viewerRole,
    required this.allowedActions,
    this.decidedAt,
    this.rejectReason,
  });

  final ExchangeRequest request;
  final String materialTitle;
  final String materialSubject;
  final OfferType offerType;
  final String ownerDisplayName;
  final String requesterDisplayName;
  final RequestViewerRole viewerRole;
  final Set<RequestAction> allowedActions;
  final DateTime? decidedAt;
  final String? rejectReason;

  String get id => request.id;
  String get listingId => request.listingId;
  ExchangeRequestStatus get status => request.status;
  DateTime get createdAt => request.createdAt;
  int? get requestedBorrowDays => request.requestedBorrowDays;

  bool get isIncoming => viewerRole == RequestViewerRole.owner;
  bool can(RequestAction action) => allowedActions.contains(action);
}

/// Repository dùng cho màn hình Request: giữ contract chung và thêm read model SCR-12.
abstract interface class RequestCenterRepository implements RequestRepository {
  Future<List<RequestView>> getMyRequestViews();
}

/// Giải mã một phần tử của `get_my_exchange_requests` / `data` của receipt Request.
RequestView requestViewFromRpc(Object? raw) {
  final value = WorkflowJson.object(raw);
  final roleWire = WorkflowJson.text(value['viewerRole']);
  final role = RequestViewerRole.values.firstWhere(
    (r) => r.wire == roleWire,
    orElse: () => throw const FormatException('Unknown viewerRole'),
  );
  final actions = <RequestAction>{};
  for (final item in WorkflowJson.list(value['allowedActions'])) {
    final wire = WorkflowJson.text(item);
    for (final action in RequestAction.values) {
      // Action lạ từ server bị bỏ qua: không hiện nút cho thao tác chưa hỗ trợ.
      if (action.wire == wire) actions.add(action);
    }
  }
  return RequestView(
    request: ExchangeRequest(
      id: WorkflowJson.text(value['id']),
      listingId: WorkflowJson.text(value['listingId']),
      requesterId: WorkflowJson.text(value['requesterId']),
      status: ExchangeRequestStatus.fromWire(
        WorkflowJson.text(value['status']),
      ),
      createdAt: WorkflowJson.timestamp(value['createdAt']),
      requestedBorrowDays: WorkflowJson.optionalInteger(
        value['requestedBorrowDays'],
      ),
    ),
    materialTitle: WorkflowJson.text(value['materialTitle']),
    materialSubject: WorkflowJson.text(value['materialSubject']),
    offerType: OfferType.fromWire(WorkflowJson.text(value['offerType'])),
    ownerDisplayName: WorkflowJson.text(value['ownerDisplayName']),
    requesterDisplayName: WorkflowJson.text(value['requesterDisplayName']),
    viewerRole: role,
    allowedActions: Set.unmodifiable(actions),
    decidedAt: WorkflowJson.optionalTimestamp(value['decidedAt']),
    rejectReason: WorkflowJson.optionalText(value['rejectReason']),
  );
}
