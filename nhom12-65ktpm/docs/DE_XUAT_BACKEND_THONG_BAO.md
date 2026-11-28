# Đề xuất backend cho module Thông báo (SCR-24)

Người đề xuất: Sơn (module Notification). Người quyết định và triển khai: nhóm trưởng.
Tài liệu này **không** phải migration; Sơn không sửa `supabase/`.

## 1. Hiện trạng (đối chiếu Cloud dev ngày 27/11/2026)

- Bảng `public.notifications` đã có (schema `20261122000100`), RLS: `SELECT` và
  `UPDATE (read_at)` khi `recipient_id = auth.uid()`.
- Cloud **chưa có** RPC nào cho thông báo: `get_my_notifications`,
  `mark_notification_read`, `mark_all_notifications_read` đều trả `PGRST202`.
- **Chưa có chỗ nào ghi vào `notifications`**: các RPC giao dịch/sự cố chỉ ghi
  `transaction_events` và `issue_events`. Vì vậy với dữ liệu thật hộp thư luôn rỗng.

Client hiện tại (nhánh `feature/nhom12/son-notifications`) đã chạy được với
backend hiện có: đọc bảng trực tiếp, đánh dấu đã đọc bằng
`UPDATE notifications SET read_at = 'now' WHERE id = ? AND read_at IS NULL`.
Khi backend bổ sung các mục dưới đây, client chỉ cần đổi thân hàm trong
`features/notifications/data/supabase_notification_repository.dart`.

## 2. Sinh thông báo nguyên tử cùng Event (ưu tiên cao nhất)

CONTRACTS.md §7 bước 4 yêu cầu Event và notification ghi trong cùng giao dịch DB.
Đề xuất thêm phần chèn thông báo vào ngay `private.ss_append_txn_event` và
`private.ss_append_issue_event` (một chỗ, mọi RPC hiện có đều đi qua), hoặc một
trigger `AFTER INSERT` trên hai bảng Event.

| Nguồn | Người nhận | `entity_type` / `entity_id` |
|---|---|---|
| `transaction_events` (trừ `ISSUE_*`) | `owner_at_acceptance`, `receiver_id` của giao dịch | `TRANSACTION` / `transaction_id` |
| `issue_events` | A, B và bên bị ảnh hưởng trực tiếp ở chặng (cùng phạm vi đọc Issue) | `ISSUE` / `issue_id` |

Quy tắc chung:

- Không gửi cho chính `actor_id` của Event. Nếu `actor_id` là `NULL` (sự kiện hệ thống/tự động, không do một người dùng cụ thể kích hoạt) thì gửi cho tất cả người nhận hợp lệ trong ma trận.
- Chống trùng ở mức dữ liệu bằng ràng buộc duy nhất `(source_event_type, source_event_id, recipient_id)` (hoặc tương đương) để một Event không bao giờ sinh 2 thông báo cho cùng người nhận.
- Event `ISSUE_*` ở `transaction_events` bỏ qua vì `issue_events` đã có bản tương ứng.
  Bỏ qua để mỗi việc chỉ sinh một thông báo.
- `type` = `event_type` gốc (vd. `PAYMENT_REPORTED`).
- `preview_safe` phải dùng **mẫu cố định theo `event_type`** và chỉ điền trường công khai an toàn (vd. `<tên tài liệu>`), **không** lấy nguyên `safe_description` của Event hiện có vì một số Event đang ghép nội dung người dùng nhập (ví dụ `20261127000100_delivery_handover_rpc.sql:995` ghi `'Từ chối nhận tài liệu: ' || v_reason`). Tuyệt đối không đưa vào preview:
  - bằng chứng, ảnh, URL ký;
  - số tài khoản, số tiền chưa xác nhận;
  - lý do Issue / lý do từ chối do người dùng tự nhập.
  Cần bổ sung test kiểm tra chuỗi reason/URL/tài khoản không lọt ra `preview_safe`.
