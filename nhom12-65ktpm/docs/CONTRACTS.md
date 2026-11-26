# STUDYSHARE — SHARED DATA & API CONTRACTS

> **Mã:** SS-TECH-02 · **Phiên bản:** 0.2 — đã được nhóm trưởng duyệt định hướng; đồng bộ README (CHƯA chạy SQL hoặc Flutter)  
> **Vị trí dự kiến:** `nhom12-65ktpm/docs/CONTRACTS.md`  
> **Vị trí mã nguồn sẽ tạo:** `nhom12-65ktpm/src/` theo `README.md` giảng viên; SQL migrations ở `src/supabase/migrations/`, Dart DTO/interfaces ở `src/lib/core/contracts/`. Không đặt source code trong `docs/` hoặc `nhom12-65ktpm/app/`.
> **Nguồn nghiệp vụ:** SS-BR `QUY_TAC_NGHIEP_VU.md` v2.0, đặc biệt §1–4, §11–14. Trạng thái tham chiếu `STATE_MACHINES.md`.

## 1. Quy tắc chung

- **Tên kỹ thuật dưới đây là đề xuất:** dùng `snake_case` cho SQL/RPC, `UpperCamelCase` cho Dart type và `lowerCamelCase` cho property Dart. Chỉ khóa tên sau review của nhóm trưởng.
- `id` UUID, ngày giờ ghi bằng `timestamptz` **do server**, mốc lịch hẹn/hạn trả theo `Asia/Ho_Chi_Minh` lưu bằng `date` khi nghiệp vụ tính theo ngày.
- `actor` lấy từ `auth.uid()`, **không tin** `actor_id` trong payload do client tự gửi.
- Một người có thể là A/B/C trong các giao dịch khác nhau; không dùng `globalRole='COURIER'` như căn cứ quyền.
- Material = một bản vật lý; Listing = một lần công bố; Request = đề nghị; Transaction = thỏa thuận đã được chấp thuận.
- `owner_id` và `holder_id` chỉ thay đổi qua lệnh nghiệp vụ hợp lệ, không có mutation cập nhật trực tiếp từ Flutter.
- Trạng thái như `RESERVED`, `OVERDUE`, `NEEDS_RESOLUTION`, `REHANDOVER_OVERDUE` là **nhãn dẫn xuất**, không được tự tạo enum `Listing.status`/`Transaction.status` mới.

## 2. Bảng dữ liệu tối thiểu và ràng buộc

| Table đề xuất | Field trọng tâm | Ràng buộc / diễn giải |
|---|---|---|
| `profiles` | `user_id PK/FK auth.users`, `display_name`, `created_at` | Một hồ sơ/tài khoản, chỉ cập nhật trường cho phép |
| `materials` | `id`, `owner_id`, `holder_id`, `title`, `subject`, `condition`, `isbn?`, `created_at` | Một bản vật lý; không cho update trực tiếp owner/holder từ client |
| `material_images` | `id`, `material_id`, `storage_path`, `display_order`, `uploaded_by` | Tối thiểu 1 ảnh khi công bố Listing; ảnh public/safe được phân biệt chứng cứ |
| `material_qr_credentials` | `material_id`, secret/token metadata | **Không cấp SELECT công khai**; token khó đoán/signed, kiểm tra server |
| `listings` | `id`, `material_id`, `offer_type`, `status`, `asking_price_vnd?`, `snapshot`, `published_at?` | 1 offer/Listing; `SELL` giá nguyên VND >0; 1 Listing chưa ARCHIVED của mỗi Material (đề xuất cần khóa) |
| `exchange_requests` | `id`, `listing_id`, `requester_id`, `requested_borrow_days?`, `status`, `created_at`, `decided_at?`, `reject_reason?` | BORROW 1–30; 1 PENDING/người/Listing; owner không gửi cho mình |
| `transactions` | `id`, `listing_id`, `request_id`, `material_id`, `type`, `owner_at_acceptance`, `receiver_id`, `status`, `agreed_borrow_days?`, `agreed_price_vnd?`, timestamps | Có **tối đa một** active Transaction mỗi Material; snapshot điều kiện tại lúc duyệt |
| `borrowing_records` | `transaction_id PK`, `started_at?`, `due_date?`, `return_to_courier_at?`, `final_return_confirmed_at?`, `re_handover_due_date?` | Chỉ BORROW; due_date là ngày VN bắt đầu từ receiver B ACK |
| `payment_confirmations` | `transaction_id PK`, `amount_vnd`, `buyer_reported_at?`, `seller_confirmed_at?`, `refund_proposed_at?`, `buyer_refund_confirmed_at?` | Chỉ SELL; B báo chuyển không tương đương A xác nhận |
| `delivery_tasks` | `id`, `transaction_id`, `sender_id`, `final_receiver_id`, `assigned_courier_id?`, `status`, pickup/dropoff descriptions, optional coords, `return_handover_id?` | Người tạo là người đang gửi; chọn đúng một C |
| `delivery_applications` | `id`, `task_id`, `applicant_id`, `status`, `created_at` | UNIQUE(task_id, applicant_id), tối đa một ACCEPTED/task |
| `handovers` | `id`, `transaction_id`, `delivery_task_id?`, `from_user_id`, `to_user_id`, `status`, `verification_method?`, `fallback_reason?`, server timestamps | Mỗi chặng có ID; không tạo hai chặng hoạt động trùng mục đích |
| `handover_evidence` | `id`, `handover_id`, `uploaded_by`, `private_path`, `uploaded_at`, `sensitivity` | ≥1 ảnh từ đúng `from_user_id` khi chuyển sang awaiting receiver |
| `issues` | `id`, `transaction_id`, `handover_id?`, `reporter_id`, `type`, `reason`, `status`, `opened_at`, `resolved_at?` | `OPEN/RESOLVED`; không rollback lịch sử vật lý; `handover_id` phải thuộc `transaction_id` |
| `issue_resolution_proposals` | `issue_id`, `revision`, `summary`, `proposed_by`, `proposed_at` | Bản phương án hiện hành; mỗi lần đề xuất tăng `revision` (xem §5.1) |
| `issue_consents` | `issue_id`, `participant_id`, `resolution_revision`, `approved_at` | Mỗi bên bị ảnh hưởng trực tiếp một dòng cho đúng revision; UNIQUE(issue_id, participant_id, resolution_revision) |
| `transaction_events` | `id`, `transaction_id`, `actor_id?`, `event_type`, `payload_safe`, `server_at`, `source_action_id` | Append-only; actor snapshot; phục vụ timeline/notifications |
| `notifications` | `id`, `recipient_id`, `type`, `entity_type`, `entity_id`, `created_at`, `read_at?`, `preview_safe` | Read per recipient; deep link kiểm tra lại quyền |
| `courier_ratings` | `task_id`, `rater_id`, `stars`, `created_at` | 1–5; UNIQUE(task_id,rater_id); A/B độc lập, tùy chọn |
| `command_receipts` | `actor_id`, `command_name`, `idempotency_key`, `payload_hash`, `result_json`, `created_at` | UNIQUE(actor, command, key); retry cùng payload không nhân bản tác động |

