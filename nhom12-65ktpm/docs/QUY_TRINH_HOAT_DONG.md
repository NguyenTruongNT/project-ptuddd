# QUY TRÌNH HOẠT ĐỘNG STUDYSHARE

> **Mã tài liệu:** SS-WF  
> **Phiên bản:** 1.2 – **BẢN CẬP NHẬT ĐỂ REVIEW**, hai quyết định mới đã chốt; chưa khóa Dart Contracts / SQL schema
> **Dự án:** StudyShare – Ứng dụng di động hỗ trợ cho mượn, chuyển nhượng tài liệu học tập và xác thực giao nhận giữa sinh viên  
> **Nhóm:** 12 – Lớp 65KTPM  
> **Nền tảng:** Flutter/Dart – **Android**, không có giao diện Web  
> **Người tổng hợp:** Nguyễn Văn Trường (nhóm trưởng)  
> **Các thành viên:** Nguyễn Văn Trường, **Vũ Tuấn Khanh**, Vũ Hải Đăng, Lý Đình Sơn  
> **Ngày:** 21/11/2026  
> **Tài liệu quy tắc tham chiếu:** [`QUY_TAC_NGHIEP_VU.md`](./QUY_TAC_NGHIEP_VU.md) (SS-BR v1.2)

---

## 0. Mục đích, phạm vi và cách đọc

Tài liệu này trả lời câu hỏi **“Ai vào màn hình nào, làm gì, với điều kiện gì, dữ liệu/trạng thái nào đổi và nếu lỗi thì xử lý ra sao?”**. Đây là **mô tả quy trình**, không phải lời khẳng định mọi hàm, bảng hay enum đã được lập trình.

**Thứ tự dùng tài liệu trong nhóm:**

1. `QUY_TAC_NGHIEP_VU.md`: quy tắc và quyết định đã chốt.
2. **Tệp này:** trình tự nghiệp vụ và điểm phối hợp giữa các phân hệ.
3. `TRANG_THAI_NGHIEP_VU.md`: bảng chuyển trạng thái chi tiết (**chưa tạo/khóa**).
4. `MO_HINH_DU_LIEU.md` và `HOP_DONG_LAP_TRINH.md`: schema, model, repository interfaces (**chưa tạo/khóa**).
5. Mock Data, source code và tests: phải tuân theo các quyết định đã merge của nhóm.

**Nhãn bắt buộc khi đọc:**

- **[ĐÃ CHỐT]**: quy tắc đã xác nhận; mọi module phải tuân thủ.
- **[ĐỀ XUẤT]**: thiết kế thực thi đang chờ nhóm xác nhận; **AI không được tự coi là yêu cầu đã khóa**.
- **[CẦN CHỐT]**: câu hỏi chưa có quyết định, có mã `WF-OPEN-xx` cuối tài liệu.

**Lưu ý về trạng thái:** Các quyết định **BR-49** (hiển thị RESERVED) và **BR-50** (không bỏ qua QR sai) đã được nhóm trưởng chốt trong v1.2. Những tên enum viết hoa trong tài liệu này chỉ kế thừa hoặc gợi ý từ đề cương/SS-BR. Bảng trạng thái cuối cùng sẽ được khóa trong `TRANG_THAI_NGHIEP_VU.md`; không tự viết thêm enum vì chỉ thấy trong một ví dụ.

### 0.1. Quy tắc nền tảng không được phá vỡ

| Mã liên quan | Bất biến xuyên suốt mọi pipeline |
|---|---|
| BR-02, BR-03, BR-04 | `Material` là **một bản vật lý** có ID/QR cố định; `Listing` là **lượt đăng** chỉ có **một** hình thức `BORROW` / `DONATE` / `SELL`. |
| BR-05, BR-11–BR-14 | Một bản vật lý không có hai giao dịch đã chấp thuận đang hoạt động cùng lúc; duyệt yêu cầu phải **nguyên tử ở server**. |
| BR-17–BR-19 | Mượn không đổi chủ sở hữu; hạn mượn bắt đầu khi bên mượn **thực sự xác nhận nhận**, và hoàn tất khi chủ nhận lại sách. |
| BR-24–BR-26 | Tặng chuyển chủ khi giao nhận hợp lệ; bán chuyển chủ **chỉ sau** giao nhận hợp lệ **và** người bán xác nhận nhận tiền. |
| BR-30–BR-35 | **Mọi lượt bàn giao** phải có ảnh đã được server chấp nhận và **xác nhận của bên nhận**; QR có thể thay bằng đối chiếu thủ công có lý do. |
| BR-38–BR-40, BR-44 | Giao hộ do sinh viên đăng ký và người tạo nhiệm vụ duyệt; nếu C đã lấy nhưng giao thất bại, không tự trả `holder_id` về A. |
| BR-33, BR-35 | Bản nháp/ảnh trên máy khi offline **không phải** bàn giao đã hoàn tất. |

### 0.2. Thuật ngữ và diễn giải thống nhất

- **A**: người sở hữu hiện hành, thường là người đăng tài liệu và chấp thuận yêu cầu.
- **B**: người gửi yêu cầu mượn / nhận tặng / mua.
- **C**: người giao hộ đã được duyệt, có thể là một sinh viên khác A và B.
- **Người giao một chặng**: người có trách nhiệm bàn giao tài liệu tại chặng đó; khi trả sách có thể là B.
- **Người nhận một chặng**: tài khoản được chỉ định nhận trong `Handover` đó.
- **`owner_id`**: người sở hữu được hệ thống ghi nhận; **`holder_id`**: người đang giữ **được xác nhận gần nhất trên server**. Đây không phải bằng chứng tuyệt đối về hiện trạng ngoài đời khi có tranh chấp.
- **Một Transaction có thể có nhiều Handover**. Ví dụ mượn qua C rồi trả qua C tạo **bốn lượt** bàn giao, có ảnh và xác nhận riêng.
- **Xác nhận bàn giao ≠ hoàn tất giao dịch**. Đăng sở hữu thao tác bàn giao; Sơn sở hữu điều kiện kết thúc Transaction.

---

## 1. Bản đồ pipeline và trách nhiệm

| Mã | Quy trình | Điểm bắt đầu → điểm kết thúc | Người sở hữu hành động chính | Phân hệ phối hợp |
|---|---|---|---|---|
| P0 | Xác thực và hồ sơ | Chưa đăng nhập → phiên người dùng hợp lệ | **Trường** | Các module đọc auth state |
| P1 | Đăng bản sách, công bố Listing | Tài liệu mới → Listing hợp lệ, có thể tìm kiếm | **Trường** | Khanh đọc Listing |
| P2 | Tìm kiếm, gửi và duyệt yêu cầu | Listing khả dụng → Transaction được tạo / yêu cầu từ chối | **Khanh** | Trường (Material), Sơn (Transaction) |
| P3 | Bàn giao trực tiếp | Transaction đã duyệt → B hoặc A được xác nhận giữ sách | **Đăng** | Khanh (mượn/trả), Sơn (workflow) |
| P4 | Giao hộ có người thứ ba | Tạo nhiệm vụ → hoàn tất các chặng hoặc xử lý sự cố | **Đăng** | Sơn (Issue), Trường (holder) |
| P5 | Mượn và hoàn trả | B nhận sách → A nhận lại, Transaction hoàn tất | **Khanh** (nghĩa vụ) | Đăng (bàn giao), Sơn (trạng thái) |
| P6 | Chuyển nhượng tặng miễn phí | A duyệt → B nhận → chủ sở hữu chuyển sang B | **Sơn** (hoàn tất) | Khanh (yêu cầu), Đăng (bàn giao) |
| P7 | Chuyển nhượng bán / QR ngân hàng | A duyệt → xác nhận tiền + nhận sách → chuyển chủ | **Sơn** | Khanh, Đăng |
| P8 | Điểm hẹn, GPS và chỉ đường | Xác lập hai điểm → mở hướng dẫn di chuyển | **Đăng** | Các bên liên quan |
| P9 | Hủy, từ chối, giao thất bại, tranh chấp | Phát hiện sự cố → trạng thái an toàn / hướng khắc phục | **Sơn** (Issue) | Chủ hành động phát sinh lỗi |
| P10 | Mất mạng, ảnh chờ gửi và retry | Ảnh chụp trên Android → upload được / vẫn là bản nháp | **Đăng** | Trường (hạ tầng), Sơn (tính nhất quán) |

