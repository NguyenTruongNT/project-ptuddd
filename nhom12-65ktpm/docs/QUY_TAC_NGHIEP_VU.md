# QUY TẮC NGHIỆP VỤ STUDYSHARE

> **Mã tài liệu:** SS-BR  
> **Phiên bản:** 2.0 – Quy tắc nghiệp vụ hợp nhất và quy ước triển khai MVP  
> **Ngày tổng hợp:** 21/11/2026  
> **Đề tài:** StudyShare – Ứng dụng di động hỗ trợ cho mượn, chuyển nhượng tài liệu học tập và xác thực giao nhận giữa sinh viên  
> **Nhóm:** 12 – 65KTPM, Trường Đại học Thủy lợi  
> **Đầu mối nghiệp vụ và kiến trúc dùng chung:** Nguyễn Văn Trường  
> **Đường dẫn trong repository:** `nhom12-65ktpm/docs/QUY_TAC_NGHIEP_VU.md`

## 0. Đọc trước khi lập trình

**Mục đích:** Tài liệu nghiệp vụ chính thức duy nhất cho cả bốn thành viên: *người dùng làm gì → điều kiện nào được phép → server ghi gì → màn hình thể hiện thế nào → phải kiểm thử ra sao*. Đây không phải báo cáo nghiên cứu quản trị nhân sự và không yêu cầu phát triển hệ thống quản trị quyền riêng tư nhiều cấp trong MVP.

**Cách sử dụng và hiệu lực:** Nội dung dưới đây hợp nhất và cập nhật ngay trong tệp SS-BR hiện hữu, không tạo tài liệu nghiệp vụ tên khác. Tài liệu được biên soạn từ đề cương StudyShare, bản lịch sử `QUY_TAC_NGHIEP_VU.md` v1.2 (SS-BR), `QUY_TRINH_HOAT_DONG.md` (SS-WF), đặc tả của Sơn (SS-SON), quy trình Git và những quyết định nghiệp vụ nhóm trưởng đã xác nhận sau bản v1.2. Những chỗ trước đây còn mở mà cần để lập trình được đã được đưa ra **quy ước triển khai MVP** tại mục 14; đó là lựa chọn biên soạn để nhóm trưởng ban hành, **không phải lời khẳng định cả nhóm đã từng biểu quyết/chốt trước đó**. Quy tắc này là bản do nhóm trưởng chuẩn bị để ban hành; bản trong GitHub chỉ thay đổi sau khi có commit/PR hợp lệ, không mặc định đã được merge.

**Thứ tự ưu tiên sau khi ban hành:** (1) **tệp `QUY_TAC_NGHIEP_VU.md` này** là nguồn quy tắc nghiệp vụ duy nhất; (2) `QUY_TRINH_HOAT_DONG.md` và đặc tả phân hệ bổ sung quy trình chi tiết nếu không mâu thuẫn; (3) đề cương cho mục tiêu, phạm vi, UI và phân công; (4) các bảng trạng thái, schema và API contracts triển khai sau phải tuân thủ quy tắc đã ban hành. **Mọi mô tả trái tài liệu này trong tài liệu cũ cần đồng bộ khi thay đổi code; tuyệt đối không chọn tùy tiện hai quy tắc khác nhau.** Mọi thay đổi nghiệp vụ tiếp theo phải được Trường chấp thuận và được cập nhật vào tệp này trước khi đổi Shared Models/RPC.

**Quy tắc riêng về tác giả:** Tài liệu dùng chung do trưởng nhóm tổng hợp. Việc này **không thay thế** phần UI/domain/repository/test và commit cá nhân của Khanh, Đăng, Sơn.

### 0.1. Phạm vi MVP bắt buộc

- Android, Flutter/Dart, giao diện tiếng Việt, Material 3; Riverpod, go_router; Supabase Auth/PostgreSQL/RLS/private Storage; SQLite/Drift cho bản nháp và ảnh offline. Chỉ Android, không Web.
- Đăng nhập và hồ sơ; bản sách vật lý `Material` + lần đăng `Listing`; ảnh bìa, QR riêng; khám phá/lọc; yêu cầu mượn/tặng/bán và phê duyệt nguyên tử.
- BORROW: giao, theo dõi hạn, trả trực tiếp/qua C; DONATE: chuyển chủ khi B nhận; SELL: thanh toán ngân hàng ngoài ứng dụng, A xác nhận tiền **trước mọi bàn giao SELL**.
- Handover: QR hoặc fallback hợp lệ, ảnh do người giao, người nhận chỉ định xác nhận, server ACK mới chuyển holder; giao hộ do C ứng tuyển/người tạo chọn; lịch sử, tình huống thất bại, Issue tối thiểu; ảnh offline không xác nhận giả.
- Một bản demo trọn vẹn: **A đăng → B yêu cầu → A duyệt → A/C bàn giao có ảnh → B nhận → B trả → A xác nhận → COMPLETED**.

### 0.2. Không làm trong MVP

Không đổi sách lấy sách, chat thời gian thực, theo dõi GPS liên tục, cổng thanh toán/đối soát ngân hàng tự động, ví nội bộ, chuyển tiền/hoàn tiền tự động, nền tảng Web, hệ thống trọng tài có quyền đơn phương xử lý tranh chấp, quy trình BOOT/PRIV nhiều cấp, xuất bằng chứng nhạy cảm nâng cao nếu chưa có đủ phân quyền và kiểm thử. **Không thêm các mục này vào điều kiện nghiệm thu chức năng cốt lõi.**

---

## 1. Vai trò và thuật ngữ

- **A:** chủ sở hữu/người đăng tài liệu ở thời điểm tạo giao dịch, người cho mượn/tặng/bán. Trong giao dịch đã tạo, định danh A được lưu snapshot; chuyển chủ thành công không viết lại A của lịch sử.
- **B:** người yêu cầu mượn/nhận tặng/mua và là người cuối nhận tài liệu trong chiều đi.
- **C:** sinh viên giao hộ được lựa chọn cho **một** `DeliveryTask`; ở chiều trả có thể là C khác với chiều đi. C không phải loại tài khoản cố định.
- **Material:** **một bản vật lý duy nhất**, có `material_id` và QR riêng; hai sách cùng ISBN/tên vẫn có ID khác nhau.
- **Listing:** một lượt đăng của Material, với đúng **một** `offer_type` là `BORROW`, `DONATE` hoặc `SELL`.
- **ExchangeRequest:** đơn yêu cầu một Listing, trước khi A duyệt.
- **Transaction:** giao dịch đã được chấp thuận, có loại, A/B, tình trạng, điều kiện đã snapshot, những chặng giao nhận.
- **BorrowingRecord:** thông tin số ngày mượn, `started_at`, `due_date`, các mốc giao trả và hoàn tất của BORROW.
- **DeliveryTask / DeliveryApplication:** nhiệm vụ giao hộ và ứng tuyển của C; một Task chỉ có tối đa một C được chọn ở một thời điểm.
- **Handover:** một chặng X → Y, gồm đối chiếu QR, ảnh do X cung cấp, **Y tự xác nhận**, server ghi nhận kết quả.
- **Issue:** vụ việc về sai sách, bất đồng, giao thất bại, không hợp tác, v.v.; **Issue không tự thay đổi lịch sử vật lý**.
- **`owner_id`:** người sở hữu trên StudyShare; **`holder_id`:** người giữ được ghi nhận qua **Handover hợp lệ gần nhất**. Holder không phải khẳng định tuyệt đối ai đang cầm ngoài đời nếu có tranh chấp.
- **TransactionEvent:** sự kiện server có actor, thời điểm, nguồn thao tác; thông báo và timeline đọc từ đây.

Một người dùng có thể là A ở giao dịch này, B ở giao dịch khác, C ở giao dịch khác. Quyền kiểm tra **theo quan hệ với giao dịch/chặng**, không chỉ theo loại tài khoản.

## 2. Các bất biến bắt buộc ở server

| Mã | Bất biến phải đúng với mọi UI, Mock và Supabase RPC |
|---|---|
| INV-01 | Một Material có tối đa **một Transaction ACCEPTED đang hoạt động**. Nhiều Request PENDING được phép, chỉ một Request ACCEPTED. |
| INV-02 | Duyệt Request = **một thao tác nguyên tử**: duyệt 1, từ chối PENDING cạnh tranh, khóa Material, tạo Transaction, snapshot thỏa thuận, ghi Event. |
| INV-03 | Không có `setOwner`, `setHolder`, `setStatus('COMPLETED')` tổng quát cho Flutter. Chủ/giữ/trạng thái là hệ quả của lệnh nghiệp vụ qua server. |
| INV-04 | Mỗi Handover có ≥1 ảnh **do người giao chụp/gửi**, đúng mã tài liệu/chặng, người nhận chỉ định tự xác nhận, server ACK; thiếu bất kỳ điều kiện nào không đổi holder. |
| INV-05 | **QR đã đọc nhưng sai** phải chặn chặng đó; không được chuyển sang manual để bỏ qua. QR thiếu/không đọc được mới được fallback có ghi lý do. |
| INV-06 | BORROW không đổi owner; `started_at` chỉ bắt đầu khi B nhận cuối hợp lệ; `COMPLETED` chỉ sau A nhận trả cuối hợp lệ. |
| INV-07 | DONATE đổi owner sang B sau B xác nhận nhận cuối. SELL đổi owner sang B **chỉ** sau A đã xác nhận nhận tiền trước mọi Handover và B xác nhận nhận cuối. |
| INV-08 | C giao thất bại: holder tiếp tục là C nếu chặng C nhận đã hợp lệ; không tự trả về A/B, không tự giải phóng Material. |
| INV-09 | Ảnh chụp/local draft/offline không được coi đã upload/CONFIRMED. Retry không tạo giao dịch, holder update hay event trùng. |
| INV-10 | Không có Issue hoặc admin nào tự giải quyết Transaction, đổi owner/holder, ghi nhận hoàn tiền hay xác nhận vật lý thay người liên quan. |
| INV-11 | Listing cũ `ARCHIVED` sau hoàn tất/hủy; đăng lại tạo Listing mới với cùng Material/QR, không khôi phục Listing cũ. |
| INV-12 | `auth.uid()` và mọi quyền được kiểm tra ở server; ảnh Handover nằm trong private Storage; không chứa `service_role` trong APK/repository. |

