# STUDYSHARE — STATE MACHINES & SERVER INVARIANTS

> **Mã:** SS-TECH-03 · **Phiên bản:** 0.2 — đã được nhóm trưởng duyệt định hướng, chưa triển khai SQL/RPC  
> **Vị trí dự kiến:** `nhom12-65ktpm/docs/STATE_MACHINES.md`  
> **Đường dẫn triển khai:** Flutter tại `nhom12-65ktpm/src/`, Dart enums trong `src/lib/core/contracts/`, migrations và RPC tại `src/supabase/migrations/`; tuân thủ README giảng viên.
> **Nguồn chuẩn:** `QUY_TAC_NGHIEP_VU.md` SS-BR v2.0 (§2, §4–11, §14–16). **Trạng thái ở đây giữ nguyên tên canonical**; không dùng nội dung tệp cũ để ghi đè quy tắc mới.

## 1. Nguyên tắc thiết kế

- **Chỉ server điều khiển state transition.** Flutter gọi command có nghĩa nghiệp vụ; không có RPC `setStatus`/`setHolder`/`setOwner` chung.
- Server kiểm tra session, actor A/B/C theo từng bản ghi, status trước lệnh, bằng chứng, nghĩa vụ tiền và idempotency. Transaction DB tạo Event đồng bộ.
- Một Material có tối đa **một Transaction active**; nhiều Request PENDING có thể tồn tại, chỉ một được ACCEPTED nguyên tử.
- Những nhãn như `RESERVED`, `OVERDUE`, `REHANDOVER_OVERDUE`, `NEEDS_RESOLUTION` là **dẫn xuất** từ dữ liệu, **không** gán vào enum Listing/Transaction.
- Tất cả server timestamps là `timestamptz`; phép cộng 1–30 ngày và 3/7 ngày dùng **lịch Việt Nam (`Asia/Ho_Chi_Minh`)**, không lấy đồng hồ điện thoại làm mốc pháp lý nghiệp vụ.
- Issue không tự hoàn tác sự kiện vật lý đã ACK; người nhận đúng chặng phải xác nhận, giver chụp ảnh; QR mismatch hard block.

## 2. Các enum canonical (đã có trong SS-BR v2.0)

| Đối tượng | Giá trị trạng thái chính xác |
|---|---|
| `Listing.status` | `DRAFT`, `PUBLISHED`, `HIDDEN`, `ARCHIVED` |
| `ExchangeRequest.status` | `PENDING`, `ACCEPTED`, `REJECTED`, `CANCELLED` |
| `Transaction.status` BORROW | `AWAITING_HANDOVER`, `HANDOVER_IN_PROGRESS`, `BORROWING`, `RETURN_PENDING`, `RETURN_IN_PROGRESS`, `COMPLETED`, `CANCELLED` |
| `Transaction.status` DONATE | `AWAITING_HANDOVER`, `HANDOVER_IN_PROGRESS`, `COMPLETED`, `CANCELLED` |
| `Transaction.status` SELL | `AWAITING_PAYMENT`, `AWAITING_HANDOVER`, `HANDOVER_IN_PROGRESS`, `COMPLETED`, `CANCELLED` |
| `Handover.status` | `PENDING`, `AWAITING_RECEIVER_CONFIRMATION`, `CONFIRMED`, `DISPUTED` |
| `DeliveryTask.status` | `OPEN`, `ASSIGNED`, `PICKED_UP`, `DELIVERY_PENDING_CONFIRMATION`, `COMPLETED`, `FAILED`, `CANCELLED` |
| `DeliveryApplication.status` | `PENDING`, `ACCEPTED`, `REJECTED`, `WITHDRAWN` |
| `Issue.status` | `OPEN`, `RESOLVED` |

**Không thêm** `PAYMENT_CONFIRMED`, `NEEDS_RESOLUTION`, `OVERDUE`, `RESERVED` vào `Transaction.status`/`Listing.status`; các khái niệm đó thể hiện qua payment record, Issue hoặc read-model availability.

## 3. Listing và Request

| Chuyển trạng thái | Ai / command | Điều kiện |
|---|---|---|
| Listing DRAFT → PUBLISHED | Owner `publishListing` | title, subject, condition, ≥1 ảnh, offer duy nhất; SELL giá VND >0; Material đủ điều kiện |
| Listing PUBLISHED ↔ HIDDEN | Owner hide/show | Không phá snapshot Transaction đã chấp thuận |
| Listing hiện hành → ARCHIVED | Server khi T hoàn tất/hủy hợp lệ | Không tự đưa Listing cũ lên lại; Material và QR có thể đăng lại Listing **mới** |
| Request PENDING → ACCEPTED | A `approveExchangeRequest` | Atomic: một R ACCEPTED + các R cạnh tranh REJECTED + tạo T + giữ chỗ M + Event |
| Request PENDING → REJECTED | A `rejectExchangeRequest` hoặc server khi M hết khả dụng | Không tạo T |
| Request PENDING → CANCELLED | B `cancelPendingRequest` | Request chưa ACCEPTED; không dùng CANCELLED để hủy Transaction |