**Thứ tự xây MVP khuyến nghị:** P0 → P1 → P2 → P3 → P5 → P4 → P6/P7 → P8/P9/P10. Đây là **thứ tự triển khai**, không phải thứ tự cứng mà người dùng phải đi qua.

---

## 2. Danh mục màn hình dùng trong các bước

Các mã UI dưới đây bám theo **đề cương StudyShare**. Nếu một màn hình được tái sử dụng ở nhiều quy trình, **không tạo lại bản thứ hai**.

| UI | Tên màn hình Android | Người phụ trách |
|---|---|---|
| UI-01 | Đăng nhập/đăng ký | Trường |
| UI-02 | Trang chủ | Trường |
| UI-03 | Khám phá/tìm kiếm tài liệu | Khanh |
| UI-04 | Chi tiết tài liệu | Khanh |
| UI-05 | Đăng/sửa tài liệu | Trường |
| UI-06 | Tài liệu của tôi / QR tài liệu | Trường |
| UI-07 | Gửi yêu cầu mượn/mua/nhận tặng | Khanh |
| UI-08 | Yêu cầu đã gửi / yêu cầu nhận được | Khanh |
| UI-09 | Chi tiết Transaction / timeline | Sơn |
| UI-10 | Chọn giao trực tiếp / giao hộ, điểm hẹn | Đăng |
| UI-11 | Danh sách nhiệm vụ giao hộ | Đăng |
| UI-12 | Chi tiết nhiệm vụ giao hộ, GPS/chỉ đường | Đăng |
| UI-13 | Đối chiếu QR, chụp ảnh và gửi minh chứng | Đăng |
| UI-14 | Bên nhận kiểm tra và xác nhận bàn giao | Đăng |
| UI-15 | Quản lý mượn/trả và hạn trả | Khanh |
| UI-16 | Hoạt động và lịch sử | Sơn |
| UI-17 | Thông báo | Sơn |
| UI-18 | Cá nhân và cài đặt | Trường |

**Màn hình bổ sung đề xuất, chưa tăng số UI chính:** QR chuyển khoản/đã nhận tiền là **tab, section hoặc bottom sheet trong UI-09** (Sơn); chọn GPS/điểm hẹn là thành phần của UI-10/UI-12 (Đăng); báo sự cố là màn hình con từ UI-09 hoặc UI-12 (Sơn). Quyết định thiết kế chính thức ở `UI_SPEC.md` sau này.

---

## 3. P0 – Đăng nhập và quản lý tài khoản (Trường)

**Mục tiêu:** Bảo đảm hành động thay đổi dữ liệu luôn gắn với tài khoản xác thực; một sinh viên có thể mang nhiều vai trò theo từng giao dịch. Tham chiếu **BR-01**.

| Bước | Ai – Màn hình – Hành động | Điều kiện/kiểm tra | Dữ liệu hoặc kết quả | Khi thất bại |
|---|---|---|---|---|
| P0.1 | Sinh viên – UI-01 – Chọn Email/Google | Thiết bị có mạng khi xác thực lần đầu; phương thức được cấu hình | Supabase Auth tạo/khôi phục session | Hiển thị lỗi xác thực; không điều hướng vào màn hình riêng tư |
| P0.2 | Hệ thống – nạp hồ sơ | Có `auth.uid`; dữ liệu hồ sơ hợp lệ | Nạp/tạo `Profile` được phép, không tạo role chủ/giao hộ cố định | Có trạng thái cần hoàn thiện hồ sơ nếu thiếu trường bắt buộc **[ĐỀ XUẤT]** |
| P0.3 | Sinh viên – UI-18 – Sửa hồ sơ | Chỉ sửa hồ sơ chính mình | Lưu tên hiển thị, thông tin liên hệ được phép chia sẻ | Lỗi mạng giữ dữ liệu form; không hiển thị đã lưu nếu server chưa ACK |
| P0.4 | Sinh viên – Đăng xuất | Có session | Xóa session và dữ liệu UI riêng tư trên máy theo chính sách | Không tiếp tục sử dụng token cũ để gọi API |

**Kết quả:** Mọi request nghiệp vụ sử dụng danh tính từ session server, không tin `actor_user_id` tùy ý do UI gửi.

---

## 4. P1 – Tạo bản sách và đăng Listing (Trường)

**Điều kiện trước:** A đăng nhập, có quyền sở hữu bản sách vật lý, chưa có giao dịch gây xung đột. **BR-02–BR-10**.

### 4.1. Luồng chính

| Bước | Ai – UI – Hành động | Kiểm tra bắt buộc | Dữ liệu thay đổi / kết quả | Lỗi và nhánh khác |
|---|---|---|---|---|
| P1.1 | A – UI-05 – Chọn **Thêm tài liệu** | Session hợp lệ | Khởi tạo bản nháp chưa công khai | Offline: lưu bản nháp local **[ĐỀ XUẤT]** |
| P1.2 | A – UI-05 – Nhập tên, môn/loại, tình trạng; chụp ảnh | Ảnh và trường bắt buộc trước khi công bố **[BR-08 ĐỀ XUẤT]** | Lưu ảnh tạm, form metadata | Thiếu ảnh/trường: thông báo field error |
| P1.3 | A – UI-05 – Chọn đúng **một** hình thức `BORROW`/`DONATE`/`SELL` | Với SELL có giá > 0 VND **[ĐỀ XUẤT]** | Xác lập `Listing.offer_type`; nếu SELL giữ `asking_price_vnd` | Không cho chọn đồng thời nhiều hình thức |
| P1.4 | A – UI-05 – Bấm **Lưu bản nháp** hoặc **Đăng công khai** | Kiểm tra chủ sở hữu, giới hạn Listing hiện hành | Tạo/cập nhật Material; tạo Listing ở DRAFT/PUBLISHED | Server từ chối nếu không có quyền / có Listing xung đột |
| P1.5 | Server – định danh bản vật lý | Mỗi bản vật lý ID riêng | UUID Material và QR token; QR nội bộ có thể tạo rồi hiển thị trên UI-06 | ISBN giống nhau **không** gây trùng ID |
| P1.6 | A – UI-06 – Xem và quản lý tài liệu | Chỉ tài liệu A có quyền | Hiển thị Listing, mã QR, tình trạng khả dụng từ dữ liệu server | Khi RESERVED/ON_LOAN không cho đổi giá/hình thức trái quy tắc |
| P1.7 | B – UI-03 – Tìm thấy tài liệu | Listing `PUBLISHED`, kể cả khi Material `RESERVED` | Nếu `RESERVED`, hiển thị nhãn **Đã được đặt**, nút **Gửi yêu cầu** bị khóa **[BR-49 ĐÃ CHỐT]** | Listing `ARCHIVED` không nằm trong khám phá thông thường; server từ chối yêu cầu khi Material không khả dụng |

### 4.2. Quy tắc khi sửa, ẩn và đăng lại

- Chỉ A (owner hiện hành) có quyền sửa/ẩn; server xác thực quyền **BR-06**.
- Khi Listing đang có Transaction hoạt động, **không đổi** giá, offer type, các điều kiện đã chốt; Transaction lưu ảnh chụp thỏa thuận tại lúc duyệt **[ĐỀ XUẤT]**.
- Sau mượn/trả, **không tự tạo Listing mới** **[BR-07 ĐỀ XUẤT; OPEN-01]**; chủ sách có quyền đăng lại.
- Khi chuyển chủ sau DONATE/SELL, Listing của A kết thúc; cùng Material ID có thể có Listing mới do B tạo sau này **BR-03, BR-10**.
- Mọi thay đổi quyền sở hữu là hệ quả nghiệp vụ server, **không** phải nút tự sửa `owner_id`.

**Hành động mở cho module khác:** UI-03/UI-04 của Khanh chỉ đọc `Listing` và khả dụng đã tính theo server; không tự làm `Material.status = AVAILABLE`.

---

## 5. P2 – Tìm kiếm, gửi yêu cầu, lựa chọn và duyệt (Khanh)

**Điều kiện trước:** Listing còn hiệu lực và hợp lệ; người yêu cầu B khác A. Tham chiếu **BR-11–BR-16**.

### 5.1. Người nhận gửi yêu cầu