> **Lưu ý schema:** đây là **logical schema**, không phải migration chạy được. Các field snapshot và cấu trúc JSON phải được chốt có kiểu rõ trước khi phát triển DB. Các bảng phân quyền bằng chứng mức nhạy cảm cao và export nâng cao chỉ tạo khi mở scope, không bắt buộc demo MVP.

### Chỉ mục/ràng buộc bắt buộc về mặt kết quả

1. **At most one active Transaction/Material:** unique partial constraint/index cho các `Transaction.status` chưa `COMPLETED/CANCELLED`, hoặc cơ chế lock + constraint tương đương. Đây là bất biến database, không chỉ kiểm tra client.
2. **Chỉ một Request ACCEPTED/Listing:** unique partial index cho status `ACCEPTED`, kết hợp transaction approve atomic.
3. **Chỉ một Request PENDING/(listing, requester):** unique partial index cho status `PENDING`.
4. **Chỉ một courier ACCEPTED/Task:** unique partial index; `delivery_tasks.assigned_courier_id` không thể bất đồng với application đã ACCEPTED.
5. **Courier rating:** unique (task_id, rater_id), stars từ 1–5.
6. **Chống duplicate event:** unique `source_action_id` theo phạm vi lệnh hoặc ràng buộc key.
7. **Thanh toán:** nếu `transactions.type=SELL`, `agreed_price_vnd > 0` và khớp snapshot; DONATE/BORROW không ghi giá như dữ liệu thanh toán.
8. **Evidence:** `handover_evidence.uploaded_by` phải bằng `handovers.from_user_id` theo nghiệp vụ server, không chỉ dựa vào khóa ngoại.
9. **Handover participant:** from = current recorded holder tại lúc tạo chặng; to = người được chỉ định, cả hai phải thuộc ngữ cảnh hợp lệ.

## 3. Những DTO đọc dùng chung

DTO là dữ liệu bất biến phục vụ màn hình; **không** đưa row database nguyên vẹn lên UI. Các field dưới đây là dự kiến.

| Dart DTO | Trường cần có | Màn hình tiêu thụ |
|---|---|---|
| `MaterialSummary` | id, title, subject, cover, owner/holder display-safe, `availabilityLabel` dẫn xuất, canPublish | SCR-07/09 |
| `ListingCardModel` | listingId, title, image, offerType, askingPrice, condition, `isRequestable`, statusLabel | SCR-04/05 |
| `ListingDetails` | `ListingCardModel` + mô tả, owner public summary, ảnh, chính sách mượn | SCR-06/11 |
| `RequestSummary` | requestId, listingId, requester public name, days?, status, requestedAt, allowedActions | SCR-12 |
| `TransactionDetails` | id, type, status, A/B safe summary, material, BORROW due?, payment flag, allowedActions | SCR-13/14 |
| `TransactionEventItem` | eventId, eventType, serverAt, actorDisplay, safeDescription | SCR-14/23 |
| `DeliveryTaskDetails` | id, status, sender/final receiver, pickup/dropoff **scoped**, applicants allowed, current leg | SCR-15/17 |
| `HandoverDetails` | id, leg, from/to display, status, verificationResult, evidence access info, allowedActions | SCR-18/20 |
| `IssueDetails` | `issue` (id, transactionId, handoverId?, reporterId, type, reason, status, openedAt, resolvedAt?), `materialTitle`, tên người báo/đối diện, `relation` (REPORTER/COUNTERPARTY), `proposal?` (revision, summary, người đề xuất, danh sách consent theo từng bên), `evidenceCount`, `canViewEvidence`, `canViewTransaction`, `allowedActions` (`CAN_PROPOSE_ISSUE_RESOLUTION`, `CAN_CONFIRM_ISSUE_RESOLUTION`) | SCR-21/23 |
| `IssueEventItem` | id, issueId, eventType, serverAt, actorDisplay?, safeDescription | SCR-23 |
| `NotificationItem` | id, safePreview, createdAt, readAt?, resourceRef | SCR-24 |

**Allowed actions:** Server có thể trả danh sách action cho actor (`CAN_APPROVE_REQUEST`, `CAN_CONFIRM_HANDOVER`, …) để hỗ trợ UI, nhưng RPC **vẫn phải kiểm tra lại** quyền và trạng thái khi thực thi. `can*` của client không phải quyết định cuối.

## 4. Repository interfaces ở Flutter

Các interface sau để bốn feature không phụ thuộc cách gọi Supabase cụ thể. Ví dụ chữ ký Dart **mang tính phác thảo**:

```dart
abstract interface class RequestRepository {
  Future<CommandResult<RequestSummary>> createRequest(
    CreateRequestInput input, {required String idempotencyKey});
  Future<CommandResult<TransactionDetails>> approveRequest(
    String requestId, {required String idempotencyKey});
  Future<CommandResult<RequestSummary>> rejectRequest(
    String requestId, String reason, {required String idempotencyKey});
}

abstract interface class HandoverRepository {
  Future<CommandResult<HandoverDetails>> submitEvidence(
    SubmitHandoverEvidenceInput input, {required String idempotencyKey});
  Future<CommandResult<TransactionDetails>> confirmReceipt(
    String handoverId, {required String idempotencyKey});
  Future<CommandResult<IssueDetails>> refuseReceipt(
    RefuseHandoverInput input, {required String idempotencyKey});
}

sealed class CommandResult<T> {}
class CommandOk<T> extends CommandResult<T> {
  CommandOk(this.data, this.serverEventId);
  final T data;
  final String serverEventId;
}
class CommandError<T> extends CommandResult<T> {
  CommandError(this.code, this.safeMessage);
  final DomainErrorCode code;
  final String safeMessage;
}
```

```dart
// Issue (đã cài trong src/lib/core/contracts/repositories/issue_repository.dart).
abstract interface class IssueQueryRepository {
  Future<List<IssueDetails>> getMyIssues();                    // Chỉ Issue actor được ĐỌC.
  Future<IssueDetails?> getIssueDetails(String issueId);       // null: không tồn tại HOẶC không có quyền.
  Future<List<IssueEventItem>> getTimeline(String issueId);    // Tăng dần theo serverAt; [] khi không có quyền.
}

abstract interface class IssueRepository {
  Future<CommandResult<IssueDetails>> reportIssue(
    CreateIssueInput input, {required String idempotencyKey}); // input: transactionId, type, reason, handoverId?
  Future<CommandResult<IssueDetails>> proposeResolution(
    String issueId, String summary, {required String idempotencyKey});
  Future<CommandResult<IssueDetails>> confirmResolution(
    String issueId, int resolutionRevision, {required String idempotencyKey});
}
```

