# ĐẶC TẢ PHÂN HỆ GIAO DỊCH, THANH TOÁN VÀ SỰ CỐ – STUDYSHARE

> **Mã tài liệu:** SS-SON-01  
> **Phiên bản:** 1.1 – BẢN DỰ THẢO ĐỂ REVIEW, **chưa khóa Dart Contracts/SQL schema**  
> **Nhóm:** 12 – 65KTPM  
> **Thành viên phụ trách:** **Lý Đình Sơn** – MSSV **2351170615** – GitHub: `lydinhson`  
> **Phạm vi:** Vòng đời `Transaction`, chuyển nhượng tặng/bán, QR chuyển khoản ngoài ứng dụng, lịch sử, thông báo trong ứng dụng, hủy và sự cố.  
> **Nguồn nghiệp vụ:** [`QUY_TAC_NGHIEP_VU.md`](./QUY_TAC_NGHIEP_VU.md) (SS-BR v1.1); [`QUY_TRINH_HOAT_DONG.md`](./QUY_TRINH_HOAT_DONG.md) (SS-WF v1.1), chủ yếu P6, P7, P9 và các điểm tích hợp P2–P5.  
> **Ngày soạn bản nháp:** 21/11/2026.

---

## 0. Mục đích và nguyên tắc sử dụng

Tài liệu này là **đặc tả đầu vào để Sơn tự triển khai và kiểm thử phân hệ của mình**, không phải bằng chứng Sơn đã viết code. Sơn cần đọc, tự rà soát/cập nhật các tình huống còn mở, trao đổi với nhóm, rồi **tự commit bằng tài khoản GitHub của mình**. Không ghi nhận đóng góp kỹ thuật chưa được thực hiện.

- **[ĐÃ CHỐT]:** Trích từ quyết định đã xác nhận hoặc quy tắc đang được giữ nguyên trong SS-BR/SS-WF.
- **[ĐỀ XUẤT]:** Phương án thiết kế để Sơn và các thành viên review; **không tự khóa thành enum/API/SQL**.
- **[CẦN CHỐT]:** Chưa đủ quy tắc để cài đặt an toàn; ghi Issue thảo luận trước khi triển khai.
- Nếu tài liệu này khác SS-BR hoặc SS-WF, **không tự chọn bản thuận tiện**: tạo Issue/PR sửa đồng bộ tài liệu nguồn, contracts và tests.

### 0.1. Sơn chịu trách nhiệm gì?

| Sơn **chủ trì** | Sơn **phối hợp** | Không tự ý làm thay |
|---|---|---|
| `Transaction` lifecycle/state machine và điều kiện hoàn tất | Khanh: chấp thuận `ExchangeRequest`, yêu cầu trả, hạn trả | Không tự duyệt Request hoặc sửa `request.status` bằng Flutter |
| Ghi nhận QR thanh toán, người bán xác nhận nhận tiền | Đăng: `Handover`, bằng chứng ảnh, giao hộ | Không tự giả lập bàn giao thành công hay đổi `holder_id` |
| Timeline / `TransactionEvent`, giao dịch của tôi | Trường: `Material`, `Listing`, ownership, Shared Models | Không đặt `owner_id`/`availability` trực tiếp từ UI |
| Báo cáo/trạng thái `Issue`, thông báo trong ứng dụng | Cả nhóm: RPC, RLS, mock và tests liên thông | Không giải quyết tranh chấp bằng sửa status tùy ý |

### 0.2. Bất biến phải giữ [ĐÃ CHỐT]

1. Một `Material` không có **hai Transaction đang hoạt động** đồng thời (BR-05, BR-14).
2. `owner_id` (chủ được ghi nhận) **khác** `holder_id` (người đang giữ đã xác nhận gần nhất). Mượn không đổi chủ; giao hộ chỉ đổi người giữ sau lượt xác nhận hợp lệ (BR-17, BR-33).
3. `DONATE` chỉ kết thúc khi bên nhận cuối xác nhận giao nhận; `SELL` chỉ kết thúc khi **cả** giao nhận hợp lệ **và** A xác nhận đã nhận tiền (BR-24–BR-26).
4. StudyShare **không chuyển tiền và không xác minh giao dịch ngân hàng**. B tự chuyển khoản ngoài app; A kiểm tra và xác nhận trên app (BR-25).
5. Ảnh chụp offline, lời báo "đã giao" từ người vận chuyển hoặc việc quá thời gian chờ **không đủ** để hoàn tất bàn giao/giao dịch (BR-30–BR-35, BR-46).
6. Thay đổi nhiều bảng có tác động đến Transaction/Material phải **nguyên tử ở server**; Flutter chỉ gửi lệnh nghiệp vụ (BR-14, mục 9 SS-BR).