| Bước | Ai – UI – Hành động | Điều kiện/kiểm tra | Dữ liệu / trạng thái | Trường hợp lỗi |
|---|---|---|---|---|
| P2.1 | B – UI-03 – Tìm/lọc môn học, mượn/tặng/bán | Listing `PUBLISHED`; `ARCHIVED` không hiển thị trong khám phá thông thường | Kết quả danh sách, bao gồm mục `RESERVED` có nhãn **Đã được đặt** **[BR-49 ĐÃ CHỐT]** | Empty/loading/error, thử lại |
| P2.2 | B – UI-04 – Xem thông tin thật của bản sách | Có Listing `PUBLISHED` | Xem ảnh, chủ sách, offer; nếu `RESERVED` hiện nhãn **Đã được đặt** | `RESERVED`: khóa nút Gửi yêu cầu **[BR-49 ĐÃ CHỐT]** |
| P2.3 | B – UI-07 – Điền yêu cầu | BORROW: đề xuất số ngày; SELL: giá hiển thị; DONATE: không có tiền | Form yêu cầu, ghi chú, khu vực nhận nếu chọn chia sẻ **[OPEN-05]** | Thiếu dữ liệu: validation |
| P2.4 | B – UI-07 – **Gửi yêu cầu** | Session; Listing PUBLISHED và Material còn khả dụng **[BR-49 ĐÃ CHỐT]**; không tự yêu cầu sách mình/không gửi trùng **[BR-15 ĐỀ XUẤT]** | `ExchangeRequest(PENDING)` và `created_at` **do server tạo** | Nếu Material chuyển RESERVED giữa lúc xem và gửi, server từ chối; không tạo yêu cầu |
| P2.5 | A – UI-08 – Mở danh sách yêu cầu đến | Là owner hiện hành, request PENDING | Thời điểm gửi, người yêu cầu, loại giao dịch; **sắp cũ nhất trước [ĐỀ XUẤT]** | Không dùng timestamp điện thoại để xếp hàng |

**Không áp dụng FIFO bắt buộc:** A được chọn một người bất kỳ trong số yêu cầu hợp lệ; `created_at` chỉ hỗ trợ cân nhắc công bằng, không tự quyết người trúng.

### 5.2. A duyệt một yêu cầu – thao tác server nguyên tử

| Bước | Ai – UI – Hành động | Kiểm tra server | Dữ liệu cập nhật trong **một transaction** | Lỗi và kết quả |
|---|---|---|---|---|
| P2.6 | A – UI-08 – Bấm **Chấp thuận yêu cầu B** | A đúng owner; request B PENDING; Listing hợp lệ; Material chưa có giao dịch active | Khóa/kiểm soát cạnh tranh trên Material | Nếu hai người thao tác gần nhau, chỉ một thành công |
| P2.7 | Server – duyệt | Tất cả điều kiện vẫn đúng khi ghi | Request B → ACCEPTED; mọi request PENDING cạnh tranh → REJECTED (`MATERIAL_UNAVAILABLE`) | Không cập nhật nửa chừng; lỗi → rollback toàn bộ |
| P2.8 | Server – giữ chỗ, tạo Transaction | Dữ liệu đã kiểm tra | Material không còn khả dụng; Transaction tạo trạng thái chờ bàn giao; ghi event, snapshot điều kiện | Nếu tạo Transaction lỗi, rollback cả trạng thái request |
| P2.9 | A, B – UI-08/UI-09 | Server trả ACK | Cùng nhìn thấy giao dịch mới; các yêu cầu khác có kết quả từ chối | UI không dự đoán đã ACCEPTED trước ACK |
| P2.10 | A – UI-08 – Bấm **Từ chối** một request khác | Request còn PENDING và A có quyền | REJECTED với lý do | Không được tác động Transaction khác |

**Hủy request PENDING [ĐỀ XUẤT]:** B được tự hủy khi còn PENDING. Request đã ACCEPTED **không** đổi ngược về PENDING/CANCELLED; chuyển sang pipeline hủy Transaction P9.

### 5.3. Điểm giao sang module khác

- **Trường:** cung cấp kiểm tra Material/Listing còn khả dụng, không trực tiếp duyệt thay Khanh.
- **Sơn:** sở hữu quy tắc trạng thái của Transaction được tạo và timeline; **không tự tạo một Transaction thứ hai**.
- **Đăng:** chỉ bắt đầu chọn cách giao khi Transaction đã tạo thành công.

---

## 6. P3 – Giao trực tiếp (Đăng)

**Điều kiện trước:** Transaction hợp lệ, A (hoặc người giữ ở chặng trả) và người nhận được xác định. **BR-30–BR-36, BR-37**.

### 6.1. Luồng một Handover trực tiếp

| Bước | Ai – UI – Hành động | Điều kiện/kiểm tra | Dữ liệu / trạng thái | Lỗi và phương án |
|---|---|---|---|---|
| P3.1 | Bên gửi – UI-10 – Chọn **Giao trực tiếp** | Transaction đang chờ bàn giao/chờ trả | Xác định `from_user_id`, `to_user_id`, điểm hẹn | Người gửi không đúng holder ghi nhận: từ chối |
| P3.2 | Server – tạo Handover | Bên gửi và nhận khác nhau, thuộc Transaction, có quyền | `Handover(PENDING)` với ID ổn định | Không tạo nhiều Handover active trùng chặng **[ĐỀ XUẤT]** |
| P3.3 | Bên gửi – UI-13 – Đối chiếu tài liệu | Ưu tiên QR Material; **thiếu QR/camera không đọc được** thì dùng QR lượt giao hoặc thủ công có lý do **[BR-32]** | Ghi `verification_method` và kết quả đối chiếu hợp lệ | **QR đã đọc nhưng không khớp:** chặn bàn giao, không được chuyển thủ công để bỏ qua; đối chiếu lại **[BR-50]** |
| P3.4 | Bên gửi – UI-13 – **Chụp ít nhất 1 ảnh** | Camera cấp quyền; hình là ảnh cho Handover này | Ảnh cục bộ gắn `handover_id` | Từ chối quyền camera/chưa có ảnh: không gửi xác nhận |
| P3.5 | Bên gửi – **Gửi minh chứng** | Ảnh tải lên Storage private và được server ghi nhận; quyền đúng | Handover → `AWAITING_RECEIVER_CONFIRMATION`; tạo Evidence | Offline/upload lỗi: giữ bản nháp, không coi server đã nhận |
| P3.6 | Bên nhận – UI-14 – Xem ảnh, tài liệu, người giao | Đúng tài khoản `to_user_id` | Hiển thị thông tin bản giao và ảnh private được cấp quyền | Chưa có evidence server: không bật Xác nhận |
| P3.7a | Bên nhận – **Xác nhận đã nhận** | Handover chờ, có ảnh; không thay người giao | **Nguyên tử:** Handover → CONFIRMED, holder đổi sang bên nhận, ghi event; cập nhật Transaction nếu đủ điều kiện | Nhấn hai lần/retry không chuyển holder lần 2 |
| P3.7b | Bên nhận – **Báo vấn đề** | Có lý do sai sách, thiếu ảnh, chưa nhận, hư hỏng... | Handover → DISPUTED, tạo Issue, **không đổi holder theo lượt này** | Chuyển sang P9 xử lý |

**Điều kiện nghiệm thu:** Một người **không thể tự bấm cả gửi và xác nhận nhận** cho cùng Handover. Ảnh được tải lên thành công **không tương đương** người nhận đã nhận.

### 6.2. Nhánh sử dụng lại

- **Giao sách cho B khi mượn:** cuối P3.7a → P5 bắt đầu kỳ mượn.
- **Tặng/bán cho B:** cuối P3.7a → P6/P7 kiểm tra điều kiện chuyển chủ.
- **Trả sách từ B về A:** cuối P3.7a → P5 kiểm tra hoàn tất.

---

## 7. P4 – Giao hộ qua một sinh viên thứ ba (Đăng)

**Điều kiện trước:** Transaction hợp lệ và có bên đang giữ sách. **BR-38–BR-44**.

### 7.1. Nhận nhiệm vụ và chọn người giao hộ