Các interface khác: `MaterialRepository`, `ListingRepository`, `ListingQueryRepository`, `BorrowRepository`, `TransactionRepository`, `DeliveryRepository`, `EvidenceRepository`, `NotificationRepository`.

## 5. Command contract và điểm chuyển trách nhiệm

| Use case / tên client | Tác động cần nguyên tử ở server | Chủ trì phối hợp |
|---|---|---|
| `createMaterial` / `publishListing` | Chỉ owner có quyền; QR/Listing hợp lệ; không trùng Listing hiện hành | Trường |
| `createExchangeRequest` | Listing PUBLISHED + Material khả dụng + không trùng PENDING | Khanh |
| `approveExchangeRequest` | Lock Material; 1 ACCEPTED; các PENDING khác REJECTED; tạo T; snapshot; Event | Khanh + Sơn |
| `requestBorrowReturn` | BORROW hợp lệ; chỉ ghi ý định/trạng thái trả; không sửa holder | Khanh |
| `confirmSellerPayment` | Chỉ A; SELL đã duyệt; tiền xác nhận đúng một lần; mở giai đoạn giao | Sơn |
| `createDeliveryTask` | Người tạo là current giver; đúng chặng; không Task cạnh tranh | Đăng |
| `applyForDelivery` / `selectCourier` | Đúng quyền; chọn 1 C nguyên tử; từ chối các ứng viên còn lại | Đăng |
| `createHandover` | Đúng current holder, receiver, leg; SELL đã xác nhận tiền | Đăng + Sơn |
| `verifyMaterialCode` | Server so Material/leg; QR mismatch hard block; fallback chỉ khi thiếu/không đọc được | Đăng |
| `submitHandoverEvidence` | Giver đúng actor; private storage ACK; ≥1 ảnh + QR/fallback hợp lệ → awaiting | Đăng |
| `confirmHandover` | Receiver đúng actor; Handover awaiting; đổi holder + event + Transaction/Task transition | Đăng + Sơn |
| `refuseHandover` / `reportIssue` | Ghi Issue, Handover DISPUTED nếu chưa nhận; không đổi holder | Sơn + Đăng |
| `proposeIssueResolution` / `confirmIssueResolution` | Snapshot proposal/revision; xác nhận các bên ảnh hưởng (xem §5.1); không ép giải quyết | Sơn |
| `proposeTransactionCancellation` / `acceptTransactionCancellation` | Hai bên đồng thuận; kiểm tra nghĩa vụ sách/tiền/Issue; archive Listing an toàn | Sơn |
| `getTransactionTimeline` | Chỉ actor thuộc transaction; event details đã loại PII | Sơn |

### Quy ước tên server RPC đề xuất

`approve_exchange_request`, `confirm_seller_payment`, `select_courier`, `create_handover`, `verify_material_code`, `submit_handover_evidence`, `confirm_handover`, `refuse_handover`, `request_borrow_return`, `confirm_issue_resolution`, `accept_transaction_cancellation`. **Không buộc mỗi use case là một RPC riêng**, nhưng mọi mutation xuyên bảng phải là server-side atomic command.

**Thiết kế nhận input:** client gửi ID, payload nghiệp vụ, `idempotency_key`, phiên Supabase Auth; **không** gửi actor/owner/holder/status mới. Server lấy actor từ `auth.uid()` và tự đọc bản ghi mới nhất dưới lock phù hợp.

### 5.1 Issue: người liên quan, revision và consent (đề xuất, chữ ký chưa khóa)

**Người liên quan được suy ra theo từng Issue**, không mặc định luôn là A và B, và không dựa vào `globalRole`:

| Khái niệm | Quy tắc |
|---|---|
| Bên bị ảnh hưởng trực tiếp | Issue gắn `handover_id`: hai đầu của chặng đó (`from_user_id`, `to_user_id`). Issue cấp giao dịch: A và B. Luôn gồm cả người báo. |
| ĐỌC (`getMyIssues`/`getIssueDetails`/`getTimeline`) | A/B của giao dịch **và** các bên bị ảnh hưởng trực tiếp. C chỉ đọc khi là một đầu của đúng chặng; C ở chặng/task khác và người ngoài nhận `null`/`[]`, không phân biệt "không tồn tại" với "không có quyền". |
| MỞ Issue (`reportIssue`) | A/B của giao dịch, hoặc một đầu của `handover_id` được gắn vào (vd. C từ chối nhận ở chặng A→C). Không có `handover_id` thì C không mở được. |
| ĐỀ XUẤT / XÁC NHẬN | Chỉ bên bị ảnh hưởng trực tiếp. Bên chỉ đọc (vd. A khi Issue thuộc chặng C→B mà A không báo) không có action. |
| `canViewTransaction` | `false` với người không phải A/B (C): UI không hiện lối tắt sang SCR-14. |

**Revision và consent:**

1. `proposeResolution` tạo bản phương án mới với `revision = revision cũ + 1`; mọi consent của revision cũ mất hiệu lực. Đề xuất **không** tự là consent của người đề xuất: mỗi bên (kể cả người đề xuất) xác nhận riêng.
2. `confirmResolution(issueId, revision)` chỉ hợp lệ khi `revision` bằng revision hiện hành; sai revision trả `CONFLICT`. Chưa có phương án, đã xác nhận rồi, hoặc Issue đã `RESOLVED` trả `INVALID_TRANSACTION_TRANSITION`.
3. Server chỉ chuyển `OPEN → RESOLVED` khi **mọi** bên bị ảnh hưởng trực tiếp đã xác nhận đúng revision hiện hành; moderator/admin không đóng thay.
4. `reportIssue`: `reason` không rỗng (≤ 1000 ký tự); giao dịch `CANCELLED` không nhận Issue; sau `COMPLETED` chỉ khởi tạo trong **7 ngày lịch Việt Nam** (hết ngày thứ 7). Lệnh không đổi owner/holder/`due_date`/payment/`Transaction.status` (INV-10), chỉ ghi Issue + Event.
5. Sau mỗi lệnh server trả `IssueDetails` mới nhất; client tải lại, không tự sửa state.

**`IssueType` (ĐỀ XUẤT của module Sơn, CHƯA được nhóm trưởng duyệt, SS-BR v2.0 chưa khóa danh sách):** `WRONG_MATERIAL`, `WRONG_CONDITION`, `NOT_RECEIVED`, `DELIVERY_FAILED`, `UNCOOPERATIVE`, `OTHER`. Loại chỉ để phân loại/hiển thị, không quyết định trạng thái hay chủ sở hữu. Nếu nhóm trưởng đổi danh sách, cập nhật `IssueType` trong `domain_enums.dart` và CHECK constraint tương ứng.