## 1. Các đầu vào, đầu ra và màn hình của phân hệ Sơn

| Thành phần | Đầu vào/nguồn có thẩm quyền | Sơn cung cấp |
|---|---|---|
| Giao dịch đã chấp thuận | `Transaction` do nghiệp vụ duyệt của Khanh tạo nguyên tử tại server | Trang **Chi tiết giao dịch**, hiển thị đúng điều kiện thao tác |
| Bàn giao thành công | `Handover.CONFIRMED` và thông tin bên nhận từ module Đăng | Quy tắc tính **trạng thái giao dịch tiếp theo**; timeline |
| Bắt đầu/hoàn trả BORROW | Xác nhận bàn giao đến B / nhận lại A; nghĩa vụ mượn từ Khanh | Xác định khi nào `BORROWING`/`COMPLETED`; không tự tính sửa hạn trả |
| Xác nhận tiền SELL | Người bán A xác nhận sau khi tự kiểm tra tiền | QR/thông tin chuyển khoản, trạng thái xác nhận, event |
| Báo bất đồng, giao thất bại | Người liên quan hoặc tác vụ giao hộ của Đăng | Tạo/theo dõi `Issue`, hạn chế các chuyển trạng thái không an toàn |
| Thông báo | Event nghiệp vụ đã ghi nhận ở server | Danh sách thông báo trong app cho người liên quan |

**Màn hình chính:** UI-09 Chi tiết giao dịch / timeline; UI-16 Hoạt động / lịch sử; UI-17 Thông báo (theo danh mục màn hình trong đề cương/SS-WF). Phân hệ giao nhận và xác minh ảnh vẫn do Đăng thực hiện trên các UI liên quan.

## 2. Mô hình vòng đời Transaction – [ĐỀ XUẤT, chưa khóa enum]

Trạng thái **phải phản ánh điều kiện đã được server xác nhận**, không phản ánh chỉ thao tác trên client. Đề cương có các trạng thái dự kiến dưới đây; khi khóa `TRANG_THAI_NGHIEP_VU.md`, nhóm phải thống nhất bảng chuyển trạng thái đầy đủ.

### 2.1. BORROW – cho mượn

| Trạng thái đề xuất | Khi nào thể hiện | Sự kiện hợp lệ tiếp theo |
|---|---|---|
| `AWAITING_HANDOVER` | Request được duyệt, chưa có lượt giao đang thực hiện | Tạo/chọn phương thức giao |
| `HANDOVER_IN_PROGRESS` | Đang thực hiện A→B hoặc A→C→B | Bên nhận được chỉ định xác nhận từng lượt |
| `BORROWING` | **B đã xác nhận nhận sách**; `owner=A`, `holder=B` | B tạo yêu cầu trả (Khanh) |
| `RETURN_PENDING` | Đã yêu cầu trả, chưa triển khai lượt bàn giao trả | Chọn giao trực tiếp / giao hộ |
| `RETURN_IN_PROGRESS` | Đang thực hiện B→A hoặc B→C→A | A xác nhận lượt nhận cuối |
| `COMPLETED` | **A đã xác nhận nhận lại** qua Handover đủ ảnh | Kết thúc; không tái kích hoạt Transaction cũ |
| `NEEDS_RESOLUTION` | Có trở ngại khiến luồng bình thường không thể tiếp tục | Xử lý `Issue` theo quyền/quy tắc được chốt |