| Bước | Ai – UI – Hành động | Điều kiện/kiểm tra | Dữ liệu / trạng thái | Lỗi |
|---|---|---|---|---|
| P4.1 | Người đang giữ sách – UI-10 – Chọn **Giao hộ** | Có quyền tạo nhiệm vụ ở chặng hiện tại | `DeliveryTask(OPEN)` với người gửi và người nhận cuối, điểm lấy/giao | Thiếu điểm hẹn mô tả: yêu cầu bổ sung **[BR-42 ĐỀ XUẤT]** |
| P4.2 | C – UI-11 – Xem nhiệm vụ có thể nhận | Đăng nhập; C khác hai bên nhiệm vụ **[BR-41 ĐỀ XUẤT]** | Danh sách nhiệm vụ OPEN phù hợp quyền xem | Không công khai địa chỉ riêng tư đầy đủ cho người chưa được chọn |
| P4.3 | C – UI-12 – **Đăng ký giao hộ** | Chưa được phân công người khác; C không gửi trùng đơn ứng tuyển **[ĐỀ XUẤT]** | DeliveryApplication PENDING | Nhiệm vụ đã khóa: báo hết chỗ |
| P4.4 | Người tạo nhiệm vụ – UI-12 – Xem ứng viên và **duyệt C** | Tài khoản tạo nhiệm vụ; chưa có courier được duyệt | Một C ASSIGNED; ứng viên còn lại từ chối/đóng **[ĐỀ XUẤT]** | Duyệt đồng thời: chỉ một người được nhận |
| P4.5 | C – UI-12 – Xem điểm lấy và chỉ đường | C đã được duyệt | Thấy điểm hẹn phù hợp; có thể mở Maps | GPS từ chối: dùng mô tả địa điểm; không khóa nhiệm vụ |

### 7.2. Hai lượt bàn giao bắt buộc

| Bước | Lượt | Ai thực hiện | Cách xử lý / cập nhật |
|---|---|---|---|
| P4.6 | **H1: Người gửi → C** | Người gửi chụp ảnh và gửi minh chứng; **C xác nhận đã nhận** | Dùng **toàn bộ P3.2–P3.7**; sau CONFIRMED, holder = C, nhiệm vụ đạt PICKED_UP |
| P4.7 | **H2: C → Người nhận cuối** | C di chuyển, đối chiếu QR/thủ công, chụp ảnh; **bên nhận cuối xác nhận** | Dùng **toàn bộ P3.2–P3.7**; sau CONFIRMED, holder = người nhận cuối, nhiệm vụ COMPLETED |
| P4.8 | Kết quả chặng cuối | Server và UI-09 | Mượn → P5 bắt đầu mượn; DONATE/SELL → P6/P7 kiểm tra hoàn tất |

**Không được làm:** C tự nhấn “Đã giao” rồi cập nhật holder = B khi B chưa xác nhận. Không dùng ảnh H1 thay thế ảnh H2.

### 7.3. Người giao hộ gặp sự cố

- **C rút trước khi H1 được xác nhận:** người tạo nhiệm vụ có thể hủy phân công, chọn C khác **[ĐỀ XUẤT]**.
- **C đã được xác nhận cầm sách nhưng giao thất bại:** holder **vẫn là C**; mở Issue; chọn giao lại hoặc **tạo Handover mới** để trả về người gửi, không xóa H1.
- **B không phản hồi xác nhận H2:** H2 vẫn chờ; C có thể gửi nhắc hoặc báo Issue; không tự `CONFIRMED` theo thời gian.
- **B báo tài liệu hư/hỏng:** H2 → DISPUTED; giữ người giữ đã xác nhận gần nhất, đưa P9 đối soát.

### 7.4. Giao hộ chiều trả

Người tạo nhiệm vụ ở lượt trả có thể là **B đang giữ sách**. Nếu B nhờ D giao trả A, đó là **DeliveryTask mới** và hai Handover **B → D → A**. Không sử dụng lại nhiệm vụ A → C → B của chiều cho mượn.

---

## 8. P5 – Cho mượn, tính hạn và trả sách (Khanh + Đăng + Sơn)

**Điều kiện:** Transaction có hình thức `BORROW`, chưa hoàn tất. **BR-17–BR-23**.

### 8.1. Thỏa thuận và nhận sách

| Bước | Ai – UI – Hành động | Điều kiện | Dữ liệu/kết quả | Ngoại lệ |
|---|---|---|---|---|
| P5.1 | B – UI-07 – Đề xuất số ngày mượn | Số ngày > 0, trong giới hạn sẽ chốt **[OPEN-02]** | `requested_borrow_days` trong request **[BR-20 ĐỀ XUẤT]** | Không nhập hợp lệ: báo lỗi |
| P5.2 | A – UI-08 – Duyệt | A đồng ý số ngày B đề xuất; chưa thương lượng trong MVP **[ĐỀ XUẤT]** | Sao chép `agreed_borrow_days` vào thỏa thuận giao dịch | A không đồng ý: REJECTED; B có thể gửi yêu cầu mới nếu còn Listing |
| P5.3 | A/B/C – UI-10 đến UI-14 – Bàn giao | Giao trực tiếp P3 hoặc giao hộ P4, có ảnh từng Handover | Khi **B xác nhận Handover cuối và server ACK**, holder = B | B chưa xác nhận: chưa bắt đầu kỳ mượn |
| P5.4 | Server – bắt đầu kỳ mượn | P5.3 thành công; lần đầu B nhận sách của giao dịch | `BorrowingRecord.started_at` lấy timestamp server; Transaction → BORROWING | Không cho client tự đặt thời gian nhận |
| P5.5 | Server – tính hạn | Có số ngày đã chốt | `due_date` từ **ngày nhận theo Asia/Ho_Chi_Minh + số ngày** **[BR-21 ĐỀ XUẤT]** | Không đủ dữ liệu: chặn chuyển sang BORROWING và ghi lỗi nhất quán |

**Ví dụ đề xuất:** Nếu B nhận hợp lệ ngày 21/11/2026, số ngày 7 thì hạn cuối **28/11/2026** theo ngày lịch Việt Nam; quá hạn sau hết ngày đó. Quy tắc giờ/ngày chính thức vẫn cần khóa ở OPEN-07.

### 8.2. Theo dõi và trả sách

| Bước | Ai – UI – Hành động | Điều kiện | Dữ liệu/kết quả | Ngoại lệ |
|---|---|---|---|---|
| P5.6 | B/A – UI-15/UI-09 – Xem trạng thái mượn | B hoặc A có quyền | Hiển thị ngày nhận, ngày hạn, người giữ | `OVERDUE` là nhãn tính từ thời gian, không ghi đè Transaction.status |
| P5.7 | B – UI-15 – Bấm **Yêu cầu trả** | B là người mượn; Transaction BORROWING | Transaction → RETURN_PENDING hoặc nghiệp vụ trả tương đương | Bấm lặp: không tạo nhiều yêu cầu trả |
| P5.8 | B – UI-10 – Chọn trực tiếp/giao hộ | Đang có nghĩa vụ hoàn trả; B/courier giữ hợp lệ | Tạo Handover B→A hoặc DeliveryTask trả | Chọn giao hộ phải qua P4 từ đầu |
| P5.9 | Các bên – UI-13/UI-14 – Bàn giao trả | **Mỗi chặng** đủ ảnh + bên nhận xác nhận | Handover được xác nhận; holder chuyển dần theo từng chặng | Chỉ bấm “Tôi đã trả” không làm giao dịch hoàn tất |
| P5.10 | **A xác nhận nhận lại** | A là chủ sở hữu; Handover cuối → A CONFIRMED | **Nguyên tử ở server:** BorrowingRecord kết thúc, Transaction → COMPLETED, giải phóng Material | A báo hư/hỏng: Handover DISPUTED, Issue, không hoàn tất |
| P5.11 | A – UI-06 – Quản lý sau trả | P5.10 ACK | Material lại khả dụng; Listing cũ **không tự công khai** **[BR-07 ĐỀ XUẤT]** | Muốn cho mượn lần sau: tạo/công bố Listing mới nếu nhóm chốt |

**Quyền sở hữu:** Trong tất cả P5, `Material.owner_id = A` không thay đổi; `holder_id` chuyển qua C/B/D theo các Handover CONFIRMED.

---

## 9. P6 – Chuyển nhượng tặng miễn phí (Sơn + Khanh + Đăng)

**Điều kiện:** Listing `DONATE`; người yêu cầu B được A duyệt. **BR-24, BR-30–BR-35**.