**Giới hạn của bản mock (không phải backend thật):**
- Mốc "hoàn tất" để tính hạn 7 ngày lấy từ sự kiện mới nhất (bỏ qua `ISSUE_*`) của giao dịch; server thật phải dùng thời điểm ACK cuối cùng.
- Mock chưa có ảnh bằng chứng (`evidenceCount = 0`, `canViewEvidence = false`); phần này thuộc `EvidenceRepository`/module Handover.
- Chặng bàn giao do `MockTransactionStore.seedHandovers`/`MockFixtures.handovers` cung cấp; module Handover thật sẽ ghi các chặng này.
- SCR-22 hiện lấy tên tài liệu từ giao dịch nên C (không đọc được giao dịch) chưa mở được Issue bằng form; lệnh `reportIssue` đã hỗ trợ C theo chặng. Cần phối hợp với Đăng khi làm luồng từ chối nhận (SCR-20).
- Supabase phải thực thi lại toàn bộ quy tắc ở RLS/RPC; mock chỉ để UI và test dùng chung.

## 6. Error contract

| `DomainErrorCode` từ SS-BR | UI response |
|---|---|
| `AUTH_REQUIRED` | Điều hướng login, bảo toàn route dự định an toàn |
| `FORBIDDEN` | Không có quyền; không hiển thị chi tiết nhạy cảm |
| `INVALID_INPUT` | Lỗi theo field, giữ dữ liệu đang nhập |
| `MATERIAL_UNAVAILABLE`, `CONFLICT` | Refresh server snapshot, nhãn Đã được đặt hoặc đã thay đổi |
| `DUPLICATE_REQUEST`, `DUPLICATE_ACTIVE_TRANSACTION` | Hiện bản ghi hiện có, không gửi lại bừa |
| `REQUEST_NOT_PENDING` | Yêu cầu đã xử lý, refresh |
| `INVALID_TRANSACTION_TRANSITION` | Trạng thái đã thay đổi, mở timeline |
| `INVALID_HANDOVER_PARTICIPANT` | Không đúng người giao/nhận, chặn |
| `QR_MISMATCH` | **Hard block**, không fallback manual |
| `EVIDENCE_REQUIRED`, `EVIDENCE_UPLOAD_FAILED` | Giữ nháp, retry upload có kiểm soát |
| `RECEIVER_CONFIRMATION_REQUIRED` | Chưa hoàn tất; đợi receiver đúng actor |
| `PAYMENT_NOT_CONFIRMED` | SELL chặn tất cả lượt giao |
| `ISSUE_BLOCKING_ACTION`, `CANCELLATION_OBLIGATION_PENDING` | Cảnh báo nghĩa vụ còn mở, hướng xử lý |
| `NETWORK_UNAVAILABLE` | Chỉ nháp/cache; không success |
| `TIMEOUT_UNKNOWN` *(lớp client)* | Kiểm tra theo idempotency key và tải lại server trước retry |

**Response chuẩn đề xuất:** `ok`, `data`, `event_id`, `server_revision`, `error.code`, `error.safe_message`. Lỗi nhạy cảm không trả thông tin của user khác. `TIMEOUT_UNKNOWN` không yêu cầu có trong SQL enum vì có thể phát sinh ở transport layer.

## 7. Idempotency, concurrency, transaction

**Lược đồ bắt buộc về logic cho mutation quan trọng:**

1. Xác thực JWT → `auth.uid()` không null → kiểm tra quyền actor.
2. Đọc `(actor, command, idempotency_key)` và hash payload; nếu đã thành công trả kết quả cũ; nếu key trùng payload khác → CONFLICT.
3. Khóa row liên quan trong DB transaction (`FOR UPDATE` theo thứ tự nhất quán) và kiểm tra trạng thái mới nhất.
4. Thực hiện toàn bộ thay đổi domain cùng lúc: trạng thái, holder/owner, snapshot, Event, notification queue, command receipt.
5. Commit → trả ACK + event ID; lỗi → rollback toàn bộ.
6. Client timeout/đứt mạng: query lại theo key / đọc server snapshot; **không tự nhận đã thành công**.

**Ví dụ approve:** request R2 + Material M → trong **một** transaction: R2 ACCEPTED, các request PENDING cạnh tranh REJECTED, T tạo, Material bị giữ bởi active T, Event một lần. Race R1/R2 có nhiều request nhưng tối đa một T active.

## 8. RLS & privacy access matrix (đề xuất tối thiểu)

| Dữ liệu | Người khác | A owner / B requester | C được chọn | Quy tắc |
|---|---|---|---|---|
| Discovery Listing PUBLISHED | Xem thông tin công khai an toàn | Như public + quyền của mình | Như public | PUBLISHED+RESERVED vẫn hiện, không lộ QR |
| `materials` owner/holder | **Không SELECT toàn row** | Đọc thông tin theo quyền | Chỉ thông tin cần cho chặng | Tách private QR secret |
| Request | Không | Requester xem bản thân; owner xem yêu cầu gửi tới Listing của mình | Không | Thời gian server |
| Transaction / Event | Không | A/B theo Transaction | Chỉ phần thuộc task/chặng | Không lộ dữ liệu ngoài nhiệm vụ |
| DeliveryTask OPEN | Xem tóm tắt phục vụ ứng tuyển khi đăng nhập | Người tạo xem chi tiết | Người đã được chọn xem điểm hẹn phù hợp | Không GPS/địa chỉ chi tiết trước khi chọn |
| Handover | Không | Xem theo chặng/quan hệ | Chỉ chặng giao C | Giver/receiver mới được mutate đúng bước |
| Evidence Handover | Không | Chỉ ảnh cho phép theo vai trò | Chỉ ảnh liên quan chặng C | Private bucket + signed URL ngắn hạn |
| Issue/Evidence | Không | A/B của giao dịch đọc; chỉ bên bị ảnh hưởng trực tiếp mới đề xuất/xác nhận (§5.1) | Chỉ Issue gắn đúng chặng C tham gia; không đọc giao dịch | Cấp cao cần cấp quyền riêng |
| Notification | Không | Chỉ `recipient_id = auth.uid()` | Chỉ của chính C | Không để private payload trong preview |
| Payment | Không | A/B thuộc SELL hợp lệ | Không | Ngân hàng ngoài app, không OTP |

**Phải kiểm thử các vai trò:** A/B/C/người lạ; Request của người khác; C task khác; ảnh private; người vừa mất quyền; session hết hạn; user metadata giả mạo. **Không dùng một policy `authenticated can select all` trên bảng chứa PII.**

## 9. QR, camera và Storage