**Dẫn xuất tìm kiếm:** `Listing.status=PUBLISHED` với Material đang `RESERVED` vẫn xuất hiện ở SCR-05/06, nhãn “Đã được đặt”, nút Request disabled; server từ chối Request mới. `ARCHIVED` không xuất hiện trong khám phá công khai.

## 4. Transaction — BORROW

```text
A chấp thuận Request BORROW
  → AWAITING_HANDOVER
  → HANDOVER_IN_PROGRESS      (có lượt giao A→B hoặc A→C→B)
  → BORROWING                (B nhận cuối, receiver ACK)
  → RETURN_PENDING           (B ghi ý định trả; không đổi holder)
  → RETURN_IN_PROGRESS       (Handover chặng trả B→A hoặc B→C→A)
  → COMPLETED                (A xác nhận nhận lại cuối)
```

- Chấp thuận Request không bắt đầu kỳ mượn. B chỉ bắt đầu mượn khi **B nhận hợp lệ** và server ACK, khi đó `started_at` và `due_date` được server ghi.
- Nếu nhận ngày lịch Việt Nam **21/11** và mượn **7 ngày**, hạn là **28/11 hết ngày**; overdue bắt đầu **29/11**.
- `due_date` không thay khi B ghi ý định trả, khi Issue mở, hoặc khi A chưa hợp tác.
- B giao sách hợp lệ cho C được chọn trong chiều trả vào/trước hạn: lưu `return_to_courier_at` để không tính sai trễ mượn gốc do A/C chậm; **Transaction chưa COMPLETED**.
- Nếu C không giao A được, C trả **C→B** (có ảnh + B ACK); B có hạn **3 ngày lịch Việt Nam kể từ ACK C→B** để tái bàn giao lượt đầu hợp lệ. Lưu `re_handover_due_date` riêng, không viết đè `due_date` mượn gốc.
- Chỉ **A receiver ACK lượt trả cuối** mới cập nhật `holder=A`, kết thúc BorrowingRecord, `Transaction.COMPLETED`, `Listing.ARCHIVED`.
- Hủy `CANCELLED` theo đồng thuận và nghĩa vụ ở §9, không cho B tự hủy BORROW chỉ qua nút Request.

## 5. Transaction — DONATE và SELL

### DONATE

```text
Request ACCEPTED → AWAITING_HANDOVER
  → HANDOVER_IN_PROGRESS     (giao trực tiếp hoặc qua C)
  → COMPLETED               (B ACK lượt cuối)
```

Khi B ACK cuối, trong **một** DB transaction: holder=B, owner=B, Transaction COMPLETED, Listing ARCHIVED, Event một lần. Không có payment.

### SELL

```text
Request ACCEPTED → AWAITING_PAYMENT
  → AWAITING_HANDOVER        (A xác nhận đã nhận tiền thực tế)
  → HANDOVER_IN_PROGRESS     (cho phép lượt giao đầu sau seller confirmation)
  → COMPLETED               (B ACK lượt cuối)
```

- Khi B bấm “Tôi đã chuyển khoản”, chỉ lưu `buyer_reported_at`; không rời `AWAITING_PAYMENT`.
- `seller_confirmed_at` do **A** tự kiểm tra ngân hàng và xác nhận ngoài app; **trước đó mọi Handover SELL bị từ chối**, bao gồm A→C và A→B.
- Khi B ACK nhận cuối, server kiểm tra seller confirmation đã có, mới chuyển owner=B và hoàn tất.
- Nếu giao hộ SELL thất bại, sách trở về A hợp lệ, A/B quyết định tiếp tục giao hoặc đồng thuận hủy/hoàn tiền. Chỉ B xác nhận nhận hoàn tiền ngoài app cùng nghĩa vụ sách/Issue đã xong mới cho CANCELLED.

## 6. Handover — state machine dùng chung

```text
PENDING
  ├── QR đúng hoặc fallback hợp lệ (QR thiếu/không đọc được)
  ├── ≥1 ảnh do from_user_id tải thành công lên Storage private
  └── server xác nhận đủ evidence/verification
          ↓
AWAITING_RECEIVER_CONFIRMATION
  ├── receiver đúng người xác nhận → CONFIRMED (đổi holder + Event)
  └── receiver đúng người từ chối với lý do → DISPUTED (Issue, không đổi holder)
```

**Quy tắc bất biến:**