| Bước | Ai – UI – Hành động | Điều kiện | Dữ liệu/kết quả | Nhánh lỗi |
|---|---|---|---|---|
| P6.1 | B – UI-04/UI-07 – Chọn **Nhận miễn phí** | Listing DONATE khả dụng | Request PENDING | Hết khả dụng: từ chối tạo |
| P6.2 | A – UI-08 – Duyệt B | P2 xử lý nguyên tử | Request ACCEPTED; Transaction TRANSFER/DONATE, giữ chỗ | Request khác REJECTED |
| P6.3 | A/B/C – UI-10 đến UI-14 – Giao trực tiếp hoặc hộ | P3/P4, mỗi Handover có ảnh và xác nhận | Holder cuối = B sau ACK | B chưa xác nhận: chưa chuyển chủ |
| P6.4 | Server – kết thúc tặng | Handover cuối đến B CONFIRMED | **Nguyên tử:** Transaction COMPLETED, owner = B, holder = B, Listing cũ ARCHIVED, ghi event | Không có bước thanh toán |
| P6.5 | B – UI-06 – Quản lý tài liệu mới | Server đã cập nhật owner | B có quyền xem/sở hữu Material; có thể tạo Listing mới **[BR-10 ĐỀ XUẤT]** | Không tự dùng Listing của A để đăng tiếp |

---

## 10. P7 – Chuyển nhượng bán, QR chuyển khoản và xác nhận tiền (Sơn)

**Điều kiện:** Listing `SELL` có giá; **không** tích hợp ngân hàng, không tự xác minh chuyển khoản. Tham chiếu **BR-25–BR-29**.

### 10.1. Quy trình yêu cầu mua và QR

| Bước | Ai – UI – Hành động | Điều kiện | Dữ liệu/kết quả | Ngoại lệ |
|---|---|---|---|---|
| P7.1 | B – UI-04/UI-07 – Bấm **Mua tài liệu** | Listing SELL còn hiệu lực | Request PENDING, **chưa được yêu cầu chuyển tiền** | Không hiển thị QR chuyển khoản trước duyệt **[BR-27 ĐỀ XUẤT]** |
| P7.2 | A – UI-08 – Chấp thuận | P2 nguyên tử | Transaction SELL với giá niêm yết được **snapshot lúc duyệt** **[BR-28 ĐỀ XUẤT]** | A từ chối: không phát sinh giao dịch/QR thanh toán |
| P7.3 | B – UI-09 – Xem QR chuyển khoản A | Transaction đã duyệt; thông tin nhận tiền do A khai báo | Hiển thị ngân hàng, người nhận, số tiền, nội dung/mã tham chiếu | Không yêu cầu/không lưu mật khẩu, OTP ngân hàng |
| P7.4 | B – app ngân hàng **ngoài StudyShare** – Chuyển khoản | B tự quyết định thao tác chuyển | StudyShare **không biết tự động** tiền thành công hay không | App ngân hàng lỗi: trong StudyShare vẫn chưa xác nhận |
| P7.5 | B – UI-09 – Bấm **Tôi đã chuyển khoản** (nếu có) | Transaction SELL chưa hoàn tất | Chỉ gửi **thông báo** cho A, không đánh dấu tiền đã đến **[ĐỀ XUẤT]** | Không được tự hoàn tất giao dịch |
| P7.6 | A – UI-09 – Tự kiểm tra ngân hàng và bấm **Đã nhận tiền** | A là người bán của Transaction, chưa xác nhận trước đó | Server lưu `seller_confirmed_at`, số tiền snapshot, actor và event | Bấm lặp không tạo hai lần xác nhận |

**Lưu ý quan trọng:** Đây là **ghi nhận xác nhận của A**, không phải StudyShare bảo đảm có giao dịch ngân hàng thật. Với dữ liệu demo, tránh đưa thông tin tài khoản ngân hàng nhạy cảm hoặc ảnh chuyển khoản cá nhân vào fixture công khai.

### 10.2. Hai điều kiện để kết thúc SELL

| Giao nhận cuối tới B | A xác nhận tiền | Quyền giữ | Chủ sở hữu trên StudyShare | Transaction |
|---|---|---|---|---|
| Chưa | Chưa | Người giữ gần nhất | A | Đang chờ bàn giao/thanh toán |
| Chưa | **Rồi** | Người giữ gần nhất | A | Chưa hoàn tất; chờ bàn giao |
| **Rồi** | Chưa | **B** | **A** | Chờ xác nhận tiền |
| **Rồi** | **Rồi** | **B** | **B** | **COMPLETED** |

**Quy tắc nguyên tử:** Sự kiện cuối cùng trong hai điều kiện (P7.6 hoặc Handover cuối CONFIRMED) kích hoạt server kiểm tra và **chuyển owner đúng một lần**, đồng thời ARCHIVE Listing cũ và ghi event. **Không quan trọng xác nhận tiền trước hay giao sách trước**; luồng ưu tiên là nhận tiền trước giao sách **[BR-29 ĐỀ XUẤT]**.

**Chưa triển khai:** thanh toán trong app, thanh toán QR tự xác minh, đối soát API ngân hàng, ví nội bộ, hoàn tiền tự động, COD đa phương thức nếu chưa được nhóm chốt.

---

## 11. P8 – Điểm hẹn, GPS và chỉ đường (Đăng)

**Mục tiêu:** Hỗ trợ di chuyển **từ điểm lấy đến điểm giao**, không thay thế xác nhận bàn giao. **BR-40 [ĐÃ CHỐT]; BR-42–BR-43 [ĐỀ XUẤT]**.

| Bước | Ai – UI – Hành động | Điều kiện/kiểm tra | Dữ liệu/kết quả | Khi từ chối GPS / lỗi |
|---|---|---|---|---|
| P8.1 | Người gửi/nhận – UI-10 – Thống nhất điểm hẹn | Mô tả điểm lấy và điểm giao **[ĐỀ XUẤT]** | `pickup_point`, `dropoff_point`: tên/mô tả, tọa độ nếu có | Người dùng nhập mô tả thủ công |
| P8.2 | Người dùng – UI-10 – Dùng **Vị trí của tôi** | Hỏi quyền vị trí Android tại thời điểm cần | Lấy vị trí tham khảo; người dùng xác nhận đây là điểm hẹn | Từ chối/cấp gần đúng: không chặn quy trình |
| P8.3 | C – UI-12 – Xem nhiệm vụ đã được duyệt | C có quyền xem; nhiệm vụ hợp lệ | Hiển thị điểm lấy, điểm giao, ghi chú | Chưa được duyệt: không hiện địa chỉ chi tiết **[ĐỀ XUẤT]** |
| P8.4 | C – UI-12 – Chọn **Chỉ đường đến điểm lấy** | Có vị trí/địa chỉ đủ dùng | Mở ứng dụng bản đồ/URL chỉ đường | Không mở được Maps: hiển thị địa chỉ để sao chép |
| P8.5 | C – UI-12 – Sau H1 CONFIRMED, chọn **Chỉ đường đến điểm giao** | C đang giữ sách | Mở hướng dẫn tuyến tiếp theo | Không tự suy ra “đã lấy” chỉ vì GPS ở gần điểm lấy |
| P8.6 | Các bên – UI-13/UI-14 – Xác nhận giao | Áp dụng P3/P4 | Ảnh và xác nhận quyết định việc bàn giao | Tọa độ/chỉ đường không đủ chứng minh bàn giao |

**Không có trong v1.1 nếu chưa chốt thêm:** theo dõi vị trí C theo thời gian thực, background location, thuật toán tối ưu tuyến, phí giao theo km.

---

## 12. P9 – Hủy, giao thất bại, bất đồng và xử lý sự cố (Sơn)

### 12.1. Ma trận ngoại lệ và hành động