**[CẦN CHỐT]** `NEEDS_RESOLUTION` là trạng thái riêng của Transaction hay chỉ là cờ/cảnh báo lấy từ Issue đang mở? Không cho Sơn tự tạo hai nguồn chân lý mâu thuẫn nhau. **[ĐỀ XUẤT]** lưu Issue riêng, xác định quy tắc chuyển trạng thái/chặn thao tác theo Issue khi khóa state machine.

### 2.2. DONATE / SELL – chuyển nhượng

| Tình huống | Giao nhận cuối đến B | A xác nhận tiền | Owner hệ thống | Holder hệ thống | Kết quả |
|---|---|---|---|---|---|
| `DONATE`: chưa nhận | Không | Không áp dụng | A | Người đã nhận hợp lệ gần nhất | Chưa hoàn tất |
| `DONATE`: đã nhận | **Có** | Không áp dụng | **B** | **B** | `COMPLETED` |
| `SELL`: chưa nhận, chưa tiền | Không | Không | A | Người đã nhận hợp lệ gần nhất | Chờ bàn giao/thanh toán |
| `SELL`: tiền trước | Không | **Có** | A | Người đã nhận hợp lệ gần nhất | Vẫn chờ giao nhận |
| `SELL`: sách trước | **Có** | Không | A | **B** | `AWAITING_PAYMENT_CONFIRMATION` |
| `SELL`: đủ hai điều kiện | **Có** | **Có** | **B** | **B** | `COMPLETED` |

**[ĐÃ CHỐT]** Luồng tiền trước / sách trước đều phải được mô hình hóa; việc ghi nhận một điều kiện trước **không** được tự hoàn tất giao dịch. **[ĐỀ XUẤT]** mặc định khuyên nhận tiền trước khi giao sách (BR-29), nhưng app không được lỗi khi thực tế ngược lại.

### 2.3. Sự kiện và rào chắn chuyển trạng thái

| Event nghiệp vụ (tên minh họa) | Ai phát lệnh | Preconditions bắt buộc | Side effects **trên server** |
|---|---|---|---|
| `REQUEST_ACCEPTED` | Khanh (approval flow) | A là chủ; Request PENDING; Material khả dụng | Tạo Transaction + giữ chỗ + từ chối request khác + event |
| `HANDOVER_CONFIRMED` | Người nhận Handover qua module Đăng | Đúng bên nhận, Handover hợp lệ, ảnh server hợp lệ | Cập nhật holder; xác định giai đoạn của Transaction; event |
| `BORROW_RETURN_REQUESTED` | B qua module Khanh | B đang mượn; giao dịch chưa hoàn tất | Ghi yêu cầu trả, đưa luồng sang trả **theo state machine đã chốt** |
| `SELLER_PAYMENT_CONFIRMED` | **A** (người bán) | SELL; A đúng người bán đã ghi nhận; chưa xác nhận trước đó | Ghi xác nhận; nếu đã nhận sách hợp lệ thì hoàn tất Transaction, chuyển owner một lần |
| `ISSUE_REPORTED` | Bên có quyền / tác vụ giao hợp lệ | Transaction/Handover liên quan; lý do hợp lệ | Tạo Issue + event; không tự đổi owner/holder |
| `TRANSACTION_CANCELLED` | Bên có quyền **[CẦN CHỐT]** | Chưa có bàn giao đã gửi/chờ xác nhận/thành công; chưa xác nhận tiền **[BR-45 ĐỀ XUẤT]** | Đóng giao dịch, giải phóng Material **nếu an toàn**, ghi event |

**Không tạo RPC tổng quát** như `setTransactionStatus(..., COMPLETED)` hoặc `setMaterialOwner(...)` cho client. Nếu có hai nguồn sự kiện cùng đến (xác nhận tiền và bàn giao), server phải kiểm tra và hoàn tất **tối đa một lần**.

## 3. P6 – Chuyển nhượng tặng miễn phí (DONATE)

**Tham chiếu:** SS-BR BR-24, BR-30–BR-34; SS-WF P6.