1. `from_user_id` = current holder của Material tại lúc lập chặng; `to_user_id` đúng người nhận được chỉ định.
2. Giver phải nộp **≥1 ảnh riêng cho từng chặng**; ảnh H1 không dùng thay H2.
3. Ảnh local/đang upload không được tính là evidence server.
4. QR đọc được nhưng **sai Material hoặc leg** → trả lỗi `QR_MISMATCH`, hard block; **không** mở tùy chọn manual.
5. Chỉ QR thiếu/không đọc được mới cho fallback kèm lý do và kiểm tra server.
6. Giver không thể xác nhận thay receiver. Receiver confirm phải đúng user và đúng state `AWAITING_RECEIVER_CONFIRMATION`.
7. Server ACK receiver confirm cập nhật holder + Event + tác động Transaction/DeliveryTask cùng một transaction, chống nhấn/retry trùng.
8. `DISPUTED` giữ lịch sử; sau giải quyết nếu làm lại thì tạo **Handover ID mới**, không viết lại chặng cũ thành CONFIRMED.

## 7. DeliveryTask — courier

```text
OPEN         (người gửi tạo nhiệm vụ, các C ứng tuyển)
  → ASSIGNED (người tạo chọn đúng một C)
  → PICKED_UP (H1 người gửi→C đã CONFIRMED, holder=C)
  → DELIVERY_PENDING_CONFIRMATION (H2 C→người nhận cuối đã nộp chứng cứ)
  → COMPLETED (người nhận cuối ACK H2)
```

- `DeliveryApplication`: PENDING → ACCEPTED một C, các ứng viên PENDING khác REJECTED trong **cùng** transaction. Đơn chưa được chọn có thể PENDING→WITHDRAWN.
- Nếu C rút sau ASSIGNED nhưng **trước** H1, Task cũ CANCELLED có lý do; tạo Task mới nếu cần. Không tái sử dụng ảnh/leg.
- Nếu C đã nhận (H1 ACK) nhưng không giao được: `DeliveryTask.FAILED` + lý do/Issue nếu cần, `holder=C` tiếp tục. C trả cho **người trực tiếp giao C** bằng Handover mới: đi là C→A, chiều trả là C→B.
- Sau khi phục hồi sách thành công, `DeliveryTask` vẫn `FAILED`; chỉ thêm `return_handover_id`/Event và cho phép tạo Task mới.
- Chọn C không tự đổi holder. Không tự chọn C bằng rating; A/B đánh giá tùy chọn 1–5 sao sau khi đủ điều kiện.

## 8. Issue và trạng thái tranh chấp

- Issue MVP chỉ `OPEN` và `RESOLVED`.
- Người nhận từ chối **trước khi** Handover ACK: người nhận cung cấp lý do, server Handover DISPUTED, Issue OPEN, **không** đổi holder/owner.
- Khiếu nại **sau** ACK mở Issue mà **không rollback** holder, owner, payment, due_date hoặc Transaction.COMPLETED.
- Khiếu nại về tình trạng khi B nhận: mở trong **7 ngày lịch Việt Nam** từ B ACK; sự cố mới của BORROW khi còn active có thể báo trong giao dịch; vấn đề chặng trả sau BORROW hoàn tất mở trong 7 ngày từ A ACK.
- Các bên trực tiếp bị ảnh hưởng đồng thuận với **cùng phiên bản phương án giải quyết** rồi server mới RESOLVED. Moderator không được tự đóng Issue hoặc áp đặt giao nhận/thanh toán.
- Bên bị ảnh hưởng suy ra theo từng Issue: Issue gắn một chặng thì là hai đầu của chặng (kể cả C), Issue cấp giao dịch thì là A và B; luôn gồm người báo. Đề xuất mới tăng `revision` và làm mất hiệu lực xác nhận cũ; người đề xuất cũng phải xác nhận riêng. Chi tiết: `CONTRACTS.md` §5.1.
- `NEEDS_RESOLUTION` là **nhãn UI dẫn xuất** nếu tồn tại Issue OPEN; không tạo Transaction.status này.
- Các action xung đột với Issue OPEN phải chặn, nhưng cho phép hành động khắc phục/hoàn trả theo phương án đồng thuận; tránh khóa toàn bộ tiến trình một cách mù quáng.

## 9. Hủy Request và Transaction

| Loại | Điều kiện |
|---|---|
| Rút Request PENDING | B được rút, PENDING → CANCELLED |
| Sau Request ACCEPTED | Không đổi Request thành CANCELLED để hủy T |
| Đề nghị hủy Transaction | A hoặc B đề nghị, người còn lại xác nhận cùng phương án |
| Hoàn tất hủy Transaction | Chỉ khi không còn nghĩa vụ sách, tiền/hoàn tiền, Issue OPEN; history giữ nguyên, archive Listing |
| SELL đã nhận tiền | Phải có hoàn tiền **ngoài app** khi hủy và B xác nhận thực nhận; sách ở A hợp lệ |