| Mã | Tình huống | Màn hình phát sinh | Hệ thống phải làm | Hành động tiếp theo | Owner |
|---|---|---|---|---|---|
| E-01 | A vừa duyệt B thì C/D cũng yêu cầu sách | UI-08 | Chặn duyệt trùng; request còn lại REJECTED do hết khả dụng | Thông báo kết quả | Khanh |
| E-02 | B muốn hủy request PENDING | UI-08 | Cho hủy khi còn PENDING **[ĐỀ XUẤT]** | Không tạo Transaction | Khanh |
| E-03 | Hủy sau duyệt nhưng chưa bàn giao/tiền | UI-09 | Kiểm tra điều kiện server; rollback nghiệp vụ hủy theo chính sách **[BR-45 ĐỀ XUẤT]** | Giải phóng Material khi an toàn, ghi event | Sơn |
| E-04 | Hủy sau khi Handover đã gửi hoặc đã xác nhận | UI-09 | Không cho hủy một nút; có thể đã chuyển sách thật | Tạo Issue / trả sách / đối soát | Sơn + Đăng |
| E-05 | QR đã đọc nhưng không khớp Material/Handover | UI-13 | Thông báo sai mã; **chặn xác nhận lượt giao** **[BR-50]** | Kiểm tra lại sách và quét/đối chiếu đúng mã; **không được dùng thủ công để bỏ qua mã sai** | Đăng |
| E-06 | Không có ảnh / ảnh upload lỗi | UI-13 | Không cho server chuyển sang chờ người nhận | Lưu nháp và thử gửi lại | Đăng |
| E-07 | Người nhận không phản hồi | UI-14 / UI-09 | Giữ Handover đang chờ, **không tự xác nhận** | Nhắc, tạo Issue khi cần | Sơn + Đăng |
| E-08 | Người nhận báo sai/hỏng/chưa nhận | UI-14 | Handover DISPUTED, không đổi holder, tạo Issue | Xác minh, tạo lượt giao thay thế/hoàn trả | Sơn + Đăng |
| E-09 | C đã lấy, không giao được | UI-12 | Holder vẫn là C; ghi lý do thất bại | Giao lại hoặc tạo Handover trả về bên gửi | Đăng + Sơn |
| E-10 | Đã xác nhận tiền, chưa giao sách | UI-09 | Owner vẫn A; không cho hủy đơn giản **[ĐỀ XUẤT]** | Hoàn tất giao hoặc xử lý hoàn tiền ngoài app qua Issue | Sơn |
| E-11 | B đã nhận SELL, A chưa xác nhận tiền | UI-09 | Holder B, owner A, Transaction chưa hoàn tất | A kiểm tra rồi xác nhận hoặc tạo Issue | Sơn |
| E-12 | B quá hạn trả | UI-15 | `OVERDUE` hiển thị theo ngày, không tự kết thúc | B tạo yêu cầu trả; thông báo | Khanh + Sơn |
| E-13 | User khác đọc ảnh/cập nhật giao dịch | Mọi UI | RLS/RPC từ chối | Hiển thị không có quyền, không lộ ảnh | Chủ module + Trường |
| E-14 | Gửi lại thao tác xác nhận sau timeout | UI-13/UI-14 | Không sinh hai lần chuyển holder/event | Trả trạng thái hiện có/cho tải lại | Đăng + Sơn |

### 12.2. Quy trình Issue khi bàn giao tranh chấp

1. Bên liên quan bấm **Báo vấn đề** trên UI-14/UI-09/UI-12 và chọn lý do.
2. Server ghi `Issue` với Transaction/Handover, người báo, thời điểm, mô tả và bằng chứng liên quan (chỉ các bên có quyền xem).
3. UI-09/UI-16 hiển thị **cần xử lý**; **không** tự sửa `holder_id`/`owner_id` để cho giao dịch có vẻ hoàn tất.
4. **[ĐỀ XUẤT]** Các bên chọn hướng: thử giao lại, trả về người gửi qua Handover mới, hoặc để trạng thái chờ đối soát; mọi kết quả phải có event.
5. **[CẦN CHỐT: WF-OPEN-06]** Ai được kết luận tranh chấp kéo dài và đóng Issue khi hai bên không đồng ý? MVP chưa xây giao diện Admin đầy đủ.

**Chỉ được đóng giao dịch do điều kiện nghiệp vụ thỏa mãn**, không được đóng bằng cách sửa thủ công trường status trong database từ UI.

---

## 13. P10 – Offline ảnh, upload và retry (Đăng + Trường)

**Phạm vi:** bản nháp đăng tài liệu, ảnh và yêu cầu gửi minh chứng; **không** tự duyệt request, đổi người giữ hay chuyển chủ khi offline. **BR-35**.

| Bước | Ai – Hành động | Local / Cloud | Trạng thái hiển thị | Quy tắc lỗi |
|---|---|---|---|---|
| P10.1 | Người giao mở Handover đã được server tạo trước đó | Lưu `handover_id`, trạng thái hiện có | Chờ chụp ảnh | Khi hoàn toàn offline chưa có `handover_id`, chỉ tạo nháp; không tự tạo Handover đã có quyền **[ĐỀ XUẤT]** |
| P10.2 | Người giao chụp ảnh | File riêng tư trên Android, gắn Handover/nháp | `Đã chụp – chưa gửi` | Không đưa file cá nhân vào GitHub hoặc public Storage |
| P10.3 | App upload ảnh lên Storage private | Cloud ghi nhận file và Evidence | `Đang tải` → `Đã gửi minh chứng` | Lỗi mạng giữ file, không xóa nháp; retry theo ý người dùng/foreground **[ĐỀ XUẤT]** |
| P10.4 | Server kiểm tra Evidence | Kiểm tra quyền actor, Handover, storage path, số ảnh | Handover → `AWAITING_RECEIVER_CONFIRMATION` | Chưa có ảnh hợp lệ: từ chối chuyển trạng thái |
| P10.5 | Bên nhận xác nhận qua server | Cloud transaction | `Đã xác nhận bàn giao` | Chỉ đổi holder sau ACK server |
| P10.6 | App dọn file cục bộ | Sau khi chắc chắn cloud đã lưu/không cần retry | Không còn cảnh báo nháp | Không xóa trước khi nhận ACK hợp lệ |

### Chống nhân bản (idempotency) – đề xuất kỹ thuật

- Một Handover có **UUID ổn định**; retry không sinh Handover mới tùy ý.
- Upload ảnh nên sử dụng **đường dẫn đối tượng xác định** và kiểm tra trùng; server chỉ gắn Evidence thuộc Handover hợp lệ.
- Xác nhận Handover/tiền/yêu cầu có kiểm tra trạng thái hiện hành, không tạo thêm event hoặc chuyển holder lặp lại.
- **Không hứa đồng bộ nền liên tục** trong MVP; ưu tiên gửi khi ứng dụng đang mở, khi trở lại foreground hoặc khi người dùng bấm thử lại **[ĐỀ XUẤT]**.
- Ảnh ở local không chứng minh upload thành công; trạng thái phải ghi rõ `Chưa gửi` / `Chờ người nhận` / `Đã xác nhận`.

---

## 14. Các kịch bản xuyên suốt để chạy cùng Mock Data

### E2E-01 – Cho mượn trực tiếp rồi trả trực tiếp

**Fixture ban đầu:** A sở hữu & giữ Material M1; Listing L1 = BORROW PUBLISHED; B đăng nhập.

1. B → yêu cầu mượn 7 ngày (`PENDING`), A duyệt (`ACCEPTED`); Transaction T1 được tạo; M1 được giữ chỗ.
2. A → B, **Handover H1** có ảnh server và B xác nhận. `owner=M1:A`, `holder=M1:B`; T1 → BORROWING; `started_at` lấy từ server.
3. B gửi yêu cầu trả, B → A, **Handover H2** có ảnh server và A xác nhận. `owner=A`, `holder=A`; T1 → COMPLETED.
4. Listing cũ không tự công khai lại **[ĐỀ XUẤT]**.

**Phải kiểm chứng:** Không có ảnh H1/H2 thì không được xác nhận; ngày hạn không tính từ ngày A duyệt.

### E2E-02 – Cho mượn qua C, trả qua người giao hộ khác D

1. Tạo T1 mượn; bên gửi A tạo DeliveryTask DT1; C ứng tuyển và được duyệt.
2. H1 A→C: A chụp ảnh, C xác nhận ⇒ holder=C.
3. H2 C→B: C chụp ảnh, B xác nhận ⇒ holder=B, bắt đầu BORROWING.
4. B yêu cầu trả; tạo **DeliveryTask DT2 mới**; D được duyệt.
5. H3 B→D: B chụp ảnh, D xác nhận ⇒ holder=D.
6. H4 D→A: D chụp ảnh, A xác nhận ⇒ holder=A, T1 COMPLETED.

**Phải kiểm chứng:** Có **4 Handover và ≥4 ảnh**, không tái sử dụng nhiệm vụ/ảnh chiều đi cho chiều trả.

### E2E-03 – A tặng B miễn phí