---

## 3. Material, Listing, tìm kiếm và yêu cầu

### 3.1. Đăng và quản lý bản sách

1. A đăng nhập, tạo `Material` nếu là bản vật lý mới; cung cấp tên, môn/loại và tình trạng. Khi công bố Listing cần **tối thiểu một ảnh** đã ghi nhận và chọn đúng một hình thức; SELL phải có giá nguyên VND >0. Tên/ISBN có thể trùng bản khác.
2. Server tạo `material_id`/QR định danh riêng; Listing bắt đầu `DRAFT` hoặc `PUBLISHED`. Một Material không có hai Listing hiện hành cạnh tranh.
3. Chỉ owner hiện tại được sửa/ẩn; khi đã có giao dịch đang hoạt động không được đổi hình thức, giá hoặc điều kiện đã snapshot.
4. Listing `PUBLISHED` nhưng Material đã `RESERVED` **vẫn hiển thị với nhãn “Đã được đặt”**; vô hiệu nút gửi yêu cầu và server từ chối tạo yêu cầu mới. `ARCHIVED` bị ẩn khỏi khám phá bình thường.
5. Sau BORROW hoàn tất, owner A vẫn sở hữu Material, holder A, Listing cũ `ARCHIVED`. Muốn tiếp tục cho mượn phải tạo Listing mới; **reuse QR**.
6. Sau DONATE/SELL hoàn tất, owner mới B có quyền tạo Listing mới cho cùng Material; không được sửa Listing lịch sử của A.

**MVP thống nhất:** Thông tin khu vực nhận sách của người yêu cầu không phải trường bắt buộc ở UI gửi Request; ghi điểm hẹn tại lúc chọn bàn giao. Không lấy GPS âm thầm để sắp hàng yêu cầu.

### 3.1.1. Bổ sung Material ngày 2 — Trường duyệt 25/11/2026

- Material chưa đăng tin được lưu với 0–5 ảnh; công bố Listing cần ít nhất 1 ảnh đã được server xác thực và gắn vào Material. JPEG/PNG/WebP, tối đa 5 MiB/ảnh; ảnh đầu là bìa.
- Tên 1–200, môn/loại và tình trạng 1–100 ký tự sau trim; mô tả bản sách tùy chọn tối đa 2.000 ký tự; ISBN tùy chọn, nếu nhập phải đúng ISBN-10/13 và không unique. Không cho ký tự điều khiển trong văn bản.
- Chỉ owner sửa metadata/ảnh khi không có Transaction active, owner đang là holder, không có Listing PUBLISHED hoặc Request PENDING. Ẩn tin và xử lý yêu cầu chờ trước khi sửa.
- Sửa dùng revision để chặn ghi đè đồng thời; retry cùng key/payload trả cùng kết quả. Client confirm trước tạo/sửa, gỡ ảnh và bỏ thay đổi. Local draft không phải ACK server.
- Chủ mới quản lý ảnh theo Material, không phụ thuộc người upload. Ảnh lịch sử còn được snapshot tham chiếu phải được giữ khi gỡ khỏi gallery.

### 3.1.2. Quy tắc Listing