- QR Material: token khó đoán, có nguồn server và kiểm tra server; QR không đủ tự xác nhận đã giao/nhận.
- **Không** để `qr_token` ở DTO hoặc view Discovery. Phải tách bảng credential/secret hoặc RPC tạo mã có kiểm soát để chủ sở hữu có thể hiển thị QR.
- Trường hợp **QR đọc được sai** trả `QR_MISMATCH` và chặn; không cho manual override.
- **Chỉ** QR mất/không đọc được mới cho fallback kèm lý do và kiểm tra đối tượng server.
- Evidence: giver chụp ≥1 ảnh **từng lượt**, upload bucket private, `storage_path` không phát cho người không có quyền. Photo local ≠ Evidence server.
- Người nhận designated receiver là người duy nhất được confirm, server ACK đổi holder.
- Tệp ảnh raw chỉ nên được đọc qua scoped access; không đặt URL signed dài hạn vào SQLite cache hoặc notification payload.

## 10. Offline/draft contract

- Drift lưu `draft_id`, `owner_user_id`, `entity_type`, `entity_local_payload`, `local_photo_paths`, `upload_state`, `last_updated_at`; trạng thái chỉ là `DRAFT_LOCAL`, `QUEUED_UPLOAD`, `FAILED_UPLOAD`, `SYNCED_EVIDENCE` (đề xuất UI/local, không phải trạng thái Domain của Handover).
- Chỉ upload khi app mở/có mạng/quyền hợp lệ; retry cùng idempotency key; có thể cho hủy/xóa bản nháp local.
- Offline **không** nhận Request, approve, confirm, payment, Issue resolved hoặc holder update là thành công.
- Khi đổi tài khoản/đăng xuất, tách/xóa dữ liệu bản nháp nhạy cảm và xác minh quyền trước khi upload.

## 11. Test contracts tối thiểu

| ID | Test server/contract | Kết quả bắt buộc |
|---|---|---|
| CT-01 | A tạo 2 Material cùng tên | Hai ID/QR khác nhau |
| CT-02 | 2 A-side approve cùng Material chạy đồng thời | Chỉ một thành công, đúng một T active |
| CT-03 | Listing PUBLISHED, Material RESERVED | Search thấy nhưng Request RPC từ chối |
| CT-04 | B tạo Request trùng PENDING | Một Request, duplicate lỗi rõ |
| CT-05 | SELL chưa seller-confirm, thử Handover | Từ chối `PAYMENT_NOT_CONFIRMED` |
| CT-06 | QR đọc được nhưng sai | `QR_MISMATCH`, không manual fallback |
| CT-07 | Handover thiếu giver photo | Không awaiting/confirmed, holder giữ nguyên |
| CT-08 | Giver tự gọi confirm thay receiver | `INVALID_HANDOVER_PARTICIPANT` |
| CT-09 | B ACK BORROW | Đúng started_at/due_date lịch Việt Nam |
| CT-10 | B→C chiều trả, A chưa ACK | Transaction chưa COMPLETED, không tính sai overdue gốc |
| CT-11 | C→B phục hồi chiều trả | Có re-handover deadline 3 ngày riêng |
| CT-12 | B ACK cuối SELL/DONATE | Owner thay đổi chỉ khi đủ điều kiện |
| CT-13 | Issue mở trước/sau nhận | Không tự sửa owner/holder/payment/due |
| CT-14 | Caller không liên quan xem private image | Server deny |
| CT-15 | Retry cùng idempotency key sau timeout | Không double event/holder update |
| CT-16 | 2 ứng viên C được chọn đồng thời | Chỉ một ACCEPTED |

## 12. Gate trước khi triển khai migration/code

Các contracts Auth/Profile bổ sung ở mục 13; không thay đổi enum hoặc quyền của các module giao dịch.

- [x] Nhóm trưởng đã duyệt định hướng `CONTRACTS.md` và `STATE_MACHINES.md` trên cơ sở SS-BR v2.0; bản v0.2 điều chỉnh vị trí mã nguồn theo README.
- [ ] Khóa exact SQL schema/migration và RPC input/output types.
- [ ] Khóa query public read vs private row access; không làm lộ QR secret.
- [ ] Thử RLS với A/B/C/người lạ bằng môi trường riêng, không dùng dữ liệu cá nhân thật.
- [ ] Chốt `pubspec.yaml` và `pubspec.lock` khi tạo app, không đoán phiên bản package trong tài liệu.
- [ ] Mock repository chạy cùng interface và contract tests trước khi các thành viên triển khai UI chuyên biệt.

> **Tình trạng:** Bản kỹ thuật đã được nhóm trưởng duyệt định hướng, chưa khóa chữ ký SQL/RPC cụ thể. **Chưa có migration, RLS, RPC hoặc UI được chạy từ file này.**

## 13. Auth/Profile — contracts triển khai ngày 1

> Material ngày 2 được mô tả ở mục 14 bên dưới; không thay contract workflow của Khanh/Đăng/Sơn.

- `AuthRepository` cung cấp `watchSession`, `signIn`, `register`, `requestPasswordReset`, `resendConfirmation`, `completePasswordRecovery`, `signOut`; adapter Supabase là `AuthSessionService`.
- `AuthSnapshot` phân biệt chưa cấu hình, signed out, signed in, recovery và lỗi phiên. `AuthIdentity` chỉ gồm ID, email và tên hiển thị của chính người dùng; không chứa token. Actor thực tế ở server vẫn là `auth.uid()`.
- `register` nhận tên/email/password, trả `RegistrationOutcome.needsEmailConfirmation`. Session null không được coi là đăng ký đã xác thực. Password không được lưu vào preferences hoặc chuyển qua URL.
- Đăng ký/đặt mật khẩu mới: tối thiểu 8 ký tự, có A–Z, a–z, 0–9 và ít nhất một ký tự thuộc tập symbol của Supabase `lower_upper_letters_digits_symbols`. Form báo rõ điều kiện còn thiếu, xác nhận mật khẩu phải khớp, không mở confirm/gọi API khi sai. Supabase Auth local cưỡng chế cùng policy tại signup/updateUser; Cloud cần cấu hình riêng trước triển khai. Đăng nhập không áp policy tạo mới lên mật khẩu cũ; server xác thực thông tin đăng nhập. Email đúng định dạng ở client không thay thế bước xác minh email do server yêu cầu.
- Chỉ sự kiện `AuthChangeEvent.passwordRecovery` sau khi SDK xác minh liên kết mới bật form đổi mật khẩu. URL/query recovery do người dùng tự gửi không đủ cấp quyền. Đổi mật khẩu xong đăng xuất các phiên bằng server và yêu cầu đăng nhập lại.
- Callback Android: `studyshare://auth/callback`, được allowlist trong Auth. SDK sở hữu nhận và trao đổi PKCE; Flutter router không đọc/log code hoặc token. Các route phụ `/auth/forgot-password`, `/auth/check-email`, `/auth/reset-password` không tăng 26 SCR chính.
- Auth guard chỉ lưu đường dẫn nội bộ đã biết, loại query/fragment, từ chối external redirect. Khi đổi identity/logout, profile và cache mock riêng tư phải được tái tạo. Chế độ demo chỉ bật tường minh khi backend chưa cấu hình và phải có nhãn mô phỏng.
- `ProfileRepository.getOrCreateMyProfile` chỉ đọc/tạo hồ sơ của session hiện tại; `updateMyDisplayName` chỉ sửa tên 1–100 ký tự. Dùng SELECT/INSERT và column-grant UPDATE(display_name) đã có, với RLS self-only. Không cấp UPDATE(user_id), role hay trạng thái nghiệp vụ.
- Tên trong `user_metadata` chỉ là giá trị khởi tạo hiển thị, không dùng làm căn cứ phân quyền. Dữ liệu profile không được coi là đã lưu trước ACK server. Lỗi không trả message thô có thể chứa PII.
- Preferences chỉ lưu theme, palette, locale, grid/leaves trên thiết bị; Supabase SDK quản lý session. Các lựa chọn giao diện được ghi tuần tự để không mất thay đổi đồng thời.
- Kiểm thử: unit/widget Auth + guard + cache + preferences; pgTAP `03_profile_access.test.sql`; test local opt-in `test/integration/auth_local_test.dart` dùng Auth thật, RLS và trao đổi PKCE. Test local chỉ xóa UUID tài khoản giả do chính nó tạo, không dùng URL cloud hoặc service key.
- Kiểm thử policy riêng: `tool/test_password_policy_local.ps1` chạy `test/integration/password_policy_local_test.dart`, gọi trực tiếp SDK để kiểm tra server từ chối từng điều kiện còn thiếu ở signup/update, mật khẩu cũ vẫn dùng được sau yêu cầu đổi bị từ chối, mật khẩu mới hợp lệ mới thay thế mật khẩu cũ.