A đăng Listing DONATE → B yêu cầu → A duyệt → A/C bàn giao có ảnh và B xác nhận → owner/holder cùng là B → Transaction COMPLETED → Listing cũ archived.

### E2E-04 – A bán B: tiền trước, sách sau

A đăng Listing SELL (ví dụ 50.000 VND) → B yêu cầu → A duyệt → B xem QR chuyển khoản, chuyển khoản ngoài app → A kiểm tra và xác nhận đã nhận tiền → A/C bàn giao (ảnh + B xác nhận) → chuyển `owner` từ A sang B đúng một lần, Transaction COMPLETED.

### E2E-05 – A bán B: sách trước, tiền sau

A duyệt B → Handover đến B được xác nhận ⇒ `holder=B`, `owner=A`, Transaction chưa COMPLETED → A kiểm tra tiền và nhấn xác nhận ⇒ `owner=B`, COMPLETED.

### E2E-06 – Giao hộ thất bại sau khi C đã lấy

A→C Handover CONFIRMED ⇒ `holder=C` → C không gặp B → C báo giao thất bại → tạo Issue, holder **vẫn C** → tạo Handover mới C→A để trả hoặc tạo lượt giao lại C→B → bên nhận xác nhận mới cập nhật holder.

### E2E-07 – Yêu cầu cạnh tranh

B, D, E lần lượt gửi yêu cầu (thời điểm từ server); A duyệt D → request D ACCEPTED, B/E REJECTED (`MATERIAL_UNAVAILABLE`), đúng **1 Transaction**; thử duyệt B ngay sau đó bị server từ chối.

### E2E-08 – QR thủ công, ảnh offline

Tài liệu không có QR dán: người giao chọn QR Handover hoặc thủ công có lý do → chụp ảnh khi offline → app hiển thị `Chưa gửi` → gửi lại khi có mạng → chỉ sau khi upload ACK và bên nhận xác nhận mới đổi holder.

---

## 15. Giao tiếp giữa các phân hệ và quyền sở hữu code

| Hành động nghiệp vụ | Người sở hữu UI/use case | Đầu vào | Các thay đổi bắt buộc ở server | Ai review hợp đồng |
|---|---|---|---|---|
| Tạo Material & Listing | Trường | Thông tin, ảnh, offer | Material/Listing hợp lệ, QR ID | Khanh (khả dụng) |
| `approveExchangeRequest` **(tên minh họa)** | Khanh | Request ID | Duyệt + từ chối request khác + giữ chỗ + tạo Transaction + event | Trường + Sơn |
| Tạo/chọn DeliveryTask | Đăng | Transaction, điểm hẹn, ứng viên | Chỉ một người giao hộ được duyệt; đúng quyền | Sơn |
| `confirmHandover` **(tên minh họa)** | Đăng | Handover ID | Bằng chứng đủ + receiver đúng → đổi holder + event + Transaction effect | Trường + Sơn |
| Tạo yêu cầu trả | Khanh | Transaction BORROW | Ghi nghĩa vụ trả; không đổi holder trước Handover | Đăng + Sơn |
| `confirmSellerPayment` **(tên minh họa)** | Sơn | Transaction SELL | Lưu xác nhận của A; điều kiện hoàn tất nếu B đã nhận | Trường |
| Hoàn tất tặng/bán/mượn | Sơn (quy tắc) | Event từ P3/P5/P7 | Transaction và owner/availability nhất quán | Trường + Khanh/Đăng theo luồng |
| Báo/đóng Issue | Sơn | Lý do và đối tượng | Lịch sử, hạn chế chuyển trạng thái trái phép | Đăng |

**Không triển khai client gọi `updateTransactionStatus(id, 'COMPLETED')` hoặc `setMaterialHolder(userId)` trực tiếp.** Client chỉ gửi **lệnh nghiệp vụ**, server tự xác định actor từ phiên đăng nhập và kiểm tra trạng thái.

**Mọi thành viên phải có:** UI Android riêng, business logic, repository (Mock trước/Real sau), unit/widget tests, commits và PR. Trường tạo **shared model/interface/fixture store và mock skeleton ban đầu**; ba thành viên bổ sung mock của module mình, không tự đổi ID lõi hoặc định nghĩa model khác tên.

---

## 16. Mẫu định nghĩa một màn hình và một hành động cho các AI coding assistants

Trước khi triển khai màn hình, người phụ trách phải điền đủ:

```text
Màn hình: UI-xx / tên tiếng Việt
Phân hệ phụ trách:
Người dùng hợp lệ:
Trạng thái đầu vào được phép mở:
Dữ liệu hiển thị (nguồn repository nào):
Nút/hành động (theo trạng thái và quyền):
Điều kiện trước khi bấm:
Lệnh nghiệp vụ được gọi:
Kết quả sau server ACK:
Các lỗi: loading / empty / offline / unauthorized / conflict / uploadFailure:
Kiểm thử tối thiểu:
Mã quy tắc: BR-xx, pipeline Px.y:
```

**Ví dụ điều kiện nút “Xác nhận đã nhận”:** chỉ hiển thị/hợp lệ cho `to_user_id` của Handover ở trạng thái chờ, có Evidence server hợp lệ. Nếu lỗi `CONFLICT`, UI tải lại Handover thay vì tự cập nhật trạng thái local thành CONFIRMED.

---

## 17. Mã lỗi nghiệp vụ đề xuất để toàn nhóm nói cùng ngôn ngữ

**Các mã dưới đây là [ĐỀ XUẤT], chưa khóa trong Dart/RPC:**

| Mã lỗi | Khi phát sinh | UI cần làm |
|---|---|---|
| `AUTH_REQUIRED` | Chưa có session | Chuyển đến đăng nhập |
| `FORBIDDEN` | Không phải người có quyền | Báo không có quyền, không hiện dữ liệu nhạy cảm |
| `MATERIAL_UNAVAILABLE` | Material đã có giao dịch, Listing hết khả dụng | Làm mới danh sách, chặn yêu cầu |
| `DUPLICATE_ACTIVE_TRANSACTION` | Thao tác duyệt trùng | Làm mới request/transaction, không tạo bản sao |
| `REQUEST_NOT_PENDING` | Duyệt/hủy request đã xử lý | Làm mới yêu cầu |
| `INVALID_HANDOVER_PARTICIPANT` | Người giao/nhận không khớp | Không cho xác nhận |
| `QR_MISMATCH` | Đọc được mã nhưng không đúng Material/Handover | Dừng đối chiếu, báo sai tài liệu; **không cho fallback thủ công để bỏ qua** **[BR-50]** |
| `EVIDENCE_REQUIRED` | Chưa có ảnh server | Yêu cầu chụp/upload lại |
| `EVIDENCE_UPLOAD_FAILED` | Lỗi upload | Giữ nháp, cho thử lại |
| `RECEIVER_CONFIRMATION_REQUIRED` | Chưa có bên nhận xác nhận | Hiển thị đang chờ |
| `INVALID_TRANSACTION_TRANSITION` | Hành động trái trạng thái | Tải lại Transaction, báo trạng thái hiện tại |
| `PAYMENT_NOT_CONFIRMED` | SELL chưa có A xác nhận tiền | Không hoàn tất chuyển chủ |
| `NETWORK_UNAVAILABLE` | Không có kết nối khi cần server | Giữ nháp an toàn, không giả lập đã hoàn tất |
| `CONFLICT` | Dữ liệu đã đổi ở server | Làm mới và hướng dẫn thực hiện lại |

Các lỗi từ Supabase phải được **mapping có kiểm soát** sang mã lỗi chung; UI không tự suy ra thành công từ HTTP timeout hoặc lỗi upload.

---

## 18. Vấn đề còn mở trước khi khóa state machine và contracts

> **Bắt buộc phân biệt các mục dưới đây với quy tắc đã chốt.** Không để AI tự đặt giá trị enum, giới hạn hoặc cơ chế xác nhận rồi coi như quyết định của nhóm.