| Bước | Người / màn hình | Điều kiện | Kết quả dữ liệu | Nhánh lỗi |
|---|---|---|---|---|
| S6.1 | B chọn **Nhận miễn phí** (UI-04/UI-07 – Khanh) | Listing `DONATE` còn hiệu lực | Request `PENDING` | Không có quyền / sách hết khả dụng ⇒ từ chối |
| S6.2 | A duyệt (UI-08 – Khanh) | Quy trình duyệt nguyên tử | Request ACCEPTED; Transaction DONATE; Material giữ chỗ | Duyệt trùng ⇒ không tạo Transaction thứ hai |
| S6.3 | A và B chọn giao trực tiếp/giao hộ (Đăng) | Transaction hợp lệ | Handover theo từng chặng, mỗi lượt có ảnh | Thiếu ảnh/sai người nhận ⇒ chưa xác nhận |
| S6.4 | B xác nhận nhận cuối (Đăng) | Handover cuối CONFIRMED ở server | **Cùng thao tác nguyên tử**: `owner=B`, `holder=B`, Transaction COMPLETED; ghi Event | B tranh chấp ⇒ Issue, không đổi owner |
| S6.5 | Sơn hiển thị lịch sử (UI-09/UI-16) | Server ghi nhận thành công | Timeline tặng thành công | Mạng lỗi ⇒ tải lại trạng thái từ server, không tự giả thành công |

**Tiêu chí demo riêng:** Bấm "Đã giao" của C không hoàn tất DONATE nếu B chưa xác nhận. Không có ảnh server hợp lệ cũng không hoàn tất.

## 4. P7 – Bán sách, QR chuyển khoản và xác nhận tiền (SELL)

**Tham chiếu:** SS-BR BR-25–BR-29, BR-33; SS-WF P7. **Không tích hợp thanh toán tự động**.

| Bước | Người / màn hình | Điều kiện | Dữ liệu / phản hồi |
|---|---|---|---|
| S7.1 | B chọn **Mua** (Khanh) | Listing SELL hợp lệ | Gửi Request PENDING; **chưa mặc định coi là đã thanh toán** |
| S7.2 | A chấp thuận (Khanh) | Duyệt nguyên tử | Transaction SELL tạo; ghi **giá đã chốt** **[BR-28 ĐỀ XUẤT]** |
| S7.3 | B mở UI-09 – xem QR chuyển khoản | Transaction đã chấp thuận **[BR-27 ĐỀ XUẤT]** | Hiển thị ngân hàng/người thụ hưởng/số tiền/nội dung, không yêu cầu OTP |
| S7.4 | B chuyển khoản trong ứng dụng ngân hàng | Ngoài StudyShare | StudyShare **không kiểm tra số dư/sao kê/giao dịch** |
| S7.5 | B bấm "Tôi đã chuyển khoản" **[ĐỀ XUẤT]** | Transaction SELL còn hoạt động | Chỉ thông báo cho A; không xác nhận đã nhận tiền |
| S7.6 | A tự kiểm tra và bấm **Đã nhận tiền** | A đúng seller của Transaction | Server ghi người xác nhận + timestamp + Event, một lần duy nhất |
| S7.7 | B nhận sách (Đăng) | Handover cuối CONFIRMED với ảnh | Ghi nhận bàn giao; nếu tiền đã được A xác nhận thì hoàn tất |
| S7.8 | Sơn thể hiện kết quả | Cả hai điều kiện có trên server | Transaction COMPLETED, `owner=B`, `holder=B`, archive Listing cũ **[BR-07 ĐỀ XUẤT]** |

**Chỉ A xác nhận tiền.** B không có nút xác nhận thay A. Khi A nhấn nhiều lần hoặc request bị timeout, server phải trả về trạng thái nhất quán, không tạo hai lần chuyển chủ hay hai Event (idempotency **[ĐỀ XUẤT kỹ thuật]**).

### 4.1. Thông tin dữ liệu thanh toán [ĐỀ XUẤT]

| Trường logic | Ý nghĩa | Ghi chú |
|---|---|---|
| `transaction_id` | Liên kết Transaction SELL | Khóa ngoại |
| `agreed_price_vnd` | Giá snapshot lúc duyệt | Không phụ thuộc giá Listing sau này |
| `seller_id` | Người bán tại lúc duyệt | Xác nhận tiền đúng người, dù owner có thể đổi sau |
| `payment_qr_payload` hoặc đầu vào tạo QR | Thông tin người hưởng, số tiền, nội dung | Cần review chuẩn hóa dữ liệu và quyền riêng tư |
| `transfer_reference` | Nội dung chuyển khoản tham khảo | Không phải mã giao dịch ngân hàng được xác thực |
| `buyer_reported_at` | B thông báo đã chuyển | **Không** có giá trị xác nhận tiền thành công |
| `seller_confirmed_at` | A xác nhận đã nhận | Nguồn quyết định đối với điều kiện tiền của SELL |

