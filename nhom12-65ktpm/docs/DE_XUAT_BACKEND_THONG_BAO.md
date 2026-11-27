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

- Không gửi cho chính `actor_id` của Event.
- Event `ISSUE_*` ở `transaction_events` bỏ qua vì `issue_events` đã có bản tương ứng.
  Bỏ qua để mỗi việc chỉ sinh một thông báo.
- `type` = `event_type` gốc (vd. `PAYMENT_REPORTED`).
- `preview_safe` = `<tên tài liệu>: <safe_description>`. Không đưa vào preview:
  - bằng chứng, ảnh, URL ký;
  - số tài khoản, số tiền chưa xác nhận;
  - lý do Issue do người dùng tự nhập.
- Câu chữ `PAYMENT_REPORTED` không được nói "thanh toán thành công" (BR-29).

Mock trong `lib/core/mock/mock_notification_fanout.dart` đang mô phỏng đúng các
quy tắc này. Test `test/features/notifications/mock_notification_test.dart` là
kịch bản kiểm thử tương ứng.

## 3. Ràng buộc và chỉ mục

- `CHECK (entity_type IN ('TRANSACTION','ISSUE','REQUEST','DELIVERY_TASK','HANDOVER'))`.
  Client vẫn chịu được mã lạ: hiển thị thông báo nhưng không mở.
- Chỉ mục `(recipient_id, created_at DESC)` cho hộp thư. Thêm chỉ mục một phần
  `WHERE read_at IS NULL` cho badge chưa đọc.

## 4. RPC đề xuất (thay cho truy cập bảng trực tiếp)

Theo phong bì hiện có `{ok, data, event_id}` / `{ok:false, code, message}`. Tham số dạng `p_*` text.

- `get_my_notifications(p_limit int default 100)` trả mảng
  `{id, type, entityType, entityId, safePreview, createdAt, readAt}`.
- `mark_notification_read(p_notification_id text, p_idempotency_key text)`:
  - chỉ ghi khi `read_at IS NULL`, dùng giờ server;
  - không phải người nhận thì trả `FORBIDDEN` chung;
  - lưu `command_receipts`.
- `mark_all_notifications_read(p_idempotency_key text)` trả `data = {count}`.

Sau khi có RPC, nên **thu hồi** `UPDATE (read_at)` trực tiếp. Hiện client có thể
đặt `read_at` thành giá trị tùy ý, kể cả `NULL` hoặc một thời điểm tương lai,
trên dòng của chính mình.

## 5. Để sau MVP

- Thêm `notifications` vào publication `supabase_realtime` để badge tự cập nhật.
  Hiện client chỉ tải lại khi mở hộp thư hoặc khi app quay lại foreground.
- Push khi app đóng (FCM + `POST_NOTIFICATIONS`): BR-48 chưa yêu cầu.
- Chính sách lưu trữ: ví dụ xóa thông báo đã đọc sau 90 ngày.