Các mã N3-D01–N3-D08 được giữ để tra cứu các luồng/test cũ. Quy tắc nghiệp vụ nằm tại mục này; luồng UI, RPC và kiểm thử xem [đặc tả triển khai Listing](DAC_TA_TRIEN_KHAI_LISTING.md) và [CONTRACTS §15](CONTRACTS.md#15-listing-ngày-3).

| Mã | Quy tắc |
|---|---|
| N3-D01 | Nháp local có thể chưa hoàn chỉnh. Nháp server cần Material thật và đúng một hình thức. Chỉ DRAFT SELL được để giá null; giá đã nhập phải nguyên VND dương. HIDDEN/PUBLISHED SELL luôn cần giá hợp lệ, kể cả khi thao tác có tên “lưu nháp”. BORROW/DONATE không có giá. |
| N3-D02 | Sửa nội dung tin PUBLISHED phải ẩn trước. Chỉ sửa DRAFT/HIDDEN khi chủ đang giữ sách, không có Transaction active hoặc Request PENDING. |
| N3-D03 | Ẩn tin giữ nguyên yêu cầu PENDING. Người mượn vẫn rút, chủ vẫn từ chối; tin HIDDEN không được nhận/duyệt yêu cầu. Còn PENDING thì chỉ hiện lại nguyên thỏa thuận hoặc xử lý hết yêu cầu trước khi sửa. |
| N3-D04 | Chủ được ẩn/hiện tin có Transaction active để quản lý hiển thị; điều khoản, nghĩa vụ và quyền sở hữu/giữ sách không đổi. Tin hiện lại vẫn RESERVED và không nhận yêu cầu mới. |
| N3-D05 | Mô tả lượt đăng tùy chọn tối đa 2.000 ký tự; khu vực hẹn chung tùy chọn tối đa 200 ký tự. Điểm giao cụ thể/GPS và thông tin ngân hàng không thuộc nội dung Listing công khai. |
| N3-D06 | Nội dung công bố và ảnh được chụp snapshot. Transaction mới giữ thỏa thuận đã được chấp thuận, không đổi theo Material/Listing hiện tại; ảnh lịch sử còn được tham chiếu phải được giữ. |
| N3-D07 | Người đã đăng nhập đọc thông tin an toàn và ảnh của PUBLISHED, kể cả RESERVED. DRAFT/HIDDEN/ARCHIVED không đọc qua Khám phá. URL ảnh đã cấp có thể còn hiệu lực tối đa 5 phút; người tham gia giao dịch đọc lịch sử bằng quyền giao dịch. |
| N3-D08 | Mỗi Material có tối đa một tin DRAFT/PUBLISHED/HIDDEN. Ẩn không giải phóng suất; tiếp tục nháp/tin ẩn trên cùng ID. Không xóa cứng, tự archive hay đổi Material của tin. Tái đăng sau ARCHIVED tạo Listing mới cho cùng Material/QR. |

Quyền gửi yêu cầu theo người xem: chủ tin, người có PENDING tại chính tin đó, hoặc người xem tin RESERVED/Material không khả dụng không được gửi yêu cầu mới. RPC kiểm tra lại quyền và trạng thái tại thời điểm ghi.

### 3.2. Request và phê duyệt

- B không thể gửi Request cho Material của mình, không tạo nhiều Request `PENDING` trùng cùng Listing; Request chỉ được tạo nếu Listing `PUBLISHED` và Material còn khả dụng.
- BORROW: B đề xuất **số ngày nguyên từ 1 đến 30**, A **chấp nhận đúng số đó hoặc từ chối**; không thương lượng/gia hạn trong MVP.
- Mỗi Request ghi `created_at` từ server; danh sách A xem thời điểm gửi, mặc định sắp cũ nhất trước để tiện xem, **không ép FIFO**; A được chọn bất kỳ yêu cầu hợp lệ.
- Khi A duyệt một Request: server nguyên tử đặt Request này `ACCEPTED`, Request PENDING khác `REJECTED/MATERIAL_UNAVAILABLE`, tạo **một** Transaction, giữ chỗ Material, ghi Event. Client không tự optimistic update là ACCEPTED nếu chưa ACK.
- B được rút Request khi vẫn `PENDING` → `CANCELLED`; sau `ACCEPTED`, không được sửa Request ngược về PENDING/CANCELLED, phải áp dụng hủy Transaction theo mục 10.

---

## 4. Handover – quy trình duy nhất dùng lại ở mọi chặng

Các chặng đi, trả, nhận/giao hộ **đều dùng cùng một quy trình**. Bên giao là người đang được server ghi holder; người nhận là tài khoản đích đã được chỉ định.

| Bước | Ai | Điều kiện/đầu ra |
|---|---|---|
| H1 | Server | Tạo Handover có ID ổn định; liên kết Transaction, Material, `from_user_id`, `to_user_id` và chặng liên quan. Không tạo hai Handover đang hoạt động cho cùng chặng. |
| H2 | Người giao | Quét QR Material, đối chiếu hợp lệ; nếu QR thiếu/không đọc được, dùng QR Handover hoặc manual có lý do ghi vào server. QR **đọc được mà sai** → `QR_MISMATCH`, chặn. |
| H3 | Người giao | Chụp và tải lên ít nhất 1 ảnh bằng camera; Evidence được ghi vào private Storage và server xác thực đúng Handover. |
| H4 | Server | Chỉ sau H2 hợp lệ và Evidence đã upload/ghi nhận đủ mới chuyển Handover sang `AWAITING_RECEIVER_CONFIRMATION`. |
| H5 | Người nhận chỉ định | Kiểm tra tài liệu, ảnh, người giao, rồi **Xác nhận đã nhận** hoặc **Từ chối/Báo vấn đề** với lý do. |
| H6a | Server | Khi nhận hợp lệ, nguyên tử Handover → `CONFIRMED`, holder = receiver, ghi Event, cập nhật trạng thái Transaction/DeliveryTask có liên quan. |
| H6b | Server | Khi người nhận từ chối trước nhận: `DISPUTED`, tạo Issue, **không** đổi holder/owner. Ảnh bổ sung của người từ chối là tùy chọn. |

**Quy ước triển khai để không phải hỏi tiếp:** Handover `DISPUTED` được giữ nguyên làm lịch sử; sau khi Issue có phương án giải quyết hợp lệ, nếu cần bàn giao lại thì **tạo Handover ID mới**, không sửa lượt bị từ chối thành CONFIRMED. Các nút Retry mạng phải dùng chính action ID để chống ghi trùng; retry sự kiện nghiệp vụ đã hoàn tất trả về trạng thái server hiện tại.

**QR:** QR Material xác thực `material_id` bằng token không dễ đoán, không dùng ISBN thay ID. QR của chặng gắn với `handover_id` và server kiểm tra quan hệ, trạng thái, actor; **QR/UUID một mình không phải bằng chứng người đã nhận**. Token và phiên bản được phát hành/kiểm tra ở server; TTL chi tiết có thể cấu hình và không làm thay đổi quy tắc ảnh + người nhận + ACK. Màn hình có nhãn rõ: `Chưa gửi`, `Chờ người nhận`, `Đã xác nhận`, `Bị từ chối`.

**Offline:** Chỉ lưu file trong vùng riêng tư của app, metadata nháp và action ID; không lưu quyền truy cập ảnh trong public directory, không tự tạo Handover server khi offline. Upload/retry trong lúc app chạy; xóa file nháp chỉ sau ACK thích hợp. Không hứa dịch vụ đồng bộ nền liên tục.

---

## 5. BORROW – mượn, hạn trả, hoàn trả

### 5.1. Chiều giao tài liệu

1. A duyệt Request BORROW 1–30 ngày; Transaction chờ giao; owner và holder ban đầu vẫn là A.
2. Chọn **trực tiếp A→B** hoặc **giao hộ A→C→B**; mỗi chặng có Handover riêng theo mục 4.
3. Chỉ khi B xác nhận nhận cuối thành công và server ACK: `holder=B`, Transaction vào giai đoạn `BORROWING`, lưu `started_at` server. Mượn **không bắt đầu** khi A mới duyệt hoặc C mới lấy sách.
4. `due_date` là **ngày Việt Nam** tại lúc B nhận hợp lệ cộng số ngày mượn đã được chấp thuận. Ví dụ nhận ngày 21/11/2026, mượn 7 ngày → hạn cuối 28/11/2026 (hết ngày theo `Asia/Ho_Chi_Minh`); `OVERDUE` bắt đầu 29/11/2026, không thay Transaction.status.

### 5.2. Chiều trả tài liệu

1. B tạo yêu cầu trả; ý định trả chỉ tạo lịch sử, **không** đổi holder, không tự hoàn tất, không tự dừng tính trễ.
2. B trả **trực tiếp B→A** hoặc mở **DeliveryTask trả B→C→A**. Người tạo Task chiều trả là B (người đang gửi sách); A được thông báo nhưng **không cần phê duyệt trước C**.
3. Nếu B→A thành công trước/cuối hạn, ghi mốc trả thực tế. Nếu B→C hợp lệ vào hoặc trước due_date, ghi mốc **B đã bàn giao cho người giao hộ được chọn** để không tiếp tục cộng trễ mượn gốc do A chậm/không nhận từ C; giữ nguyên due_date và bằng chứng.
4. Transaction **chỉ `COMPLETED`** khi A cuối cùng xác nhận Handover nhận lại; cập nhật holder=A, owner=A, Listing cũ ARCHIVED, không công khai lại.
5. Nếu A im lặng hoặc từ chối hợp tác, B ghi nhận ý định, lần liên hệ và mở Issue; **không tự xác nhận trả, không đóng băng due_date, không tự chuyển holder**. Lỗi và trách nhiệm chậm trả sẽ được giải quyết riêng, không tự phạt B nếu không đủ căn cứ.

### 5.3. Courier trả thất bại, 3 ngày tái bàn giao

- Khi B→C đã CONFIRMED nhưng C không giao A được, C phải trả **C→B** bằng Handover mới, ảnh người giao C và B xác nhận. Chỉ khi đó holder mới trở về B.
- B có **3 ngày lịch Việt Nam** từ ngày server xác nhận C→B để thực hiện lượt **tái bàn giao đầu tiên hợp lệ** đến A hoặc C mới được chọn; hạn cuối là cuối ngày `ngày_nhận_lại + 3`. Đây là **hạn tái bàn giao**, không viết đè `due_date` mượn gốc hoặc mốc trả ban đầu B→C.
- Quá hạn tái bàn giao hiển thị riêng `REHANDOVER_OVERDUE`, không tự tính lại trễ mượn gốc hay hoàn tất giao dịch.

---

## 6. DONATE – tặng miễn phí

1. A đăng Listing DONATE, B gửi Request, A duyệt nguyên tử.
2. Giao trực tiếp A→B hoặc A→C→B; mọi chặng ảnh + xác nhận receiver.
3. Khi **B xác nhận nhận cuối** và server ACK: `holder=B`, `owner=B`, Transaction `COMPLETED`, Listing A `ARCHIVED`, Event chỉ ghi một lần.
4. Không có thanh toán, không có bước trả. B có thể đăng Listing mới cho Material mình đã nhận; không tái sử dụng Listing cũ của A.
5. Nếu B từ chối trước nhận hoặc báo Issue sau nhận: áp dụng mục 9; không tự chuyển chủ nếu từ chối, không tự đảo ngược chủ khi đã nhận hợp lệ.

## 7. SELL – chuyển nhượng có tiền ngoài ứng dụng

**Thứ tự bắt buộc (đã được nhóm trưởng chốt sau SS-BR v1.2):**

`B gửi Request → A duyệt → B thấy QR/thông tin chuyển khoản → B chuyển tiền ngoài app → A tự kiểm tra và bấm Đã nhận tiền → mới cho Handover đầu tiên của SELL → B xác nhận nhận cuối → chuyển chủ và COMPLETED`.

- Mã QR **ngân hàng** khác QR Material và QR Handover; chỉ hiển thị **sau A duyệt**, dùng thông tin A khai báo, số tiền snapshot, mã tham chiếu; không lưu mật khẩu/OTP, không tự kiểm tra giao dịch thật.
- `buyer_reported_at`/nút “Tôi đã chuyển khoản” **chỉ là thông báo**, không đủ để giao sách; chỉ `seller_confirmed_at` do A xác nhận sau kiểm tra ngoài app mới mở khóa tạo/gửi **bất kỳ Handover SELL**.
- Có thể thỏa thuận điểm hẹn, tạo DeliveryTask và chọn C trước khi A xác nhận tiền, nhưng **không cho Handover A→C/A→B hoặc các chặng tiếp theo được thực thi trước khi A xác nhận tiền**.
- Sau A xác nhận tiền nhưng chưa có B nhận cuối: `owner=A`, `holder` vẫn là người nhận hợp lệ gần nhất, Transaction chưa hoàn tất. Khi B nhận cuối hợp lệ: server **nguyên tử** owner=B, holder=B, Transaction COMPLETED, Listing cũ ARCHIVED.
- **Không có happy path “giao sách SELL trước tiền”.** Nếu việc đó xảy ra ngoài hệ thống hoặc do dữ liệu cũ: ghi Issue để đối soát, **không cho tự hợp thức hóa bằng cách đổi trạng thái**.
- C giao SELL thất bại, sách trả lại A hợp lệ: A có thể **đề nghị tiếp tục** (hẹn giao mới/đổi C) hoặc **đề nghị hủy và hoàn tiền**. Việc hủy cần B đồng ý, A hoàn tiền **ngoài ứng dụng**, B xác nhận thực nhận tiền hoàn, sách đã ở A, không có Issue/ nghĩa vụ mở; không hủy/hoàn tiền một phía.

---

## 8. DeliveryTask – giao hộ, ứng tuyển và thất bại

1. Người đang giữ và cần gửi tài liệu tạo Task: chiều đi A→B do A; chiều trả B→A do B. Nhập **mô tả điểm lấy/điểm giao bắt buộc**; tọa độ GPS tùy chọn khi người dùng cho phép. Không tracking C liên tục.
2. C đăng nhập, tự ứng tuyển Task. C phải khác người gửi và người nhận cuối **của Task**.
3. Người tạo Task xem danh sách ứng viên và **chọn thủ công đúng một C**. Server nguyên tử ghi ứng viên C `ACCEPTED`, các đơn PENDING khác `REJECTED`, Task `ASSIGNED`; không tự chọn theo rating.
4. Chặng H1 người gửi→C: **người gửi** chụp/upload ảnh, C xác nhận; Handover CONFIRMED mới `holder=C` và Task `PICKED_UP`.
5. Chặng H2 C→người nhận cuối: **C** chụp/upload ảnh, người nhận cuối xác nhận; thành công mới Task `COMPLETED` và đổi holder.
6. **Quy ước MVP để tránh kẹt Task:** Trước khi H1 CONFIRMED, ứng viên PENDING có thể tự rút; C đã được chọn có thể xin rút phân công trước nhận, Task cũ được hủy có audit/lý do và người tạo lập Task mới để tuyển C khác. **Sau khi C đã nhận sách**, không có nút hủy nhanh: dùng quy trình giao thất bại và bàn giao trả.
7. Nếu C đã nhận sách nhưng không giao được: ghi `FAILED` với lý do, mở Issue khi cần, `holder` **vẫn C**. C phải giao trả về **người đã trực tiếp giao sách cho C** bằng Handover mới, không phải luôn luôn A: chiều đi là **C→A**, chiều trả là **C→B**.
8. Task `FAILED` giữ trạng thái lịch sử; khi sách đã hoàn trả hợp lệ, ghi `return_handover_id`/event `COURIER_RETURN_CONFIRMED`, **không tự sửa Task FAILED thành COMPLETED**. Chuyến mới (nếu tiếp tục) tạo Task mới, không tái sử dụng ảnh/chặng cũ.
9. A và B được đánh giá C **1–5 sao, mỗi người tối đa một lần mỗi Task**, tùy chọn sau khi Task kết thúc và Issue liên quan đã được giải quyết. Hiển thị trung bình + số lượt, chưa có thì ghi “Chưa có đánh giá”. Không trừ sao tự động vì sự cố. Rating là chức năng phụ, không chặn demo bàn giao.

---

## 9. Từ chối, khiếu nại và Issue

### 9.1. Từ chối **trước khi nhận hợp lệ**

- Người nhận đúng chặng từ chối vì sai tài liệu/không đúng tình trạng/chưa nhận: phải ghi **lý do**, ảnh bổ sung có thể kèm. Server Handover → `DISPUTED`, Issue mở, **không đổi holder/owner**, không được coi Handover hoàn tất.
- QR sai đã đọc được **chặn từ đầu**, không cho manual override hoặc xác nhận nhận. Khi các bên thống nhất phương án xử lý Issue, nếu cần thực hiện lại thì tạo Handover mới.

### 9.2. Khiếu nại **sau khi đã nhận hợp lệ**

- B có thể báo vấn đề sau khi nhận; Issue **không đảo ngược** Handover, `holder`, `owner`, payment hay `COMPLETED`.
- Khiếu nại về tình trạng tại lúc nhận B phải được **mở trong 7 ngày lịch Việt Nam** kể từ ngày server xác nhận B nhận cuối. Ví dụ B nhận 24/11 → nhận phản ánh đến hết **01/12**.
- Đối với BORROW, vấn đề mới phát sinh được báo **trong suốt giao dịch còn hoạt động**. Sau BORROW `COMPLETED`, có thể mở Issue về chặng trả trong **7 ngày lịch Việt Nam** từ ngày A xác nhận trả cuối; đồng thời vẫn giữ cửa sổ khiếu nại 7 ngày của B từ lúc nhận ban đầu nếu chưa hết.
- Issue mở đúng hạn **không tự hết hiệu lực** sau mốc 7 ngày; ngày cuối chỉ là hạn **khởi tạo** theo loại khiếu nại. Với DONATE/SELL đã hoàn tất, không tự trả hàng/hoàn tiền/hủy giao dịch chỉ vì Issue sau nhận.
- Mở Issue không tự dừng hoặc kéo dài hạn trả BORROW. Cần giữ lịch sử mốc trả để phân biệt quá hạn và lỗi do người nhận không hợp tác.

### 9.3. Quyền giải quyết và trạng thái

- Issue có trạng thái **`OPEN`, `RESOLVED`** cho MVP; có thể lưu loại, đối tượng, reporter, nội dung, diễn biến, giải pháp đề xuất và xác nhận các bên liên quan. `NEEDS_RESOLUTION` là **nhãn UI suy ra từ Issue đang OPEN**, không phải `Transaction.status` độc lập.
- Chỉ **các bên trực tiếp bị ảnh hưởng** đồng thuận xác nhận phương án xử lý mới chuyển Issue `RESOLVED`; moderator/APP_ADMIN (nếu có) chỉ hỗ trợ, không đơn phương xác nhận đã giao, đổi chủ, chuyển tiền hay đóng Issue.
- Nếu A nhiều lần cản trở nhận trả, B có thể yêu cầu hỗ trợ/hòa giải; không có quyền hỗ trợ tự thay đổi holder, owner, payment hoặc trạng thái hoàn tất. Nếu các bên không thống nhất, hồ sơ tiếp tục OPEN; không tự đóng sau một timeout.
- Các hành động nghiệp vụ xung đột với Issue OPEN phải bị chặn; các thao tác thực hiện nghĩa vụ trả/khôi phục an toàn cần được phép theo phương án các bên đồng thuận, không khóa toàn bộ giao dịch một cách mù quáng.

---

## 10. Hủy Request, Transaction và khắc phục SELL

- **Request trước duyệt:** B được tự rút nếu còn `PENDING`; `CANCELLED` ghi timestamp server. A có thể `REJECTED` Request đang PENDING.
- **Transaction đã được duyệt:** một bên A hoặc B đề nghị hủy, có lý do; **bên còn lại phải đồng ý**. Không cho hủy nhanh một phía.
- Server chỉ được chuyển `CANCELLED` khi bảo đảm **không còn sách đang cần giao/hoàn trả, không còn tiền phải đối soát/hoàn trả, không có Issue OPEN**. Nếu đã phát sinh Handover hoặc thanh toán, hoàn thành các bước vật lý/tiền hợp lệ trước, không xóa lịch sử cũ.
- Khi hủy hợp lệ: cập nhật Transaction `CANCELLED`, giải phóng khóa Material khi an toàn, **Listing cũ ARCHIVED** (không tự đăng lại), ghi Event, tất cả nguyên tử. Không thay holder/owner tùy ý.
- SELL tiền đã xác nhận nhưng giao không hoàn tất: hướng **tiếp tục** hoặc **đề nghị hủy/hoàn tiền** cần A/B đồng thuận; hoàn tiền ngoài app; B độc lập xác nhận nhận đủ tiền hoàn, sách do A giữ hợp lệ; chỉ khi hết nghĩa vụ và Issue thì mới được hủy.

---

## 11. Trạng thái canonical và quy tắc chuyển

**Các enum dưới đây là quy ước triển khai MVP trong tệp SS-BR này, dùng làm chuẩn cho Shared Models, Mock và SQL sau khi nhóm trưởng ban hành tệp này.** Không dùng status cho một ý nghĩa khác giữa các phân hệ.

| Đối tượng | Trạng thái lưu trữ chuẩn | Ghi chú |
|---|---|---|
| `Listing.status` | `DRAFT`, `PUBLISHED`, `HIDDEN`, `ARCHIVED` | `RESERVED` không phải Listing.status. |
| `ExchangeRequest.status` | `PENDING`, `ACCEPTED`, `REJECTED`, `CANCELLED` | `CANCELLED` chỉ áp dụng trước duyệt. |
| `Transaction.status` – BORROW | `AWAITING_HANDOVER`, `HANDOVER_IN_PROGRESS`, `BORROWING`, `RETURN_PENDING`, `RETURN_IN_PROGRESS`, `COMPLETED`, `CANCELLED` | `OVERDUE`, `NEEDS_RESOLUTION` là nhãn dẫn xuất. |
| `Transaction.status` – DONATE | `AWAITING_HANDOVER`, `HANDOVER_IN_PROGRESS`, `COMPLETED`, `CANCELLED` | Điều kiện tiền không áp dụng. |
| `Transaction.status` – SELL | `AWAITING_PAYMENT`, `AWAITING_HANDOVER`, `HANDOVER_IN_PROGRESS`, `COMPLETED`, `CANCELLED` | `AWAITING_PAYMENT` cho đến khi A xác nhận tiền; không có Handover trước đó. |
| `Handover.status` | `PENDING`, `AWAITING_RECEIVER_CONFIRMATION`, `CONFIRMED`, `DISPUTED` | `DISPUTED` giữ nguyên, retry bằng Handover mới sau phương án xử lý. |
| `DeliveryTask.status` | `OPEN`, `ASSIGNED`, `PICKED_UP`, `DELIVERY_PENDING_CONFIRMATION`, `COMPLETED`, `FAILED`, `CANCELLED` | FAILED vẫn FAILED sau sự kiện trả hợp lệ; không giả hoàn tất task. |
| `DeliveryApplication.status` | `PENDING`, `ACCEPTED`, `REJECTED`, `WITHDRAWN` | Chỉ một ACCEPTED mỗi Task. |
| `Issue.status` | `OPEN`, `RESOLVED` | Không tự `CLOSED` nếu chưa có quy trình mới. |
| `Material availability` | **Dẫn xuất** từ Listing, Transaction và holder | UI không set `AVAILABLE`, `RESERVED`, `ON_LOAN` tùy ý. |

### 11.1. Ma trận transition (lệnh nghiệp vụ, không phải set status)

| Từ → đến | Lệnh hoặc sự kiện | Rào chắn và tác động chính |
|---|---|---|
| Listing `DRAFT → PUBLISHED` | Owner `publishListing` | Ảnh, tên, môn/loại, tình trạng và hình thức hợp lệ; SELL giá >0. |
| Listing `PUBLISHED ↔ HIDDEN` | Owner ẩn/hiện | Không phá thỏa thuận giao dịch đã duyệt. |
| Listing hiện hành `→ ARCHIVED` | Hoàn tất/hủy Transaction | Giữ lịch sử, không công khai lại. |
| Request `PENDING → ACCEPTED` | A duyệt | Một RPC nguyên tử, các request cạnh tranh REJECTED, tạo T. |
| Request `PENDING → REJECTED/CANCELLED` | A từ chối/B rút | Đúng actor; không tạo T. |
| BORROW `AWAITING_HANDOVER → HANDOVER_IN_PROGRESS` | Tạo Handover chiều đi | Đúng holder, đúng transaction; không tự BORROWING. |
| BORROW `HANDOVER_IN_PROGRESS → BORROWING` | B xác nhận nhận cuối | Bắt đầu kỳ mượn/tính due_date. |
| BORROW `BORROWING → RETURN_PENDING` | B yêu cầu trả | Chỉ ghi ý định, không đổi holder. |
| BORROW `RETURN_PENDING → RETURN_IN_PROGRESS` | Chặng trả đầu tiên | Không hoàn tất khi mới B→C. |
| BORROW `RETURN_IN_PROGRESS → COMPLETED` | A xác nhận nhận cuối | Holder=A, owner=A, archive Listing. |
| SELL `AWAITING_PAYMENT → AWAITING_HANDOVER` | A xác nhận đã nhận tiền | A là người bán, server ghi nhận một lần. |
| DONATE/SELL `AWAITING_HANDOVER → HANDOVER_IN_PROGRESS` | Chặng đầu giao tài liệu | SELL đã phải có seller_confirmed_at. |
| DONATE/SELL `HANDOVER_IN_PROGRESS → COMPLETED` | B nhận cuối | DONATE: owner=B; SELL: kiểm tra tiền có từ trước; archive Listing. |
| Handover `PENDING → AWAITING_RECEIVER_CONFIRMATION` | Người giao upload ≥1 ảnh + đối chiếu đúng | Ảnh đã server ACK; QR mismatch chặn. |
| Handover `AWAITING_RECEIVER_CONFIRMATION → CONFIRMED` | Người nhận xác nhận | Holder=receiver nguyên tử, event một lần. |
| Handover `AWAITING_RECEIVER_CONFIRMATION → DISPUTED` | Người nhận từ chối | Lý do + Issue, không holder change. |
| DeliveryTask `OPEN → ASSIGNED → PICKED_UP` | Người tạo chọn C; H1 xác nhận | One courier; holder=C sau H1. |
| DeliveryTask `PICKED_UP → DELIVERY_PENDING_CONFIRMATION → COMPLETED` | C gửi ảnh; receiver xác nhận | Holder cuối được cập nhật sau ACK. |
| DeliveryTask sau C đã lấy `→ FAILED` | Báo giao thất bại | Giữ holder=C, Issue hoặc lý do, cần Handover trả riêng. |
| Transaction active `→ CANCELLED` | Đề nghị + đồng ý hủy | Không còn nghĩa vụ sách/tiền/Issue; archive Listing nguyên tử. |
| Issue `OPEN → RESOLVED` | Các bên bị ảnh hưởng xác nhận phương án | Không cho moderator/admin tự xác nhận thay. |

**Chú ý chuỗi dài:** Sau khi C giao không thành, lượt Handover trả về người giao trước là một **Handover phục hồi** thuộc cùng Transaction, không bị ép phải hợp thức hóa bằng một transition BORROWING giả. Sơn tính trạng thái tổng từ các Event/Handover; Đăng không tự set Transaction.status.

---

## 12. Dữ liệu tối thiểu, server contracts và lỗi

### 12.1. Các thực thể cần dùng chung

| Thực thể | Trường logic tối thiểu để thiết kế database / model |
|---|---|
| `Profile` | `user_id`, `display_name`, thông tin chia sẻ có quyền, `created_at`. |
| `Material` | `id`, `owner_id`, `holder_id`, `qr_token` (không public token nhạy cảm), `title`, `subject`, `condition`, `isbn?`, ảnh bìa, `created_at`. |
| `Listing` | `id`, `material_id`, `offer_type`, `status`, `asking_price_vnd?`, `published_at`, snapshot các thuộc tính công bố. |
| `ExchangeRequest` | `id`, `listing_id`, `requester_id`, `requested_borrow_days?`, `status`, `created_at`, `decided_at`, `reject_reason?`. |
| `Transaction` | `id`, `listing_id`, `request_id`, `type`, `owner_at_acceptance`, `receiver_id`, `status`, `agreed_borrow_days?`, `agreed_price_vnd?`, timestamps. |
| `BorrowingRecord` | `transaction_id`, `started_at`, `due_date`, `return_to_courier_at?`, `final_return_confirmed_at?`, `re_handover_due_date?`. |
| `DeliveryTask` | `id`, `transaction_id`, `sender_id`, `final_receiver_id`, `assigned_courier_id?`, `status`, pickup/dropoff description, optional coords, recovery handover. |
| `DeliveryApplication` | `id`, `task_id`, `applicant_id`, `status`, `created_at`. |
| `Handover` | `id`, `transaction_id`, `delivery_task_id?`, `from_user_id`, `to_user_id`, `status`, `verification_method`, fallback reason, server timestamps. |
| `HandoverEvidence` | `id`, `handover_id`, uploader, private storage path, server time, sensitivity metadata. |
| `PaymentConfirmation` | `transaction_id`, price snapshot, seller, buyer_reported_at?, seller_confirmed_at?, refund_proposed_at?, buyer_refund_confirmed_at?`. |
| `Issue` | `id`, `transaction_id`, `handover_id?`, reporter, reason/type, status, opened_at, resolved_at?, resolution/consents. |
| `TransactionEvent` | `id`, `transaction_id`, actor, event type, server timestamp, `source_action_id` idempotency key, safe details. |
| `CourierRating` | task ID, rater ID, stars 1–5, timestamp; UNIQUE(task_id,rater_id). |

`Material.holder_id` và Transaction không được tạo bản sao mutable riêng ở mỗi module. **Schema, SQL tên cột và chữ ký Dart cụ thể do Trường khóa ở tài liệu kỹ thuật kế tiếp**, nhưng ý nghĩa và điều kiện nghiệp vụ trong tài liệu này là chuẩn.

### 12.2. Lệnh use case cần có trong Repository Interfaces

`createMaterial`, `publishListing`, `hideListing`, `getDiscoverListings`, `createExchangeRequest`, `cancelPendingRequest`, `approveExchangeRequest`, `rejectExchangeRequest`, `requestBorrowReturn`, `createDeliveryTask`, `applyForDelivery`, `selectCourier`, `withdrawCourierBeforePickup`, `createHandover`, `submitHandoverEvidence`, `confirmHandover`, `refuseHandover`, `confirmSellerPayment`, `reportIssue`, `proposeIssueResolution`, `confirmIssueResolution`, `proposeTransactionCancellation`, `acceptTransactionCancellation`, `getTransactionTimeline`.

Đây là **tên hành động logic**, không buộc mỗi hành động thành một RPC độc lập. Module gọi repository; SQL/RPC quyết định hành động hợp lệ và tác động nguyên tử. Mọi action thay đổi trạng thái có idempotency key khi cần; client không gửi `actor_id` có giá trị quyền thay cho session.

### 12.3. Mã lỗi chung tối thiểu

`AUTH_REQUIRED`, `FORBIDDEN`, `INVALID_INPUT`, `MATERIAL_UNAVAILABLE`, `DUPLICATE_REQUEST`, `DUPLICATE_ACTIVE_TRANSACTION`, `REQUEST_NOT_PENDING`, `INVALID_TRANSACTION_TRANSITION`, `INVALID_HANDOVER_PARTICIPANT`, `QR_MISMATCH`, `EVIDENCE_REQUIRED`, `EVIDENCE_UPLOAD_FAILED`, `RECEIVER_CONFIRMATION_REQUIRED`, `PAYMENT_NOT_CONFIRMED`, `ISSUE_BLOCKING_ACTION`, `CANCELLATION_OBLIGATION_PENDING`, `NETWORK_UNAVAILABLE`, `CONFLICT`.

UI phải hiển thị lỗi thân thiện, không hiển thị `service_role`, storage path riêng tư hay stack trace. Timeout không được coi là thành công; tải lại server snapshot, retry cùng action key.

---

## 13. Bảo mật, chứng cứ và tính riêng tư – phạm vi MVP

1. `Supabase Auth` xác định `auth.uid()`. RLS kiểm tra người sở hữu, người yêu cầu, người giao/nhận đúng chặng và phạm vi sự kiện. Người ngoài không đọc được Transaction hoặc ảnh handover.
2. Ảnh Handover, Issue ở **private Storage**. Không đưa ảnh cá nhân, token đăng nhập, CCCD, thông tin ngân hàng thật vào Mock công khai hoặc GitHub. Signed URLs có TTL ngắn, kiểm tra quyền ở server trước khi cấp.
3. Người liên quan có thể xem ảnh mức 2 đúng chặng và Issue thuộc phạm vi quyền; C **không** tự được xem toàn bộ ảnh giao dịch khác chặng. Bằng chứng mức 3 cần chấp thuận riêng của người cung cấp có quyền chia sẻ; không tự mở chỉ vì `APP_ADMIN` hay `SUPPORT_MODERATOR`.
4. Các quyết định đã chốt về chia sẻ mức 3 (chấp thuận từng ảnh/người nhận, tối đa 24 giờ và URL tối đa 5 phút), xuất bản tổng hợp Handover (metadata server; ảnh mức 2 chỉ khi có chấp thuận, mỗi quyền xuất tạo một bản; tệp lưu tạm 24 giờ, URL tải tối đa 60 giây) là **quy tắc bảo vệ nếu nhóm triển khai chức năng nâng cao**, **không bắt buộc phải xây UI xuất ảnh/PRIV/BOOT trong bản demo MVP**. Không đưa ảnh mức 3 vào export mức 2; không coi cache/URL đã cấp được thu hồi tức thì.
5. Tên trong bản tổng hợp sau này: tên hiển thị tại thời điểm server xác nhận Handover + vai trò + mã StudyShare thích hợp, không mặc định email/điện thoại/địa chỉ/MSSV/CCCD/GPS chi tiết; các ngoại lệ che thông tin giữ lịch sử gốc có phân quyền, bản xuất thay thế có mã mới.
6. Người thứ ba có thể gửi phản ánh riêng tư qua kênh có kiểm soát mà không tự được xem Transaction/Issue/ảnh. **Quy trình xét duyệt PRIV và bổ nhiệm quản trị gốc phức tạp không thuộc các màn hình bắt buộc MVP**. Không tự xây quyền `APP_ADMIN` xem chứng cứ hoặc giải quyết Issue thay người dùng.
7. D3 bằng chứng bổ sung Issue: quyết định đã chốt là giữ 90 ngày **sau RESOLVED**, trừ khi có nghĩa vụ/tranh chấp đang tồn tại cần xem xét; **không áp dụng 90 ngày** cho D1 lịch sử giao dịch, D2 ảnh Handover gốc, D4 audit – thời hạn của chúng chưa khóa. MVP không tự xóa chứng cứ nguồn theo một job chung thiếu phân loại.

---

## 14. Các quy ước triển khai để chốt khỏi hỏi vòng lại

**Các lựa chọn sau là quy ước thiết kế MVP được tổng hợp để nhóm trưởng ban hành khi đưa bản này lên GitHub.** Chúng là *quy ước thiết kế được chuẩn hóa trong tài liệu này*, không được ghi ngược là “đã chốt từ v1.2”. Thành viên không tự thay chúng khi code.

| Mã | Quy ước MVP dùng để triển khai ngay | Lý do |
|---|---|---|
| MVP-D01 | `NEEDS_RESOLUTION` là **nhãn dẫn xuất từ Issue OPEN**, không phải trạng thái Transaction. | Không có hai nguồn sự thật. |
| MVP-D02 | Handover `DISPUTED` giữ làm lịch sử; sau giải quyết muốn giao lại tạo Handover mới. | Không viết lại bằng chứng bất đồng. |
| MVP-D03 | DeliveryTask `FAILED` vẫn FAILED; Handover phục hồi gắn riêng và ghi Event. | Phân biệt chuyến thất bại và việc vật lý đã được trả lại. |
| MVP-D04 | C rút trước khi nhận: đơn PENDING → WITHDRAWN; đã ASSIGNED mà chưa pickup thì hủy Task có lý do, tạo Task mới nếu còn nhu cầu. | Không có Task treo/không giả hoàn thành. |
| MVP-D05 | Nút “Báo vấn đề” khi chờ receiver luôn khả dụng cho người có quyền; không bắt buộc phải đợi N giờ. | Không có timeout tự xác nhận. |
| MVP-D06 | Listing bắt buộc tên, môn/loại, tình trạng, ≥1 ảnh, một hình thức; SELL giá VND>0. B được rút Request PENDING. | Validation cụ thể cho UI/DB. |
| MVP-D07 | Điểm hẹn có mô tả bắt buộc; GPS optional; mở bản đồ ngoài app, không tracking. | Giảm phạm vi, đủ chứng minh tính năng thiết bị. |
| MVP-D08 | QR material có token khó đoán; QR Handover là mã tham chiếu gắn Handover do server kiểm tra, **không là yếu tố xác nhận đủ một mình**. | Giảm rủi ro QR bị sao chép và tránh lệ thuộc QR làm bằng chứng duy nhất. |
| MVP-D09 | Mọi state-changing action dùng idempotency key, timestamp server, quyền server và event nhất quán; Mock phải mô phỏng lỗi. | Tránh double-approval, double-holder-update. |

**Không tự quyết định bằng code:** quyền xóa chứng cứ đang có tranh chấp, đóng Issue đơn phương, chính sách BOOT/PRIV khi thiếu người phê duyệt độc lập, thanh toán hoặc hoàn tiền tự động, theo dõi vị trí liên tục. Chuyển các mục này sang backlog/hướng phát triển và hỏi trưởng nhóm **chỉ nếu** tính năng thực sự được đưa vào phạm vi triển khai.

---

## 15. Phân công theo chức năng, đầu ra kiểm chứng

| Thành viên | Phân hệ bắt buộc | Màn hình và đầu ra | Dependency cần tuân theo |
|---|---|---|---|
| **Nguyễn Văn Trường** – nhóm trưởng | Auth, Profile, Material, Listing, ảnh bìa, QR Material, Shared Foundation | UI-01/02/05/06/18; Shared Models, enums, repository interfaces, fixture IDs cố định, Mock skeleton, tích hợp/CI | Không tự hoàn tất giao dịch bằng sửa Material. Khóa contracts theo tài liệu này. |
| **Vũ Tuấn Khanh** | Discovery, Request, duyệt, BORROW, hạn trả | UI-03/04/07/08/15; validate Request, approve atomic, ngày hạn, yêu cầu trả, tests duyệt trùng | Không tự xác nhận Handover, không tự set COMPLETED. |
| **Vũ Hải Đăng** | DeliveryTask, C ứng tuyển, QR/Handover, camera, offline evidence, GPS/điểm hẹn | UI-10/11/12/13/14; ảnh người giao, receiver confirmation, courier fail/return, tests camera/QR/offline | Không tự đổi owner, xác nhận tiền hay đóng Issue. |
| **Lý Đình Sơn** | Transaction state, SELL, DONATE, Event/timeline, Issue, thông báo | UI-09/16/17; quy tắc hoàn tất, tiền, lỗi, hủy, tests chuyển trạng thái/concurrency | Không tự duyệt Request, tạo holder update không có Handover. |

**Ranh giới phối hợp:** Khanh sở hữu use case duyệt Request, Đăng sở hữu Handover, Sơn sở hữu Transaction workflow, Trường sở hữu Material/Shared contracts. Tác động xuyên nhiều bảng nằm **trong RPC server nguyên tử**, không chia thành bốn lệnh cập nhật client.

**Danh mục UI dùng chung:** UI-01 Đăng nhập; 02 Trang chủ; 03 Khám phá; 04 Chi tiết tài liệu; 05 Đăng tài liệu; 06 Tài liệu của tôi/QR; 07 Gửi yêu cầu; 08 Danh sách yêu cầu; 09 Chi tiết giao dịch/timeline/SELL; 10 Chọn giao/điểm hẹn; 11 Danh sách giao hộ; 12 Chi tiết giao hộ; 13 Quét/chụp ảnh; 14 Receiver xác nhận; 15 Mượn/trả; 16 Hoạt động/lịch sử; 17 Thông báo; 18 Cá nhân. **Tái sử dụng UI-13/14 cho mọi chặng**, không mỗi module tạo một màn hình bàn giao riêng.

**Trạng thái UI tối thiểu ở màn hình có mạng/camera:** loading, empty, error, offline, no permission, QR mismatch, awaiting receiver, conflicting update; không báo thành công trước server ACK.

---

## 16. Test nghiệm thu bắt buộc cho nhóm

| ID | Kịch bản thực thi | Kết quả bắt buộc |
|---|---|---|
| AC-01 | Hai sách cùng tên/ISBN | Hai Material ID và QR riêng. |
| AC-02 | 3 Request cùng Listing, A duyệt Request thứ 2 | Chỉ 1 ACCEPTED/Transaction; 2 REJECTED, có timestamp. |
| AC-03 | Hai thao tác duyệt đồng thời | Không tạo 2 Transaction active cho một Material. |
| AC-04 | Listing PUBLISHED nhưng RESERVED | Vẫn hiện “Đã được đặt”; client và server chặn Request mới. |
| AC-05 | QR Handover đọc được nhưng sai | Chặn, không manual override. |
| AC-06 | QR không có/không đọc được | Fallback có lý do, vẫn ảnh + receiver xác nhận. |
| AC-07 | Handover thiếu ảnh/người giao tự confirm | Server không đổi holder. |
| AC-08 | A→C→B, mỗi chặng ảnh/confirm | Holder A→C→B đúng 2 Event. |
| AC-09 | Mượn trực tiếp và trả trực tiếp | B nhận mới bắt đầu mượn; A nhận mới COMPLETED; Listing ARCHIVED. |
| AC-10 | BORROW 7 ngày nhận 21/11 | due 28/11 (giờ Việt Nam); overdue từ 29/11. |
| AC-11 | B→C trả đúng hạn, A không nhận | Giữ mốc trả ban đầu; chưa COMPLETED; không cộng trễ mượn gốc vì A trì hoãn. |
| AC-12 | C chiều trả giao thất bại, C→B hợp lệ | Holder trở B, có hạn 3 ngày tái bàn giao riêng. |
| AC-13 | DONATE cuối cùng B nhận | Owner/holder B, COMPLETED, archive Listing. |
| AC-14 | SELL trước A xác nhận tiền, thử A→B hoặc A→C | Server từ chối mọi Handover SELL. |
| AC-15 | SELL tiền trước + B nhận cuối | Owner chỉ đổi B một lần sau B confirm. |
| AC-16 | C đã nhận tài liệu nhưng giao thất bại | Holder=C, Task FAILED, trả người đã giao C bằng Handover mới. |
| AC-17 | Receiver từ chối trước nhận | Handover DISPUTED, Issue OPEN, holder không đổi. |
| AC-18 | B nhận rồi khiếu nại trong 7 ngày | Issue OPEN, không rollback Handover/owner/holder. |
| AC-19 | A im lặng, B chỉ ghi ý định trả | Không tự đổi holder hoặc COMPLETED, giữ due_date; có Issue. |
| AC-20 | Hai bên yêu cầu hủy khi còn sách/tiền/Issue | Server từ chối; khi đủ đồng thuận và hết nghĩa vụ mới CANCELLED. |
| AC-21 | Offline lúc chụp/upload Evidence | Nháp local, không thành công giả; retry không trùng event. |
| AC-22 | Người không thuộc Transaction mở private evidence | RLS/Storage từ chối. |
| AC-23 | Giao nhiệm vụ cho hai C gần như cùng lúc | Chỉ một ACCEPTED, Task có một courier. |
| AC-24 | C rút trước pickup | Không đổi holder; Task cũ hủy đúng quy tắc, Task mới không dùng ảnh cũ. |
| AC-25 | Bán đã nhận tiền, C trả sách về A rồi hai bên đồng ý hủy | A hoàn tiền ngoài app, B xác nhận đã nhận hoàn, mới cho CANCELLED. |

**Bằng chứng mỗi cá nhân:** UI chạy trên emulator/Android, unit/widget tests cho phân hệ, mock scenario và real repository đúng interface, commit/PR cá nhân. Test được ghi “đạt” **chỉ khi đã chạy**, không đánh dấu bằng lời mô tả.

---

## 17. Thứ tự thực hiện từ tài liệu đến sản phẩm

1. **Ngay sau khi nhóm trưởng ban hành bản SS-BR này:** Cả bốn người lấy **tài liệu này** làm chuẩn nghiệp vụ. Không tiếp tục vòng review/chốt quyết định BOOT/PRIV; không tự sửa rule vì thấy file v1.2 cũ.
2. **Trường – Giai đoạn 3, Khung kỹ thuật:** khóa `MO_HINH_DU_LIEU.md`, `HOP_DONG_LAP_TRINH.md`, cấu trúc Flutter `lib/features/{auth,materials,discovery,requests,borrowing,delivery,handovers,transactions,issues}`, `lib/core`, theme, routes, shared enums/models, Mock Store và error types. Các file này **phải dùng đúng các bất biến trong tài liệu hiện tại**.
3. **Giai đoạn 4, chia GitHub Issues:** giao Khanh/Đăng/Sơn mỗi chức năng có UI, domain, repository, mock, test, dependency và tiêu chí nghiệm thu AC-x liên quan. Tránh làm trùng shared models.
4. **Giai đoạn 5, Foundation:** Trường tạo Flutter Android app và mô-đun nền; các thành viên xây module độc lập dùng Mock, sau đó tích hợp Supabase theo RPC nguyên tử.
5. **Giai đoạn 6, tích hợp:** feature branch → PR vào `integration/nhom12-65ktpm`; khi đạt test/CI → PR sang `nhom12-65ktpm`; cuối kỳ từ nhánh chính thức của nhóm tạo PR nộp `oanhcuongdo/project-ptuddd:main`. **Không push thẳng lên main của giảng viên.**

### 17.1. Luật thay đổi sau khi ban hành

- **Quyết định nghiệp vụ thuộc nhóm trưởng**; các thành viên làm theo bản đã ban hành, không cần biểu quyết lại từng BR nếu không có mâu thuẫn mới.
- Thành viên có thể báo bug hoặc vấn đề bất khả thi qua GitHub Issue với mã INV/AC/mục liên quan. **Không tự tạo quyền, status hoặc ngoại lệ mới trong code**.
- PR code vẫn cần review chất lượng, test và lịch sử tác giả theo quy trình Git nhóm; điều này **khác** việc bắt cả nhóm biểu quyết lại nghiệp vụ.
- Đề cương và các file SS-BR v1.2 (lịch sử), SS-WF v1.2 và SS-SON v1.1 có thể chứa mô tả cũ, đặc biệt `SELL sách trước tiền`: bản này **thay thế ý nghĩa cũ** cho MVP. Khi có thời gian, đồng bộ các file phụ, nhưng không trì hoãn lập trình vì các vòng ngoại lệ quản trị.

## 18. Checklist giao việc ngay sau khi tài liệu hiện diện trên GitHub

- [ ] Trường công bố đường dẫn `docs/QUY_TAC_NGHIEP_VU.md` và version cho cả nhóm.
- [ ] Trường tạo Shared Models + trạng thái chuẩn theo mục 11 (không cần hỏi lại `NEEDS_RESOLUTION`).
- [ ] Trường tạo mô hình dữ liệu/contracts kỹ thuật theo mục 12, Mock fixture A/B/C + 2 Materials + đủ case AC-01,02,05,09,14.
- [ ] Khanh nhận issue Discovery/Request/Borrow/Return, viết UI + repository mock + unit/widget test.
- [ ] Đăng nhận issue Task/QR/Handover/Offline, viết UI + camera/QR mock + Android device test.
- [ ] Sơn nhận issue Transaction/SELL/Issue/Event, viết UI + state service + test concurrency.
- [ ] Tích hợp kịch bản AC-09 mượn–trả trước, sau đó AC-08 giao hộ, AC-13 DONATE, AC-15 SELL, AC-16/17/21 ngoại lệ.

---

**Điểm dừng phạm vi:** Tài liệu này giải quyết nghiệp vụ **đủ để phát triển ứng dụng Android cuối kỳ**. Không tiếp tục mở chuỗi ai bổ nhiệm ai, ai ký thay ai hoặc quyền xuất ảnh nhiều cấp trong MVP. Mọi thay đổi ngoài phạm vi phải do trưởng nhóm quyết định rõ ràng, không tự phát sinh từ màn hình hay câu hỏi của AI.


---

## Phụ lục A. Bảng tra mã quy tắc BR-01 đến BR-50 (giữ tương thích tài liệu cũ)

Các mã `BR-xx` **được giữ nguyên**, để `QUY_TRINH_HOAT_DONG.md`, test cases, GitHub Issues và code không mất tham chiếu. Nếu mô tả ở phụ lục rút gọn, **nội dung chi tiết ở các mục 1–18 phía trên có hiệu lực ưu tiên**. Nhãn `QUY ƯỚC MVP` dùng cho quyết định thiết kế được chuẩn hóa trong bản 2.0, không tuyên bố đã được chốt từ v1.2.

| Mã | Phân loại | Quy tắc/ý nghĩa tham chiếu |
|---|---|---|
| BR-01 | ĐÃ CHỐT | Một tài khoản sinh viên có thể thực hiện nhiều vai trò khác nhau ở các giao dịch khác nhau. Quyền thao tác phụ thuộc **quan hệ với giao dịch**, không chỉ vai trò trên hồ sơ. |
| BR-02 | ĐÃ CHỐT | Mỗi bản vật lý là **một Material ID/QR riêng**. ISBN/barcode của nhà xuất bản chỉ để tham khảo; không được dùng ISBN làm khóa duy nhất. |
| BR-03 | ĐÃ CHỐT | **Material và Listing là hai khái niệm tách biệt**: Material giữ danh tính xuyên suốt; một lần đăng cho mượn/bán/tặng là một Listing. |
| BR-04 | ĐÃ CHỐT | Một Material **chỉ có một hình thức công khai tại một thời điểm**; mỗi Listing có chính xác một `offer_type` thuộc BORROW/DONATE/SELL. |
| BR-05 | ĐÃ CHỐT | Một Material không được có hai giao dịch đã chấp thuận **đang hoạt động** đồng thời. Việc chặn phải được thực hiện tại server. |
| BR-06 | ĐÃ CHỐT | Chỉ chủ sở hữu được đăng, sửa hoặc ẩn Listing của Material mình sở hữu. Thông tin giao dịch đã chốt không được bị thay đổi ngược bởi việc sửa bài đăng. |
| BR-07 | ĐÃ CHỐT | Một Material có tối đa một Listing hiện hành; Listing cũ chuyển `ARCHIVED` sau BORROW hoàn tất hoặc chuyển nhượng kết thúc. Không tự công khai lại Listing cũ: chủ sở hữu tạo Listing mới, **giữ Material ID và QR cũ**. |
| BR-08 | QUY ƯỚC MVP | Listing khi xuất bản: tên, môn/loại, tình trạng, ít nhất một ảnh, đúng một hình thức; SELL giá VND > 0. |
| BR-09 | ĐÃ CHỐT | Không được đổi hình thức, giá hoặc điều kiện đã chấp thuận làm sai thỏa thuận trong Transaction hiện hành. Quyền chỉnh sửa thuộc tính khác phải được kiểm tra ở server; không sửa hồi tố snapshot giao dịch. |
| BR-10 | ĐÃ CHỐT | Sau chuyển nhượng hoàn tất, Material giữ nguyên ID, QR và lịch sử; **chủ mới** có thể tạo Listing mới. Listing của chủ cũ đã `ARCHIVED`. |
| BR-11 | ĐÃ CHỐT | Có thể có **nhiều ExchangeRequest PENDING** cho cùng một Listing, nhưng chỉ **một yêu cầu được ACCEPTED**. |
| BR-12 | ĐÃ CHỐT | Khi A duyệt yêu cầu B, các yêu cầu PENDING còn lại của bản tài liệu đó **tự chuyển REJECTED**, lý do `MATERIAL_UNAVAILABLE`. |
| BR-13 | QUY ƯỚC MVP | Danh sách yêu cầu ghi thời điểm server, mặc định hiển thị từ cũ đến mới; A không bắt buộc duyệt FIFO. |
| BR-14 | ĐÃ CHỐT | Duyệt yêu cầu, từ chối các yêu cầu cạnh tranh, giữ chỗ Material, tạo Transaction và ghi sự kiện phải diễn ra **nguyên tử trên server**: tất cả thành công hoặc tất cả thất bại. |
| BR-15 | QUY ƯỚC MVP | Không cho tự yêu cầu bản sách mình sở hữu hoặc tạo hai yêu cầu PENDING trùng người/Listing; tuân thủ BR-49. |
| BR-16 | QUY ƯỚC MVP | Thời điểm duyệt/từ chối và lý do do server ghi; ACCEPTED không đổi ngược về PENDING. |
| BR-17 | ĐÃ CHỐT | Với BORROW, `owner_id` **không đổi** trong suốt thời gian mượn. `holder_id` chỉ đổi sau các Handover được xác nhận. |
| BR-18 | ĐÃ CHỐT | **Thời gian mượn bắt đầu khi B thực sự xác nhận nhận sách và server ghi nhận bàn giao thành công**, không tính từ lúc A duyệt. |
| BR-19 | ĐÃ CHỐT | Một giao dịch mượn chỉ `COMPLETED` sau khi **A xác nhận đã nhận lại đúng sách** qua lượt bàn giao cuối có ảnh. |
| BR-20 | ĐÃ CHỐT | B đề xuất **1–30 ngày mượn**; A chỉ chấp thuận đúng số ngày hoặc từ chối; không thương lượng hoặc gia hạn trong MVP. Lưu số ngày đã đồng ý theo snapshot Transaction. |
| BR-21 | ĐÃ CHỐT | Hạn trả là **ngày lịch Việt Nam (`Asia/Ho_Chi_Minh`)** từ ngày B nhận hợp lệ; ví dụ nhận 21/11, mượn 7 ngày thì hạn cuối 28/11 (hết ngày). Quá hạn từ 29/11; `OVERDUE` là thông tin suy ra, không thay trạng thái. Việc mở Issue không tự gia hạn/đóng băng `due_date`. |
| BR-22 | ĐÃ CHỐT | Khi trả sách, B có thể trả trực tiếp hoặc nhờ người giao hộ; nếu qua người giao hộ, đây là **DeliveryTask mới**, có các Handover và ảnh riêng. |
| BR-23 | ĐÃ CHỐT | Không hủy BORROW khi còn tài liệu cần hoàn trả, thanh toán chưa đối soát hoặc Issue mở. Phải giao trả hợp lệ hoặc giải quyết nghĩa vụ liên quan; **không có gia hạn mượn trong MVP**. |
| BR-24 | ĐÃ CHỐT | DONATE không phát sinh thanh toán; sau khi người nhận xác nhận bàn giao hợp lệ, Transaction hoàn tất và `owner_id` chuyển sang người nhận. |
| BR-25 | ĐÃ CHỐT | Với SELL, ứng dụng **không chuyển tiền và không tự kiểm tra tài khoản ngân hàng**. Người mua chuyển khoản **ngoài ứng dụng** theo QR/thông tin người bán; A kiểm tra và bấm xác nhận đã nhận tiền. |
| BR-26 | ĐÃ CHỐT | SELL chỉ `COMPLETED` khi **A đã xác nhận nhận tiền trước bàn giao** và **B đã xác nhận nhận sách hợp lệ**. Trước khi B nhận, `owner_id` vẫn là A; khi B xác nhận lượt nhận cuối, server chuyển `owner_id`/`holder_id` sang B nguyên tử. Việc B đã cầm sách ngoài quy trình không tự hợp thức hóa bàn giao. |
| BR-27 | ĐÃ CHỐT | QR/thông tin chuyển khoản SELL chỉ được hiển thị **sau khi A chấp thuận yêu cầu mua**. |
| BR-28 | QUY ƯỚC MVP | Khi A duyệt SELL, lưu giá và tham chiếu chuyển khoản snapshot; B báo đã chuyển tiền không tương đương xác nhận của A. |
| BR-29 | ĐÃ CHỐT | **Mọi Handover SELL (trực tiếp hoặc qua C) bị chặn cho tới khi A xác nhận đã nhận tiền ngoài ứng dụng**. Chỉ hiển thị «đã nhận tiền» sau ACK server; không tự suy ra thanh toán từ thông báo của B. Nếu có giao sách ngoài hệ thống trái quy trình, ghi Issue để đối soát, không coi đó là Handover hợp lệ. |
| BR-30 | ĐÃ CHỐT | **Mọi Handover** đều phải có ít nhất **một ảnh minh chứng**, bao gồm giao trực tiếp, A→C, C→B, trả trực tiếp và trả qua C. |
| BR-31 | ĐÃ CHỐT | **Người giao từng chặng** chụp và gửi ít nhất một ảnh; **người nhận được chỉ định** xác nhận đã nhận. Người giao không được xác nhận thay người nhận. |
| BR-32 | ĐÃ CHỐT | Ưu tiên **QR tài liệu**; nếu **không có mã dán** hoặc **camera không đọc được mã**, cho phép đối chiếu bằng **QR lượt bàn giao** hoặc **thủ công có ghi lý do**. Dù dùng cách thủ công, vẫn phải có ảnh và người nhận xác nhận. **Mã QR đọc được nhưng không khớp không phải lý do để bỏ qua xác thực** (xem BR-50). |
| BR-33 | ĐÃ CHỐT | Chỉ sau khi ảnh đã được server ghi nhận và người nhận xác nhận, Handover mới thành công và server cập nhật `holder_id`, lịch sử, trạng thái liên quan. |
| BR-34 | ĐÃ CHỐT | Từ chối trước khi nhận vì sai/hỏng/chưa nhận: Handover DISPUTED, mở Issue, không đổi holder; phản ánh sau đã nhận không đảo ngược Handover. |
| BR-35 | ĐÃ CHỐT | Khi mất mạng hoặc upload lỗi: lưu ảnh/bản nháp trên điện thoại, hiển thị “chưa gửi/chưa xác nhận”; **không** tự thông báo bàn giao hoàn tất. |
| BR-36 | QUY ƯỚC MVP | Handover dùng ID ổn định và idempotency key, xác nhận/nhấn lại không cập nhật holder hoặc event hai lần. |
| BR-37 | ĐÃ CHỐT | Có hai phương thức: **giao trực tiếp** (A→B) và **giao hộ** (A→C→B). |
| BR-38 | ĐÃ CHỐT | Với giao hộ, sinh viên C **tự đăng ký** nhận nhiệm vụ; **người tạo nhiệm vụ** chọn và chấp thuận một người giao hộ. |
| BR-39 | ĐÃ CHỐT | Giao hộ có **hai Handover riêng**: bên gửi→C và C→bên nhận cuối. Việc C tự bấm “đã giao” không đủ để kết thúc lượt thứ hai. |
| BR-40 | ĐÃ CHỐT | StudyShare v1.1 hỗ trợ **GPS để xác định vị trí tham khảo/điểm lấy và điểm giao, hỗ trợ chỉ đường** giữa các điểm hẹn. |
| BR-41 | QUY ƯỚC MVP | Người đang giữ và có nhiệm vụ gửi là người tạo Task; người tạo chọn duy nhất một C; C không phải người gửi/người nhận chặng đó. |
| BR-42 | QUY ƯỚC MVP | Điểm hẹn cần mô tả; tọa độ GPS tùy chọn theo quyền người dùng, không tracking nền. |
| BR-43 | QUY ƯỚC MVP | Chỉ người có quyền được xem dữ liệu điểm hẹn chi tiết; chỉ đường/GPS không đủ là bằng chứng giao nhận. |
| BR-44 | ĐÃ CHỐT | Nếu C đã xác nhận lấy sách nhưng giao thất bại, hệ thống tiếp tục ghi nhận C đang giữ; phải giao lại, bàn giao trả hoặc mở Issue, **không tự đặt lại AVAILABLE**. |
| BR-45 | ĐÃ CHỐT | Sau ACCEPTED, A/B đề nghị hủy có lý do và bên kia đồng ý; chỉ CANCELLED khi không còn nghĩa vụ vật lý/tiền/Issue, archive Listing nguyên tử. |
| BR-46 | ĐÃ CHỐT | Không tự chuyển sang `COMPLETED` chỉ vì quá thời gian người nhận chưa phản hồi; giữ `AWAITING_RECEIVER_CONFIRMATION`, cho nhắc xác nhận hoặc mở Issue. |
| BR-47 | ĐÃ CHỐT | Khắc phục sự cố qua Handover mới/Issue; không tự sửa holder/owner, không tự đóng Issue khi các bên chưa xác nhận. |
| BR-48 | QUY ƯỚC MVP | MVP có danh sách/chi tiết Issue và thông báo trong ứng dụng; UI Admin hoàn chỉnh và push notifications không bắt buộc. |
| BR-49 | ĐÃ CHỐT | `Listing.status = PUBLISHED` vẫn có thể hiển thị trong kết quả khám phá khi Material đã `RESERVED`, nhưng phải có nhãn **Đã được đặt** và **khóa nút Gửi yêu cầu**. Server phải từ chối tạo yêu cầu mới khi Material không khả dụng. Listing `ARCHIVED` **không hiển thị** trong danh sách khám phá thông thường. |
| BR-50 | ĐÃ CHỐT | Nếu hệ thống **đọc được QR nhưng mã không khớp** với Material/Handover cần bàn giao, **chặn xác nhận lượt bàn giao hiện tại**, báo sai mã và yêu cầu kiểm tra/đối chiếu lại đúng tài liệu. **Không cho chuyển sang thủ công để vượt qua kết quả không khớp đó.** |

### Phụ lục A.1. Trạng thái OPEN-01 đến OPEN-10 của bản SS-BR cũ

| Mã OPEN | Kết quả áp dụng trong bản 2.0 |
|---|---|
| OPEN-01 | Đã chốt: không tự đăng lại Listing cũ, tạo Listing mới dùng cùng Material/QR. |
| OPEN-02 | Đã chốt: BORROW nguyên 1–30 ngày; B đề xuất và A duyệt nguyên số ngày hoặc từ chối. |
| OPEN-03 | Quy ước MVP-D05: người có quyền được báo Issue ngay khi cần, không tự CONFIRMED theo timeout. |
| OPEN-04 | Đã chốt: A/B cùng đồng ý và không còn nghĩa vụ sách/tiền/Issue; hủy server nguyên tử. |
| OPEN-05 | Quy ước MVP: không bắt buộc khu vực người yêu cầu trong Request, ghi điểm hẹn ở chặng giao nhận; không thu GPS âm thầm. |
| OPEN-06 | Đã chốt: QR chuyển khoản SELL chỉ mở sau A duyệt. |
| OPEN-07 | Đã chốt: tính ngày hạn theo `Asia/Ho_Chi_Minh`, quá hạn từ ngày lịch kế tiếp. |
| OPEN-08 | Đã chốt nguyên tắc: các bên bị ảnh hưởng trực tiếp cùng xác nhận giải quyết Issue; admin/moderator không tự đóng thay. |
| OPEN-09 | Quy ước MVP-D04: C rút trước Handover nhận; Task đã phân công nhưng chưa nhận có thể hủy có lý do rồi tạo Task mới. |
| OPEN-10 | Quy ước MVP-D07: mô tả điểm hẹn, GPS tùy chọn, mở bản đồ ngoài app, không theo dõi liên tục. |

**Ghi chú thay đổi:** Bản 2.0 tích hợp các nội dung nghiệp vụ từ tài liệu hướng dẫn đã soạn trước đó **vào đúng tệp `QUY_TAC_NGHIEP_VU.md`**; không duy trì một file hướng dẫn nghiệp vụ khác tên trong thư mục `docs/`. Các tài liệu workflow/phân hệ vẫn giữ tên riêng vì phục vụ mô tả luồng và trách nhiệm, không thay thế nguồn quy tắc SS-BR.