**Không đưa dữ liệu thật như số tài khoản cá nhân, OTP, sao kê ngân hàng hoặc ảnh chuyển tiền của thành viên vào Mock công khai.** Dùng tài khoản/định danh giả định khi demo.

### 4.2. Điều kiện hoàn tất SELL (để test)

```text
Nếu NOT final_handover_confirmed:
    Không COMPLETED, dù seller_confirmed_at đã có.
Nếu final_handover_confirmed AND seller_confirmed_at == null:
    Chờ A xác nhận tiền; owner=A; holder=B.
Nếu final_handover_confirmed AND seller_confirmed_at != null:
    Server hoàn tất một lần: owner=B; holder=B;
    Transaction COMPLETED; ghi Event; Listing cũ kết thúc theo chính sách đã chốt.
```

Chỉ server được thực hiện điều kiện trên. Flutter nhận lại trạng thái từ server; không tự đổi `owner_id` trên máy.

## 5. P9 – Hủy, giao thất bại, tranh chấp và xử lý Issue

**Tham chiếu:** SS-BR BR-34–BR-35, BR-44–BR-48; SS-WF P9.

### 5.1. Trường hợp và phản ứng bắt buộc

| Mã | Trường hợp | Sơn phải cho hệ thống thể hiện | Phương án xử lý |
|---|---|---|---|
| SON-E01 | C lấy sách rồi giao thất bại | `holder=C`, không tự AVAILABLE; Issue liên quan | Đăng tổ chức lượt giao lại hoặc Handover trả về A |
| SON-E02 | B báo tài liệu sai/hỏng/chưa nhận | Handover DISPUTED, không đổi holder theo lượt đó | Tạo Issue, lưu diễn biến và hướng xử lý |
| SON-E03 | Người nhận không phản hồi | Chờ xác nhận; **không tự hoàn tất khi quá giờ** | Nhắc/báo Issue; không sửa holder |
| SON-E04 | A đã xác nhận tiền nhưng chưa giao | SELL chưa COMPLETED, owner vẫn A | Tiếp tục bàn giao hoặc Issue; hoàn tiền **ngoài app** nếu các bên tự thỏa thuận |
| SON-E05 | B đã nhận SELL nhưng A chưa xác nhận tiền | owner=A; holder=B; chờ tiền | A tự kiểm tra, xác nhận hoặc tạo Issue |
| SON-E06 | Mất mạng khi gửi bằng chứng | Handover chưa được xác nhận | Đăng giữ bản nháp, retry sau; Sơn không tự kết thúc |
| SON-E07 | Hủy trước giao nhận/chưa tiền | Chỉ hủy nếu điều kiện server hợp lệ **[ĐỀ XUẤT]** | Hoàn nguyên giữ chỗ một cách nguyên tử |
| SON-E08 | Hủy sau đã có bàn giao / đã nhận tiền | Chặn nút hủy nhanh **[ĐỀ XUẤT]** | Issue, quy trình trả lại/đối soát có ghi Event |
| SON-E09 | User không liên quan xem Issue / giao dịch | Không lộ thông tin cá nhân/ảnh | Server/RLS trả `FORBIDDEN` |

### 5.2. Luồng Issue tối thiểu

`Người có quyền bấm Báo vấn đề → nhập loại và mô tả → server ghi Issue + TransactionEvent → Sơn hiển thị Issue trên UI-09/UI-16 → các bên trao đổi/khắc phục theo hành động được phép → ghi kết quả có audit log`.