## 14. Material/ảnh — ngày 2, Trường duyệt 25/11/2026

- Giữ interface đọc cũ/constructor Material, fixture ID và workflow đồng đội. Thêm tùy chọn description/revision/updatedAt và summary fields. MaterialWorkspaceRepository mở rộng query/command: searchMaterials(query/filter/offset/limit), getDetails, uploadImage, createMaterial, updateMaterial(expectedRevision), discardUpload.
- MaterialDetails gồm Material, gallery theo thứ tự, tên owner/holder an toàn, listingStatus, hasActiveTransaction, editBlockedReason, isCached. Không QR/token/ngân hàng. CommandOk.receipt dùng commandId + serverRevision; serverEventId nullable vì Material chưa có Transaction. Constructor event cũ tiếp tục dùng cho Transaction/Issue.
- CreateMaterialInput thêm description/imageIds theo thứ tự, không actor/owner/holder/status/path. Material chưa đăng có 0–5 ảnh; bìa đầu tiên; publish Listing cần ít nhất một ảnh đã ghi nhận. Tên 1–200, môn/loại và tình trạng 1–100; mô tả tùy chọn 2.000; trim và chặn control; ISBN-10/13 có checksum, không unique.
- Chỉ owner sửa khi owner=holder, không Transaction active, Listing PUBLISHED hoặc Request PENDING. Server kiểm tra lại dưới row lock. Không ghi owner/holder qua lệnh lưu.

| RPC | Input / output |
|---|---|
| get_my_material | p_material_id → chi tiết của owner hoặc null |
| search_my_materials | p_query, p_filter (all/ready/active), p_offset, p_limit ≤1.000 → items, has_more |
| prepare_material_image | p_mime_type, p_byte_size, p_material_id? → upload ID/path, hạn 24 giờ |
| get_my_material_upload | p_image_id → đăng ký còn hợp lệ của chính actor |
| verify_material_image_upload | p_image_id, p_actor_id; chỉ service_role sau Edge kiểm tra file |
| save_material | p_payload, p_idempotency_key, p_material_id?, p_expected_revision? → Material + command_id + server_revision |
| get_material_command_result | p_command, p_key → receipt của actor còn sở hữu |
| discard_material_upload | Claim bỏ upload chưa gắn; không xóa ảnh ATTACHED/lịch sử |
| claim_expired_material_uploads / finish_material_upload_cleanup | Claim upload tạm hết hạn của actor / xác nhận path đã được xóa qua Storage API |