- Câu chữ `PAYMENT_REPORTED` không được nói "thanh toán thành công" (BR-29).
- Ma trận người nhận cần bao phủ thêm:
  - **Courier C** ở Delivery/Handover (`DELIVERY_ASSIGNED`, `HANDOVER_*`, `DELIVERY_*`) trong phạm vi chặng được phân công;
  - **Request `PENDING`** trước khi có Transaction (ví dụ `REQUEST_CREATED`, `REQUEST_ACCEPTED`, `REQUEST_REJECTED`) với `entity_type = 'REQUEST'` để chủ sách và người gửi nhận thông báo kịp thời.

Mock trong `lib/core/mock/mock_notification_fanout.dart` đang mô phỏng các
quy tắc cơ bản cho Transaction/Issue. Test `test/features/notifications/mock_notification_test.dart` là
kịch bản kiểm thử tương ứng.

## 3. Ràng buộc và chỉ mục

- `CHECK (entity_type IN ('TRANSACTION','ISSUE','REQUEST','DELIVERY_TASK','HANDOVER'))`.
  Client vẫn chịu được mã lạ: hiển thị thông báo nhưng không mở.
- Ràng buộc `UNIQUE` chống trùng theo `(source_event_type, source_event_id, recipient_id)`.
- Chỉ mục `(recipient_id, created_at DESC, id DESC)` cho hộp thư. Thêm chỉ mục một phần
  `WHERE read_at IS NULL` cho badge chưa đọc.

## 4. RPC đề xuất (thay cho truy cập bảng trực tiếp)

Theo phong bì hiện có `{ok, data, event_id}` / `{ok:false, code, message}`. Tham số dạng `p_*` text (trừ tham số phân trang số nguyên).

- `get_my_notifications(p_limit int default 100, p_offset int default 0)` trả
  `{items: [...], unreadCount: <int>, hasMore: <bool>}` (mỗi item gồm
  `{id, type, entityType, entityId, previewSafe, createdAt, readAt}`); tổng `unreadCount` đếm độc lập trên toàn hộp thư của actor, không suy từ trang hiện tại.
- `mark_notification_read(p_notification_id text, p_idempotency_key text)`:
  - chỉ ghi khi `read_at IS NULL`, dùng giờ server;
  - không phải người nhận thì trả `FORBIDDEN` chung;
  - lưu `command_receipts`.
- `mark_all_notifications_read(p_idempotency_key text)`:
  - lưu `command_receipts` theo `(actor, command, idempotency_key)` để khi mất ACK và retry sẽ trả lại đúng `data = {count}` của lần ghi đầu, không đánh dấu nhầm thông báo mới phát sinh sau thời điểm lệnh đầu.
  - `count` = số thông báo chưa đọc lúc bắt đầu ý định nay đã ở trạng thái đã đọc. Đây cũng là nghĩa client đang dùng. `count = 0` không có nghĩa là hộp thư hết thông báo chưa đọc: client hỏi lại tổng chưa đọc sau lệnh.
  - Trong lúc chưa có RPC, client tự đối soát. Tập ID được chốt ở lần thử đầu. Mỗi chunk PATCH thiếu dòng sẽ được kiểm lại bằng `read_at IS NOT NULL`, và tiến độ giữ qua các lần retry trong bộ nhớ app. Khởi động lại app thì mất trạng thái này; RPC với `command_receipts` sẽ khắc phục.

Sau khi có RPC, nên **thu hồi** `UPDATE (read_at)` trực tiếp. Hiện client có thể
đặt `read_at` thành giá trị tùy ý, kể cả `NULL` hoặc một thời điểm tương lai,
trên dòng của chính mình.

## 5. Để sau MVP

- Thêm `notifications` vào publication `supabase_realtime` để badge tự cập nhật.
  Hiện client chỉ tải lại khi mở hộp thư hoặc khi app quay lại foreground.
- Push khi app đóng (FCM + `POST_NOTIFICATIONS`): BR-48 chưa yêu cầu.
- Chính sách lưu trữ: ví dụ xóa thông báo đã đọc sau 90 ngày.