- **[ĐÃ CHỐT]** Issue không cho phép sửa lén `holder_id` hay `owner_id` để làm cho giao dịch trông như đã hoàn tất.
- **[ĐỀ XUẤT]** `issue.status`: `OPEN`, `IN_REVIEW`, `RESOLVED`, `CLOSED` (chưa khóa enums).
- **[CẦN CHỐT]** Ai có quyền đóng Issue khi bên gửi/bên nhận tranh chấp? Ai cho phép tiếp tục bước giao nhận? MVP chưa bắt buộc có Admin UI đầy đủ (BR-48).
- **[CẦN CHỐT]** Nếu SELL đã xác nhận tiền rồi A/B yêu cầu hủy, ứng dụng ghi nhận đối soát như thế nào? Không hứa tự hoàn tiền.

## 6. TransactionEvent, timeline và thông báo

### 6.1. Mẫu sự kiện đề xuất (không phải enum đã khóa)

| Event type | Khi phát sinh | Bên được xem theo quan hệ giao dịch |
|---|---|---|
| `REQUEST_ACCEPTED` | A chấp thuận yêu cầu | A và B |
| `DELIVERY_ASSIGNED` | Người giao hộ được duyệt | A, B, C có liên quan |
| `HANDOVER_CONFIRMED` | Một lượt giao nhận hoàn tất | Bên tham gia và các bên có quyền |
| `BORROW_STARTED` | B xác nhận nhận tài liệu | A, B |
| `RETURN_REQUESTED` | B muốn trả tài liệu | A, B |
| `PAYMENT_REPORTED` | B báo đã chuyển khoản (nếu có tính năng này) | A, B |
| `SELLER_PAYMENT_CONFIRMED` | A xác nhận nhận tiền | A, B |
| `TRANSACTION_COMPLETED` | Đủ điều kiện kết thúc | A, B; C xem phần công việc liên quan theo quyền |
| `ISSUE_REPORTED` | Có báo vấn đề | Các bên liên quan/được phân quyền |
| `TRANSACTION_CANCELLED` | Hủy hợp lệ | A, B |

**[ĐỀ XUẤT]** Mỗi Event có `id`, `transaction_id`, `actor_id`, `type`, `created_at` (server), `details` tối thiểu, và `source_action_id` để chống ghi trùng. Timeline theo thứ tự thời gian do server ghi, không dùng timestamp do điện thoại gửi lên làm sự thật duy nhất.

### 6.2. Quy tắc thông báo trong ứng dụng

- Gửi cho **đúng người liên quan**, ví dụ A khi B báo đã chuyển tiền, B khi A xác nhận tiền, các bên khi phát sinh Issue.
- Hiển thị rõ **đang chờ hành động của ai**; không viết "thanh toán thành công" nếu mới có sự thông báo từ B.
- Thông báo là **dẫn xuất từ Event**, không tự tạo một nguồn trạng thái giao dịch khác.
- Chưa yêu cầu push notification ngoài app trong MVP (BR-48 [ĐỀ XUẤT]).

## 7. Contracts/Supabase: ranh giới tích hợp (chưa khóa chữ ký)

| Hành động logic (tên minh họa) | Module gọi | Server phải kiểm tra | Kết quả cần trả |
|---|---|---|---|
| `getTransactionDetail(id)` | Sơn và các UI liên quan | Người dùng có quan hệ/đúng quyền | Transaction, các điều kiện hành động, timeline |
| `getMyTransactions(filter)` | Sơn | Auth user, chỉ dữ liệu được xem | Danh sách có phân trang **[ĐỀ XUẤT]** |
| `confirmSellerPayment(id)` | Sơn | SELL, A đúng seller, chưa xác nhận | PaymentConfirmation + Transaction snapshot mới |
| `reportTransactionIssue(id, reason)` | Sơn/Đăng | User có quyền, lý do hợp lệ | Issue + Event |
| `getTransactionEvents(id)` | Sơn | Đúng quyền xem | Danh sách sự kiện server |
| `cancelTransaction(id)` | Sơn | Trạng thái và các điều kiện hủy hợp lệ | Canceled/Conflict, availability cập nhật đồng bộ |
| `confirmHandover(id)` | **Đăng** | Receiver đúng, Evidence đủ và server ghi nhận | Handover + holder + tác động lên Transaction |
| `approveExchangeRequest(id)` | **Khanh** | A đúng chủ, tài liệu chưa bị giữ chỗ | Transaction đã tạo/Result nguyên tử |