Không có nút “Force Cancel” hoặc “Admin hoàn tất” trong client hay public RPC.

## 10. Lược đồ cập nhật dữ liệu trong các lệnh quan trọng

| Sự kiện server | Data đồng bộ trong một transaction |
|---|---|
| A approve Request | Request ACCEPTED + other PENDING REJECTED + T created + material reserved-derived + Event |
| A confirm SELL payment | Payment seller_confirmed_at + T AWAITING_HANDOVER + Event |
| Chọn C | DeliveryTask ASSIGNED + 1 application ACCEPTED + others REJECTED + Event |
| Giver submit evidence | Evidence server + Handover AWAITING_RECEIVER_CONFIRMATION + Event |
| Receiver confirm H1 | Handover CONFIRMED + Material.holder=C + DeliveryTask PICKED_UP + Event |
| Receiver confirm H2 cuối tới B | Handover CONFIRMED + holder=B + T BORROWING hoặc DONATE/SELL COMPLETED + owner theo offer + Event |
| A confirm return cuối | Handover CONFIRMED + holder=A + BORROW COMPLETED + Listing ARCHIVED + Event |
| Receiver refuse | Handover DISPUTED + Issue OPEN + Event; holder không đổi |
| Cancel Transaction đủ nghĩa vụ | T CANCELLED + Listing ARCHIVED + Event; owner/holder không được sửa tùy ý |

## 11. Bản test scenario bắt buộc để các module cùng dùng

| ID | Given/When | Then |
|---|---|---|
| ST-01 | Hai Material trùng tên/ISBN | UUID/QR khác nhau |
| ST-02 | 3 Request chờ; A duyệt một Request không đầu tiên | 1 ACCEPTED, 2 REJECTED, 1 T |
| ST-03 | A duyệt hai Request đồng thời | Tối đa 1 Transaction active |
| ST-04 | Listing PUBLISHED nhưng M RESERVED | Có trong Explore; không gửi Request |
| ST-05 | BORROW 7 ngày, B ACK 21/11 | due 28/11; overdue từ 29/11 (lịch Việt Nam) |
| ST-06 | Giver có QR đúng nhưng chưa có ảnh | Handover không awaiting/confirmed |
| ST-07 | QR đọc được nhưng sai | QR_MISMATCH, manual không được phép |
| ST-08 | H1 A→C và H2 C→B | Hai lượt riêng, hai ảnh, hai receiver ACK |
| ST-09 | A chưa confirm tiền SELL | Không được có Handover nào thành công |
| ST-10 | B ACK SELL sau A confirm tiền | owner=B chỉ một lần |
| ST-11 | C thất bại, chặng trả C→A | holder thay sau A ACK, Task vẫn FAILED |
| ST-12 | Chiều trả B→C hợp lệ trước hạn, A chưa ACK | Chưa COMPLETED, không tính sai trễ gốc |
| ST-13 | C→B phục hồi ở chiều trả | re-handover due = ngày ACK +3, không sửa due gốc |
| ST-14 | B từ chối nhận trước ACK | DISPUTED + Issue OPEN, holder cũ |
| ST-15 | B báo Issue sau ACK | Không rollback holder/owner |
| ST-16 | A/B đề nghị hủy khi tiền/sách/Issue còn nghĩa vụ | Không CANCELLED |
| ST-17 | Retry confirm sau timeout với cùng idempotency key | 1 event, 1 holder update |
| ST-18 | C bị rút sau khi H1 ACK | Không cho cancel Task nhanh; cần recovery |
| ST-19 | Actor ngoài Transaction đọc ảnh private | Server deny |
| ST-20 | C bị người tạo chọn cạnh tranh | Chỉ 1 C ASSIGNED |

## 12. Gate duyệt

- [ ] Đồng bộ các enum trên với Dart, database enum/check constraints, Mock seed, UI chips và test.
- [ ] Rà soát các góc cạnh: hủy có đồng thuận, SELL refund, issue blocking, recovery C, date arithmetic Việt Nam.
- [x] Nhóm trưởng đã duyệt định hướng `STATE_MACHINES.md` và `CONTRACTS.md`; còn phải khóa tên trường/chữ ký RPC và đồng bộ Dart/SQL trước khi 4 thành viên code phụ thuộc.
- [ ] Viết migrations + RPC sau khi qua gate; server tests (không chỉ widget) cho ST-01...20.

> **Tình trạng:** Đặc tả đã được nhóm trưởng duyệt định hướng và đồng bộ đường dẫn `src/`. **Chưa thực hiện SQL migrations, thay đổi Supabase project hoặc Flutter source code.**