| ID | Vấn đề | Phương án mặc định đề xuất | Tác động nếu đổi | Người phối hợp |
|---|---|---|---|---|
| `WF-OPEN-01` | Có tự mở Listing cũ sau trả sách? | **Không**; chủ sách tạo Listing mới (BR-07, OPEN-01) | Material/Listing state, UI-06 | Trường + Khanh |
| `WF-OPEN-02` | Giới hạn số ngày mượn, cách chốt số ngày? | B nhập số ngày, A duyệt/từ chối; giới hạn cần thống nhất (BR-20, OPEN-02) | Request/BorrowingRecord, validation | Khanh |
| `WF-OPEN-03` | Múi giờ/hết hạn trả chi tiết? | Ngày lịch `Asia/Ho_Chi_Minh`, sau hết ngày mới OVERDUE (BR-21, OPEN-07) | Due date và tests | Khanh + Sơn |
| `WF-OPEN-04` | Bằng chứng có cần người **giao** bắt buộc chụp? | Có, người giao chụp/submit; bên nhận confirm (BR-31 một phần ĐỀ XUẤT) | UI-13/UI-14, RLS | Đăng |
| `WF-OPEN-05` | Duyệt ứng viên giao hộ nếu nhiều người cùng bấm? | Duyệt duy nhất một, các ứng viên còn lại bị từ chối (BR-41 ĐỀ XUẤT) | DeliveryApplication schema/RPC | Đăng + Sơn |
| `WF-OPEN-06` | Ai được kết luận tranh chấp kéo dài? | Chỉ theo dõi/escalate, không tự sửa owner/holder; chưa làm Admin UI (BR-47, OPEN-08) | Issue resolution, auth | Sơn + Trường |
| `WF-OPEN-07` | Khu vực nhận sách của người yêu cầu có xuất hiện? | Người dùng tự khai báo khu vực, không tự thu GPS để xếp hạng (OPEN-05) | UI-07/UI-08, privacy | Khanh + Đăng |
| `WF-OPEN-08` | Hủy sau khi duyệt: actor nào có quyền và có cần đối tác đồng ý? | Chỉ cho hủy đơn giản khi chưa có ảnh gửi/bàn giao/tiền; người hủy được xác thực (BR-45, OPEN-04) | Cancel RPC, UI-09 | Sơn + Khanh |
| `WF-OPEN-09` | Sau SELL khi tiền nhận sai/nhầm? | Mở Issue, hoàn tiền ngoài app; không tự hoàn tiền (BR-29, OPEN-08) | Payment, issue | Sơn |
| `WF-OPEN-10` | Cách lưu và cung cấp QR lượt giao (một lần/thời hạn)? | Tạo mã định danh Handover; cơ chế token bảo mật sẽ chốt trong Contracts, không dùng UUID trần làm bảo đảm nhận hàng | QR security, UX | Đăng + Trường |
| `WF-OPEN-11` | Cách chọn điểm trên bản đồ v1.1? | Mô tả điểm hẹn bắt buộc; GPS tùy chọn; mở Maps chỉ đường (BR-42, OPEN-10) | Permission, UI, DB | Đăng |
| `WF-OPEN-12` | Giá trị trạng thái chính thức (Listing/Transaction/DeliveryTask/Handover) | Khóa trong `TRANG_THAI_NGHIEP_VU.md`; chưa cấp quyền mọi UI tự chỉnh status | State machine, database | Sơn + cả nhóm |

---

## 19. Ma trận nghiệm thu theo pipeline

| TC | Pipeline | Thử nghiệm | Kết quả bắt buộc |
|---|---|---|---|
| WF-T01 | P1 | Hai bản sách cùng ISBN | Hai Material ID/QR khác nhau |
| WF-T02 | P2 | Ba request, chọn người gửi thứ hai | Một ACCEPTED, hai REJECTED, server atomic |
| WF-T03 | P2 | Duyệt đồng thời | Một Transaction duy nhất |
| WF-T04 | P3 | Giao trực tiếp thiếu ảnh | Không submit/CONFIRMED |
| WF-T05 | P3 | Người giao tự xác nhận thay B | Bị từ chối phía server |
| WF-T06 | P3 | Không có QR hoặc camera không đọc được QR | Có thể dùng QR lượt giao/thủ công có lý do; vẫn cần ảnh và B xác nhận |
| WF-T21 | P3 | Quét được QR nhưng mã sai | Không thể gửi xác nhận bằng phương án thủ công để vượt qua QR sai; yêu cầu đối chiếu đúng |
| WF-T22 | P1/P2 | Listing còn PUBLISHED nhưng sách RESERVED | Vẫn hiển thị **Đã được đặt**; không được gửi yêu cầu, server từ chối nếu gửi trực tiếp |
| WF-T23 | P1/P2 | Listing ARCHIVED | Không xuất hiện trong khám phá thông thường |
| WF-T07 | P4 | Giao hộ A→C→B | Hai Handover, hai ảnh, holder A→C→B |
| WF-T08 | P4/P9 | C đã lấy nhưng giao thất bại | Holder vẫn C, có Issue |
| WF-T09 | P5 | B nhận sách muộn so với ngày duyệt | `started_at` là thời điểm bàn giao B nhận thành công |
| WF-T10 | P5 | Trả qua D | Hai Handover trả độc lập; T COMPLETED khi A xác nhận |
| WF-T11 | P6 | Tặng miễn phí | B nhận hợp lệ → owner B, không có thanh toán |
| WF-T12 | P7 | B nhận SELL trước khi A xác nhận tiền | Holder B, owner A, Transaction chưa completed |
| WF-T13 | P7 | A xác nhận tiền trước khi giao | Owner vẫn A cho đến lúc B nhận |
| WF-T14 | P7 | Đủ hai điều kiện SELL | Owner B đúng một lần |
| WF-T15 | P8 | Từ chối quyền GPS | Dùng điểm hẹn thủ công, vẫn giao được |
| WF-T16 | P10 | Offline khi upload ảnh | Bản nháp local, không có giao thành công giả |
| WF-T17 | P9 | B không xác nhận sau khi ảnh đã gửi | Handover chờ/Issue, không tự đổi holder |
| WF-T18 | P9 | B xác nhận hai lần | Không nhân đôi chuyển người giữ hoặc event |
| WF-T19 | Security | Tài khoản lạ xem ảnh handover | Private Storage/RLS từ chối |
| WF-T20 | Cross-module | UI của Khanh duyệt, UI Sơn/Trường xem kết quả | Request, Transaction, Material cùng nhất quán |

---

## 20. Hướng dẫn review, commit và quản lý thay đổi

1. Tạo **GitHub Issue** để cả nhóm cùng review tệp này; dẫn liên kết tới `QUY_TAC_NGHIEP_VU.md`.
2. **Trường** kiểm tra P0/P1, Material/Listing và Mock nền; **Khanh** kiểm tra P2/P5; **Đăng** kiểm tra P3/P4/P8/P10; **Sơn** kiểm tra P6/P7/P9 và tác động Transaction.
3. Với mỗi nội dung cần sửa, bình luận kèm mã `Px.y`, `BR-xx` hoặc `WF-OPEN-xx`, tình huống minh họa và đề xuất cụ thể.
4. Chỉ sau khi chốt `WF-OPEN` quan trọng mới viết bảng state machine, signature Dart và migrations SQL, tránh tình trạng sửa bốn module vì một enum.
5. Theo quy trình Git của Nhóm 12, tạo PR **từ `feature/nhom12/...` vào `integration/nhom12-65ktpm`** để review/tích hợp; sau nghiệm thu, PR **từ `integration/nhom12-65ktpm` vào `nhom12-65ktpm`**. Chỉ nhánh nhóm chính thức được dùng để PR nộp vào `main` của kho giảng viên. Tất cả file nhóm nằm trong `nhom12-65ktpm/`. Xem `QUY_TRINH_GIT_NHOM.md`.
6. Khi thay đổi quy trình đã merge, **cập nhật cùng lúc** quy tắc tương ứng, test liên quan và hướng dẫn UI; tăng version, tránh để AI dựa trên bản cũ.

**Commit message đề xuất:** `docs(nhom12-65ktpm): dong bo quy trinh hoat dong voi quy tac v1.2`. Một PR có thể có nhiều commit có ý nghĩa; khi cần giữ lịch sử commit, chọn **Create a merge commit** thay vì Squash.

---

> **KẾT LUẬN:** Tài liệu mô tả các pipeline và điểm phối hợp để phát triển từ Mock sang Supabase. **Không đồng nghĩa Contracts/schema đã khóa**. Mọi điều kiện gắn `[ĐỀ XUẤT]` hoặc `WF-OPEN-xx` phải được nhóm rà soát, không tự biến thành nghiệp vụ bắt buộc khi giao việc cho AI.