- **Trường** khởi tạo Shared Models/Repository Interfaces/mock skeleton. **Sơn** review và hoàn thiện service/repository phần Transaction–Payment–Issue–Event bằng PR.
- **Sơn không tự thêm một bản `Material` hoặc `holder_id` thứ hai** trong module của mình.
- Chỉ sử dụng tên hành động logic ở trên để giao tiếp; **Dart signatures, DTO, SQL function names và enum sẽ khóa sau** trong `HOP_DONG_LAP_TRINH.md`.
- Supabase RLS/RPC phải dựa trên user đăng nhập và kiểm tra quan hệ giao dịch; không tin `actor_id`, `seller_id`, hoặc trạng thái từ client.

## 8. Kịch bản Mock chung Sơn phải hỗ trợ

| Scenario ID | Dữ liệu ban đầu | Kết quả sau hành động |
|---|---|---|
| `son_donate_ready` | DONATE đã duyệt, chưa giao đến B | B nhận đủ ảnh ⇒ chuyển owner=B một lần |
| `son_sell_payment_first` | SELL đã duyệt, A xác nhận tiền trước | Giao thành công sau đó ⇒ COMPLETED |
| `son_sell_delivery_first` | SELL đã duyệt, B nhận sách trước | Chưa đổi owner; A xác nhận tiền ⇒ COMPLETED |
| `son_sell_unpaid` | B giữ sách, A chưa xác nhận tiền | Hiển thị chờ thanh toán, không mở bán lại |
| `son_courier_failed` | C đã nhận hợp lệ, giao B thất bại | Holder vẫn C; Issue OPEN |
| `son_handover_disputed` | B phản hồi sai/hỏng | Handover DISPUTED, không đổi holder |
| `son_cancel_safe` | Đã duyệt, chưa gửi Handover, chưa tiền | Có thể hủy theo BR-45 nếu được nhóm chốt |
| `son_cancel_unsafe` | Có Handover chờ xác nhận hoặc A đã xác nhận tiền | Không cho hủy nhanh |

**Quy định fixture:** Dùng cùng `Material`, `Listing`, `Transaction` và UUID cố định mà Trường đã tạo; **không tự tạo một Mock Store độc lập** hoặc tự sửa ID lõi. Các scenario có thể reset để unit/widget tests không phụ thuộc thứ tự thực thi.

## 9. Danh sách test Sơn cần viết

| ID | Kiểm thử | Kết quả mong đợi |
|---|---|---|
| SON-T01 | DONATE: C bấm "đã giao" khi B chưa xác nhận | Transaction chưa COMPLETED |
| SON-T02 | DONATE: B xác nhận lượt cuối có ảnh hợp lệ | Owner/holder=B, đúng một event hoàn tất |
| SON-T03 | SELL: A xác nhận tiền, chưa giao | Owner vẫn A, Transaction chưa COMPLETED |
| SON-T04 | SELL: giao đến B, chưa xác nhận tiền | Holder=B, owner=A |
| SON-T05 | SELL: đủ hai điều kiện theo thứ tự bất kỳ | Chuyển owner=B đúng một lần |
| SON-T06 | B bấm "Tôi đã chuyển khoản" | Chỉ phát thông báo, không tự ghi `seller_confirmed_at` |
| SON-T07 | B cố gọi `confirmSellerPayment` | Server từ chối `FORBIDDEN` |
| SON-T08 | Xác nhận tiền hai lần / retry sau timeout | Không nhân đôi event hay chuyển owner |
| SON-T09 | C đã lấy rồi báo giao thất bại | Holder=C, Issue được ghi nhận |
| SON-T10 | Người nhận tranh chấp Handover | Không đổi holder theo lượt tranh chấp |
| SON-T11 | Hủy khi đang chờ xác nhận Handover | Không hủy nhanh (nếu BR-45 được chốt) |
| SON-T12 | Người ngoài giao dịch đọc timeline/Issue | RLS/RPC từ chối |
| SON-T13 | Mượn: B yêu cầu trả nhưng A chưa xác nhận nhận lại | Chưa COMPLETED |
| SON-T14 | UI loading/empty/error/offline và Issue | Hiển thị trạng thái rõ; không tự suy ra thành công |

