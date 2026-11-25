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
| `issues` | `id`, `transaction_id`, `handover_id?`, `reporter_id`, `type`, `reason`, `status`, `opened_at`, `resolved_at?` | `OPEN/RESOLVED`; không rollback lịch sử vật lý |
| `issue_consents` | `issue_id`, `participant_id`, `resolution_revision`, `approved_at` | Đồng thuận đúng phương án/các bên trực tiếp bị ảnh hưởng |
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
| `IssueDetails` | id, status, relation, safe description, evidence permission flags, resolution proposals | SCR-21/23 |
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

Các interface khác: `MaterialRepository`, `ListingRepository`, `ListingQueryRepository`, `BorrowRepository`, `TransactionRepository`, `DeliveryRepository`, `EvidenceRepository`, `IssueRepository`, `NotificationRepository`.

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
| `proposeIssueResolution` / `confirmIssueResolution` | Snapshot proposal/revision; xác nhận các bên ảnh hưởng; không ép giải quyết | Sơn |
| `proposeTransactionCancellation` / `acceptTransactionCancellation` | Hai bên đồng thuận; kiểm tra nghĩa vụ sách/tiền/Issue; archive Listing an toàn | Sơn |
| `getTransactionTimeline` | Chỉ actor thuộc transaction; event details đã loại PII | Sơn |

### Quy ước tên server RPC đề xuất

`approve_exchange_request`, `confirm_seller_payment`, `select_courier`, `create_handover`, `verify_material_code`, `submit_handover_evidence`, `confirm_handover`, `refuse_handover`, `request_borrow_return`, `confirm_issue_resolution`, `accept_transaction_cancellation`. **Không buộc mỗi use case là một RPC riêng**, nhưng mọi mutation xuyên bảng phải là server-side atomic command.

**Thiết kế nhận input:** client gửi ID, payload nghiệp vụ, `idempotency_key`, phiên Supabase Auth; **không** gửi actor/owner/holder/status mới. Server lấy actor từ `auth.uid()` và tự đọc bản ghi mới nhất dưới lock phù hợp.

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
| Issue/Evidence | Không | Các bên ảnh hưởng theo phạm vi | Khi C trực tiếp liên quan | Cấp cao cần cấp quyền riêng |
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