- Luồng: prepare → uploadBinary không upsert → Edge verify-material-image → save_material. JPEG/PNG/WebP tối đa 5 MiB; Edge xác thực JWT qua Auth, đọc file bằng quyền user và kiểm tra signature, cấu trúc/kích thước tối đa 40 triệu pixel. App cũng decode ảnh trước upload.
- Edge tắt gateway verify_jwt vì tự xác thực JWT với Auth trước mọi thao tác; không tin actor từ mobile. Service key chỉ nằm trong môi trường Edge/tiến trình test.
- Một DB transaction ghi metadata, gallery, revision và receipt. Storage upload ở bước riêng; không hứa rollback file cùng DB. Retry cùng actor/command/key/payload trả ACK cũ, khác payload/revision cũ trả CONFLICT. Client timeout giữ key/payload và kiểm tra lại.
- RLS SELECT theo owner; ghi qua RPC. Bucket private đọc ảnh theo owner hiện tại, thay policy folder cũ; không policy UPDATE object. service_role có grants tường minh cho bảng Material, ảnh, upload, receipt và Listing; không thêm quyền ghi anon/authenticated.
- Gỡ gallery giữ file private để bảo vệ snapshot lịch sử. Upload chưa gắn được claim DISCARDED, xóa bằng Storage API rồi dọn registry. Cleanup upload hết hạn được retry khi upload lần sau; chưa có tác vụ nền định kỳ.
- URL ký 5 phút, không lưu URL signed vào nháp/cache. Cache metadata theo user tối đa 15 phút chỉ đọc. SQLite Android giữ nội dung/byte ảnh nháp, key/upload ID theo user + Material; web preview dùng preferences và báo lỗi quota.
- Migration: 20261125000100_material_workspace, 20261125000200_material_backend_role, 20261125000300_material_text_normalization, 20261125130000_material_isbn_prefix. Không sửa migration đã triển khai.
- ISBN-13 kiểm tra prefix 978/979 và checksum; không nhận EAN khác chỉ vì đủ 13 số/checksum đúng. [Nguồn International ISBN Agency](https://www.isbn-international.org/index.php/node/10).
- Cloud có migration riêng 20261125120000_transactions_payment_issues_rpc của Sơn chưa trong nhánh này. Đối chiếu lịch sử qua snapshot bị Git bỏ qua, không copy module Sơn vào đóng góp Material, không repair lịch sử.
- Listing publish/QR và quản lý tham chiếu snapshot nối tiếp ngày 3/4. Không tạo Listing/QR/Transaction giả để đáp ứng ACK Material.

## 15. Listing ngày 3 theo đặc tả đã được Trường đồng ý

Nguồn quy tắc: SS-BR Phụ lục B, N3-D01–N3-D08 được Trường đồng ý ngày 26/11/2026. Migration mới `20261126000100_listing_workspace.sql`; không sửa các migrations ngày 1/2 hoặc migration workflow của Sơn. QR vẫn thuộc ngày 4.

Đợt tinh chỉnh UI được Trường duyệt bổ sung `20261126000300_listing_owner_cover.sql` và `20261126000400_listing_legacy_snapshots.sql`, cùng migration ảnh lịch sử `20261126000200_listing_history_images.sql`. Cả 4 migration đã được áp dụng local và cloud development `studyshare-nhom12-dev` ngày 26/11/2026 sau kiểm thử local. Code và tài liệu được bàn giao qua PR Listing vào `integration/nhom12-65ktpm`; chỉ merge sau khi thành viên khác review đạt.

| RPC thực tế | Tham số và kết quả |
|---|---|
| `get_my_listing` | `p_listing_id?`, `p_material_id?` (ít nhất một); nếu cả hai thì phải khớp. Chi tiết quản lý của owner/người tạo hoặc null; query theo Material trả tin chưa ARCHIVED |
| `search_my_listings` | `p_status=all/DRAFT/PUBLISHED/HIDDEN/ARCHIVED`, `p_query`, `p_offset>=0`, `p_limit=1..100` mặc định 20 → items/has_more |
| `save_listing` | `p_action=draft/publish/hide/show`, `p_payload`, `p_idempotency_key`, `p_material_id?`, `p_listing_id?`, `p_expected_revision?`, `p_expected_material_revision?` → `ok`, `data` (ManagedListing), `command_id`, `server_revision` |
| `get_listing_command_result` | `p_command=listing_draft/listing_publish/listing_hide/listing_show`, `p_key` → receipt của actor khi còn sở hữu Material và là người tạo tin, hoặc null |
| `get_published_listing` | `p_listing_id` → DTO an toàn PUBLISHED theo viewer; null nếu không công khai |
| `search_published_listings` | `p_keyword` tối đa 200, offset/limit như trên → items/has_more; tìm tên/môn theo snapshot; published_at giảm dần rồi ID; vẫn gồm RESERVED |
| `get_listing_image_path` | `p_listing_id`, `p_image_id` → path đúng ảnh snapshot đang PUBLISHED hoặc null. Repository ký URL 300 giây, không đưa path vào ListingDetails |
| `get_transaction_listing_image_path` | `p_transaction_id`, `p_image_id` → path ảnh được snapshot trong đúng Transaction; chỉ A/B của Transaction hoặc null. Migration bổ sung `20261126000200_listing_history_images.sql`; dùng cho module lịch sử, không dùng đường Discovery để vượt trạng thái ẩn/archive |

`p_payload` chỉ nhận `offer_type`, `asking_price_vnd`, `description`, `meeting_area` với draft/publish; hide/show bắt buộc object rỗng. Không nhận owner/holder/actor/status/snapshot/path do mobile tự gửi. Trường tùy chọn trim/rỗng thành null. Nháp SELL cho giá null có chủ đích, nhưng giá đã nhập phải nguyên dương; publish/show không có giao dịch active bắt buộc đủ giá/ảnh. BORROW/DONATE giá luôn null. Server khóa Material trước Listing, kiểm tra revisions/quyền/trạng thái rồi ghi domain và receipt cùng transaction.

`ListingWorkspaceRepository` bổ sung execute/getCommandResult/getManaged/searchMine/getPublishedDetails/searchPage. Giữ `ListingRepository` và `ListingQueryRepository` cũ bằng adapter; adapter tra receipt trước khi dựng lại revision cho retry. `ListingCommand` giữ trọn ý định và key; Android lưu trong SQLite thông qua ListingDrafts, tách theo account. Sau timeout giữ nguyên command; app tra receipt rồi gửi lại cùng payload nếu chưa có kết quả. Đổi account loại kết quả UI của phiên trước.

Auth guard giữ ý định SCR-10 qua Splash/Login bằng whitelist `materialId`/`listingId` dạng UUID đơn; vẫn bỏ token, fragment, query lạ, ID sai/nhập lặp và cờ completion. Đăng nhập lại không cấp quyền từ ID: form luôn đọc lại ownership và revision qua RPC.

`ManagedListing` có Listing, Material revision, quyền canEdit/canHide/canShow và nhãn pending/active. `ListingDetails` có card, gallery ID/URL ngắn hạn, người đăng an toàn, mô tả Material/Listing, ISBN/khu vực chung; requestBlockedReason dẫn xuất OWNER/RESERVED/REQUEST_PENDING/MATERIAL_UNAVAILABLE. Không có QR, holder, email, ngân hàng, evidence hoặc storage path. Query card chỉ cấp URL bìa; query details mới cấp gallery.

RPC quản lý riêng bổ sung `title`, `cover_storage_path` của Material hiện tại; repository đổi path thành URL ký 300 giây trong `ManagedListing.coverUrl`, không lưu URL vào nháp. Projection Khám phá không nhận private path. `BACKEND_UNAVAILABLE` phân biệt thiếu RPC/chữ ký/schema với `CONFLICT`; lỗi không xác định dùng `UNEXPECTED_ERROR`. Debug chỉ log tên RPC/mã lỗi, không log JWT hoặc payload. Android xử lý giá bigint nguyên chính xác; Chrome preview từ chối giá không còn nguyên vẹn khi mã hóa JSON, không tự làm tròn.

Snapshot công bố có phiên bản, Material/Listing revisions và media IDs theo thứ tự. `listing_snapshot_images` giữ tham chiếu file độc lập gallery; Transaction sao chép publication_snapshot vào `terms_snapshot.listing` khi tạo. Gỡ gallery không xóa file lịch sử. Bucket private, thêm policy chỉ đọc ảnh snapshot PUBLISHED; ẩn/archive không cấp quyền ảnh công bố mới, URL đã ký có thể còn hạn tối đa 5 phút.

Tin PUBLISHED/HIDDEN có sẵn trước ngày 3 chỉ được chuyển đổi snapshot khi 1–5 ảnh có registry ATTACHED, đúng Material và metadata Storage. Snapshot ghi `captured_from=legacy_migration`, là dữ liệu tại lúc chuyển đổi; không diễn giải thành điều khoản tại thời điểm duyệt giao dịch cũ. Không sửa `terms_snapshot` cũ, owner/holder, trạng thái hay ngày công bố. Hàm chuyển đổi private không cấp quyền execute cho anon/authenticated; chạy lại không ghi đè snapshot. Đã đối chiếu cloud: 176 Listing giữ nguyên trạng thái/ngày công bố, 140 snapshot hợp lệ (136 PUBLISHED/4 HIDDEN), hashes điều khoản giao dịch và quyền sở hữu giữ nguyên.

Trigger Request bổ sung khóa Material và kiểm tra khả dụng/PUBLISHED khi tạo PENDING hoặc duyệt ACCEPTED từ JWT authenticated; không triển khai RPC Request thay Khanh. Module Khanh phải khóa Material trước khi khóa/chuyển Request để thống nhất thứ tự, snapshot giá/loại/số ngày đúng dữ liệu đã duyệt. Archive vẫn do workflow kết thúc/hủy Transaction; Listing không thay owner/holder hoặc tự hoàn tất giao dịch.

Kiểm tra local: `npx.cmd supabase@3.3.0 migration up --local --include-all`, `npx.cmd supabase@3.3.0 test db`; serve `verify-material-image` rồi chạy `src/tool/test_listing_local.ps1` để kiểm tra Auth/Storage/ảnh thật, A/B, retry mất ACK và hai lệnh công bố cạnh tranh. Script chỉ nhận URL localhost và giữ service key trong môi trường tiến trình test. Không áp dụng migration lên cloud từ lệnh kiểm tra này.

Android Emulator: `src/tool/test_listing_android.ps1 -Device emulator-5554` tạo account local dùng một lần ở host, reverse cổng 54321 rồi chạy `integration_test/listing_android_test.dart` bằng SDK integration_test. Test kiểm tra SQLite trên Android, ảnh thật, SELL công bố/ẩn/hiện và đọc lại qua repository; finally dọn đúng fixture của account vừa tạo. Service key không được đưa vào APK; tài khoản test bị xóa sau lần chạy. Sau test, build lại target ứng dụng thường nếu cần APK demo, vì APK integration_test không phải bản demo để bàn giao.

Cloud smoke chủ động: `src/tool/test_listing_cloud.ps1` chỉ cho đúng project development được cấu hình/link, đọc admin key vào tiến trình host qua CLI đã đăng nhập, tạo A/B tạm, kiểm tra Auth/Storage/Edge verify/validation/publish/retry/Discovery/quyền/ẩn/hiện; finally chỉ xóa dữ liệu theo UUID của hai account vừa tạo. Không chạy script này tự động trong Flutter test/CI. Lần kiểm tra ngày 26/11/2026 đạt và không còn account smoke trên cloud. Chrome chạy bình thường bằng `flutter run -d chrome`; không thêm `SUPABASE_ENABLED=false` khi nghiệm thu backend thật.

Kiểm tra giá trên Chrome: `src/tool/check_listing_web_price.ps1` biên dịch production validator bằng `dart compile js` và chạy fixture trong Chrome headless có profile riêng dưới `.dart_tool/`. Cách này kiểm tra số JavaScript thật, không thay đổi Flutter SDK. `flutter test --platform chrome` trên Flutter SDK Windows hiện tại gặp lỗi handler CanvasKit trả 404; không lấy lần chạy treo này làm bằng chứng kiểm thử đạt.

Kết quả đợt hoàn thiện ngày 26/11/2026: `flutter analyze` không có issue; `flutter test` đạt 268 test, 6 test tích hợp opt-in được bỏ qua trong lệnh chung; pgTAP đạt 138/138. Các script Listing local, cloud, Android và kiểm tra giá Chrome đã chạy riêng và đạt. Build web và APK debug ứng dụng thường thành công sau chỉnh sửa cuối. `db lint` local không có error, còn một warning biến `changed` chưa đọc trong `save_listing`, không ảnh hưởng kết quả command. Không reset dữ liệu; fixture cloud đã dọn và còn 0 tài khoản smoke. Đây là bằng chứng kiểm tra trước khi bàn giao PR, không thay thế việc review và nghiệm thu tích hợp của nhóm.

### 15.1. Bàn giao read model SCR-06 cho Khanh

Giữ tên `ListingDetails`, không tạo thêm `ListingDetailsModel`. UI đọc `listingDetailsProvider(listingId)` trong `features/listings/providers/listing_providers.dart`; provider gọi `ListingWorkspaceRepository.getPublishedDetails(listingId)`. `ListingQueryRepository` cũ vẫn phục vụ card, không có phương thức details. Không dùng `getMyMaterial()` hoặc ghép `MockFixtures` trong UI để dựng chi tiết công khai.

| Dữ liệu SCR-06 | Field |
|---|---|
| Tên, môn, tình trạng, hình thức, giá, bìa và trạng thái theo viewer | `details.card` (`condition`, `isOwner`, `isReserved`, `hasPendingRequest`, `isRequestable`) |
| Mô tả sách / nội dung lượt đăng | `materialDescription` / `description` |
| Người đăng công khai | `ownerId`, `ownerName`; không có email/holder/ngân hàng |
| Gallery theo thứ tự, ISBN và khu vực chung | `images`, `isbn`, `meetingArea` |
| Chính sách mượn | `borrowPolicy`: chỉ BORROW có `BorrowPolicy.mvp`; SELL/DONATE trả null |
| Lý do khóa CTA | `requestBlockedReason`: OWNER/RESERVED/REQUEST_PENDING/MATERIAL_UNAVAILABLE hoặc chuỗi rỗng |

`BorrowPolicy` bất biến theo BR-20: `minDays=1`, `maxDays=30`, `requesterProposesDays=true`, `ownerMustAcceptRequestedDays=true`, `allowsExtension=false`. `acceptsDays(int?)` chặn trống/ngoài khoảng; kiểu số nguyên được giữ bởi contract Dart. Đây là quy tắc chung, không phải cấu hình chủ tin tự đặt, không thêm cột/migration hoặc payload ghi Listing. RPC Request phải kiểm tra lại đầu vào tại server. SCR-06 hiển thị giới hạn từ policy thay vì tự ghi số trong UI.

Repository preview trả cùng model, có condition, hai loại mô tả, tên công khai từ fixture, khu vực và gallery/bìa nhất quán. URL ảnh minh họa chỉ dành cho demo, không đại diện ảnh đã xác minh trên Supabase; UI dùng placeholder nếu tải ảnh lỗi. Viewer lấy theo phiên demo, owner/PENDING/RESERVED khóa CTA tương ứng; đổi viewer làm provider đọc lại. Không đổi ID/trạng thái fixture chung.

Khi nối UI: giữ loading/error riêng; kết quả null là tin không còn công khai, không fallback sang fixture. URL ảnh thật có thể null/hết hạn; tải lại provider để xin URL mới theo quyền hiện thời. Các trường mô tả/ISBN/khu vực tùy chọn được phép null. Route SCR-06 vẫn `/listings/:listingId`; Khanh hoàn thiện giao diện trên contract này, giữ header/Back và điểm vào từ luồng đăng tin.

Kiểm tra bổ sung policy/mock SCR-06: `flutter analyze --no-pub` không có issue; `flutter test --no-pub --reporter expanded` đạt 277 test, 6 test tích hợp opt-in bỏ qua. Có 9 test mới cho dữ liệu công khai thật/mock, biên số ngày, CTA theo viewer, đổi phiên demo và tin không còn công khai. Không thay đổi SQL hoặc chạy lại script ghi dữ liệu cloud trong đợt bổ sung này.