**Kiểm thử liên thông:** Sơn phối hợp Đăng kiểm thử `confirmHandover` và phối hợp Khanh kiểm thử `approveExchangeRequest`/`requestReturn`; không sửa trực tiếp code của nhau trên nhánh nhóm.

## 10. Việc Sơn cần làm khi nhận tài liệu

- [ ] Đọc và so sánh các mục P6/P7/P9 trong `QUY_TRINH_HOAT_DONG.md` và BR-24–BR-29, BR-34, BR-44–BR-48 trong `QUY_TAC_NGHIEP_VU.md`.
- [ ] Chỉ rõ mục nào đồng ý; đề xuất sửa điểm nào, **trên chính file** này hoặc qua GitHub Issue.
- [ ] Review bảng transition Transaction với Khanh và Đăng; thống nhất sự kiện phát sinh từ các module.
- [ ] Ghi rõ lựa chọn cho các mục [CẦN CHỐT] trước khi tạo enum/service.
- [ ] Viết đặc tả chi tiết các màn hình UI-09, UI-16, UI-17 hoặc cập nhật tài liệu này bằng ảnh/phác thảo UI riêng.
- [ ] Bổ sung test cases/Mock scenarios nếu phát hiện thiếu tình huống.
- [ ] Commit **nội dung Sơn đã rà soát/chỉnh sửa** bằng tài khoản `lydinhson`, mở PR vào `nhom12-65ktpm`, yêu cầu Trường và các thành viên liên quan review.
- [ ] Sau khi PR tài liệu được merge và Contracts được khóa, triển khai UI + business logic + mock/real repository + tests; tạo **các commit code riêng**.

## 11. Các câu hỏi cần ghi quyết định trước khi khóa contracts

| Mã | Vấn đề | Hướng xử lý |
|---|---|---|
| SON-OPEN-01 | Khi có Issue đang mở, trạng thái `NEEDS_RESOLUTION` là trạng thái chính hay nhãn dẫn xuất? | Cùng nhóm quyết định trong `TRANG_THAI_NGHIEP_VU.md` |
| SON-OPEN-02 | Ai có quyền đóng Issue nếu hai bên không đồng thuận? | Chưa có chính sách giải quyết cuối cùng; không cấp quyền tùy tiện |
| SON-OPEN-03 | Hủy sau khi đã duyệt: ai có quyền, trường hợp nào được chấp thuận? | Cần khóa BR-45/WF-OPEN tương ứng |
| SON-OPEN-04 | QR chuyển khoản và thông tin ngân hàng lưu ra sao, ai được xem? | Chỉ sau chấp thuận nếu BR-27 được chốt; giới hạn dữ liệu |
| SON-OPEN-05 | Sau khi nhận tiền, giao thất bại: theo dõi hoàn tiền ngoài app như thế nào? | Ghi Issue và xác nhận đối soát, không tự chuyển tiền |
| SON-OPEN-06 | Bộ sự kiện, mã lỗi, trạng thái và chữ ký repository chính thức là gì? | Khóa tập trung với Trường sau khi nhóm review |

---

## Tóm tắt để Sơn trao đổi trong Pull Request

- **Chức năng riêng:** Transaction lifecycle, QR chuyển khoản, A xác nhận đã nhận tiền, timeline, Issue, thông báo trong ứng dụng.
- **Tích hợp:** Nhận kết quả duyệt của Khanh, kết quả Handover của Đăng, cập nhật quy tắc owner/availability cùng Trường thông qua server RPC.
- **Điều kiện nghiệp vụ bất di bất dịch:** DONATE chỉ chuyển chủ sau giao nhận hợp lệ; SELL chỉ chuyển chủ khi giao nhận và xác nhận tiền đều đủ; BORROW chỉ hoàn tất sau khi A xác nhận nhận lại.
- **Tiêu chí đóng PR tài liệu:** không mâu thuẫn SS-BR/SS-WF, có phần Sơn review thực sự, có test cases và chốt rõ các điểm còn mở cần chốt trước code.
