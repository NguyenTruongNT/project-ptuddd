# QUY TẮC NGHIỆP VỤ STUDYSHARE

> **Mã tài liệu:** SS-BR  
> **Phiên bản:** 1.2 – Bổ sung các quyết định đã chốt; vẫn còn mục đề xuất trước khi khóa Dart Contracts
> **Dự án:** StudyShare – Ứng dụng di động hỗ trợ cho mượn, chuyển nhượng tài liệu học tập và xác thực giao nhận giữa sinh viên  
> **Nhóm:** 12 – 65KTPM  
> **Phụ trách tổng hợp:** Nguyễn Văn Trường (nhóm trưởng)  
> **Ngày biên soạn:** 21/11/2026  
> **Phạm vi:** Flutter/Dart trên Android; không phát triển giao diện Web trong MVP.

## 0. Cách sử dụng tài liệu

Đây là **nguồn quy tắc nghiệp vụ chung** để bốn thành viên và các công cụ AI làm việc thống nhất. Không tự phát triển thêm nghiệp vụ hoặc thay đổi ý nghĩa của trạng thái nếu chưa được nhóm thống nhất.

- **[ĐÃ CHỐT]:** Đã được nhóm trưởng xác nhận trong quá trình phân tích hoặc đã có trong đề cương và tiếp tục được giữ nguyên.
- **[ĐỀ XUẤT]:** Phương án hợp lý để phát triển, **chưa coi là quyết định chính thức**; phải được rà soát trước khi khóa Contracts.
- **[CHƯA QUYẾT ĐỊNH]:** Thiếu thông tin; không để AI tự suy đoán.

**Nguồn tham chiếu:** `docs/De_cuong_StudyShare_Nhom12_65KTPM.docx` (đề cương mục tiêu, phân công), các quyết định đã chốt của nhóm; `README.md` tại gốc repository của thầy (quy định GitHub). **Khi có mâu thuẫn:** mở Issue thảo luận, sửa tài liệu và các Contracts/test liên quan trong cùng Pull Request. Không tự ghi đè một nguồn khác.

**Tên thành viên chính xác:** Nguyễn Văn Trường, **Vũ Tuấn Khanh**, Vũ Hải Đăng, Lý Đình Sơn. Không có thành viên Đinh Trọng Nhật. Bản DOCX trước đây có chỗ ghi “Khánh”; khi chỉnh đề cương phải đồng bộ thành **Khanh**.

## 1. Bài toán, phạm vi và thuật ngữ

### 1.1. Bài toán giải quyết

Sinh viên có sách, giáo trình, vở ghi hoặc tài liệu học tập vật lý muốn **cho mượn**, **tặng miễn phí** hoặc **bán lại**. Người cần tài liệu khó tìm kiếm, khó kiểm soát quá trình bàn giao và không có lịch sử xác nhận rõ ràng. StudyShare hỗ trợ đăng tài liệu, tìm kiếm, gửi yêu cầu, chấp thuận, bàn giao trực tiếp hoặc qua sinh viên giao hộ, xác nhận bằng ảnh và theo dõi mượn/trả hoặc chuyển nhượng.

### 1.2. Phạm vi [ĐÃ CHỐT]

- Ứng dụng **Android** dùng Flutter/Dart, UI tiếng Việt; dữ liệu demo là tài liệu thật nhóm sở hữu.
- Hai hình thức nghiệp vụ chính: **BORROW (cho mượn)** và **TRANSFER (chuyển nhượng)**. TRANSFER gồm **DONATE (tặng)** và **SELL (bán)**.
- **Không** triển khai đổi sách lấy sách, UI Web, ví điện tử hoặc tự động kiểm tra giao dịch ngân hàng.
- Mọi sinh viên có tài khoản có thể đóng vai chủ tài liệu, người nhận/mượn, hoặc người giao hộ theo **từng giao dịch**, không phải ba loại tài khoản cố định.
- Camera, mã QR, ảnh minh chứng và xác nhận người nhận là phần cốt lõi; GPS hỗ trợ điểm lấy/giao và chỉ đường.
- Supabase Auth/PostgreSQL/Storage và bộ nhớ cục bộ cho bản nháp, ảnh chờ gửi là kiến trúc dự kiến.

### 1.3. Từ điển nghiệp vụ

| Thuật ngữ | Định nghĩa thống nhất |
|---|---|
| `Material` | **Một bản sách/vở vật lý cụ thể**; có ID riêng dù trùng tên hoặc ISBN với bản khác. |
| `Listing` | Một **lượt đăng công khai** cho một `Material`, tại một thời điểm có **một hình thức**: BORROW, DONATE hoặc SELL. |
| `ExchangeRequest` | Yêu cầu của sinh viên B đối với một Listing; có thời điểm gửi do server ghi nhận. |
| `Transaction` | Giao dịch được tạo khi chủ sách chấp thuận yêu cầu; điều phối mượn/chuyển nhượng. |
| `BorrowingRecord` | Nghĩa vụ mượn/trả và thời hạn đối với giao dịch BORROW. |
| `DeliveryTask` | Một **chuyến giao hộ** (điểm lấy → điểm giao); lượt trả có thể tạo nhiệm vụ mới. |
| `Handover` | **Một lượt bàn giao** từ một người X sang một người Y, có ảnh và xác nhận của Y. |
| `HandoverEvidence` | Ảnh minh chứng thuộc **đúng một** Handover. |
| `owner_id` | Người sở hữu được **hệ thống ghi nhận** của Material. |
| `holder_id` | Người **đang giữ được hệ thống ghi nhận sau lần bàn giao xác nhận gần nhất**; không nhất thiết phản ánh chắc chắn ai đang cầm sách ngoài đời nếu có tranh chấp. |
| `TransactionEvent` | Bản ghi lịch sử: sự kiện, người thực hiện, thời gian, đối tượng liên quan. |
| `Issue` | Vụ việc cần xử lý: bàn giao tranh chấp, giao thất bại, mất liên lạc… |

## 2. Quy tắc tài khoản, bản sách và bài đăng

| Mã | Trạng thái | Quy tắc nghiệp vụ |
|---|---|---|
| BR-01 | [ĐÃ CHỐT] | Một tài khoản sinh viên có thể thực hiện nhiều vai trò khác nhau ở các giao dịch khác nhau. Quyền thao tác phụ thuộc **quan hệ với giao dịch**, không chỉ vai trò trên hồ sơ. |
| BR-02 | [ĐÃ CHỐT] | Mỗi bản vật lý là **một Material ID/QR riêng**. ISBN/barcode của nhà xuất bản chỉ để tham khảo; không được dùng ISBN làm khóa duy nhất. |
| BR-03 | [ĐÃ CHỐT] | **Material và Listing là hai khái niệm tách biệt**: Material giữ danh tính xuyên suốt; một lần đăng cho mượn/bán/tặng là một Listing. |
| BR-04 | [ĐÃ CHỐT] | Một Material **chỉ có một hình thức công khai tại một thời điểm**; mỗi Listing có chính xác một `offer_type` thuộc BORROW/DONATE/SELL. |
| BR-05 | [ĐÃ CHỐT] | Một Material không được có hai giao dịch đã chấp thuận **đang hoạt động** đồng thời. Việc chặn phải được thực hiện tại server. |
| BR-06 | [ĐÃ CHỐT] | Chỉ chủ sở hữu được đăng, sửa hoặc ẩn Listing của Material mình sở hữu. Thông tin giao dịch đã chốt không được bị thay đổi ngược bởi việc sửa bài đăng. |
| BR-07 | [ĐỀ XUẤT] | Mỗi Material có tối đa **một Listing hiện hành** (`DRAFT`/`PUBLISHED`/`HIDDEN`); Listing cũ được `ARCHIVED` khi kết thúc. Không tự công khai bài cũ sau trả sách. |
| BR-08 | [ĐỀ XUẤT] | Khi công khai Listing, phải có tên, môn/loại tài liệu, mô tả tình trạng, **ít nhất một ảnh**, hình thức chia sẻ; với SELL phải có giá bán VND lớn hơn 0. |
| BR-09 | [ĐỀ XUẤT] | Material đã được giữ chỗ/đang mượn/đang xử lý chuyển nhượng không được đổi hình thức, giá hoặc các thuộc tính làm sai thỏa thuận; chủ sách có thể xem nhưng chỉ chỉnh sửa thuộc tính được cho phép. |
| BR-10 | [ĐỀ XUẤT] | Sau chuyển nhượng hoàn tất, Material giữ nguyên ID và lịch sử; **chủ mới** có thể tạo Listing mới cho Material đó. |

**Gợi ý tách trạng thái:** `Listing.status = DRAFT / PUBLISHED / HIDDEN / ARCHIVED`; khả dụng bản vật lý được xác định bởi giao dịch hiện hành, không để nhiều module tự chỉnh một cột status tùy ý. Tên enum chính thức sẽ khóa trong `STATE_MACHINES.md` và `CONTRACTS.md`.

## 3. Quy tắc tìm kiếm, gửi yêu cầu và duyệt yêu cầu

| Mã | Trạng thái | Quy tắc nghiệp vụ |
|---|---|---|
| BR-11 | [ĐÃ CHỐT] | Có thể có **nhiều ExchangeRequest PENDING** cho cùng một Listing, nhưng chỉ **một yêu cầu được ACCEPTED**. |
| BR-12 | [ĐÃ CHỐT] | Khi A duyệt yêu cầu B, các yêu cầu PENDING còn lại của bản tài liệu đó **tự chuyển REJECTED**, lý do `MATERIAL_UNAVAILABLE`. |
| BR-13 | [ĐÃ CHỐT] | Danh sách yêu cầu hiển thị **thời điểm gửi** (do server ghi nhận), hỗ trợ chủ sách lựa chọn người nhận. **[ĐỀ XUẤT]** Mặc định sắp **cũ nhất trước**; không bắt buộc duyệt theo FIFO. |
| BR-14 | [ĐÃ CHỐT] | Duyệt yêu cầu, từ chối các yêu cầu cạnh tranh, giữ chỗ Material, tạo Transaction và ghi sự kiện phải diễn ra **nguyên tử trên server**: tất cả thành công hoặc tất cả thất bại. |
| BR-15 | [ĐỀ XUẤT] | Không cho tự yêu cầu Material của mình. Một người không nên có nhiều yêu cầu PENDING trùng nhau cho cùng Listing. Quy tắc tài liệu đã được giữ chỗ xem **BR-49 [ĐÃ CHỐT]**. |
| BR-16 | [ĐỀ XUẤT] | `created_at`, `accepted_at`, người duyệt và lý do từ chối được ghi nhận từ server. `ACCEPTED` không được đổi ngược thành `PENDING`; hủy sau duyệt phải qua nghiệp vụ hủy Transaction. |
| BR-49 | [ĐÃ CHỐT – v1.2] | `Listing.status = PUBLISHED` vẫn có thể hiển thị trong kết quả khám phá khi Material đã `RESERVED`, nhưng phải có nhãn **Đã được đặt** và **khóa nút Gửi yêu cầu**. Server phải từ chối tạo yêu cầu mới khi Material không khả dụng. Listing `ARCHIVED` **không hiển thị** trong danh sách khám phá thông thường. |

**Vị trí của người yêu cầu:** [CHƯA QUYẾT ĐỊNH] Có cần hiển thị **khu vực mong muốn nhận sách** bên cạnh thời điểm gửi không? Nếu có, chỉ dùng khu vực/điểm hẹn được người dùng cung cấp có chủ đích; **không thu thập GPS âm thầm để xếp hạng yêu cầu**.

## 4. Quy tắc cho mượn và trả

| Mã | Trạng thái | Quy tắc nghiệp vụ |
|---|---|---|
| BR-17 | [ĐÃ CHỐT] | Với BORROW, `owner_id` **không đổi** trong suốt thời gian mượn. `holder_id` chỉ đổi sau các Handover được xác nhận. |
| BR-18 | [ĐÃ CHỐT] | **Thời gian mượn bắt đầu khi B thực sự xác nhận nhận sách và server ghi nhận bàn giao thành công**, không tính từ lúc A duyệt. |
| BR-19 | [ĐÃ CHỐT] | Một giao dịch mượn chỉ `COMPLETED` sau khi **A xác nhận đã nhận lại đúng sách** qua lượt bàn giao cuối có ảnh. |
| BR-20 | [ĐỀ XUẤT] | B đề xuất **số ngày mượn**; A chấp thuận đúng số ngày hoặc từ chối (không thương lượng trong MVP). Lưu `agreed_borrow_days` trong giao dịch đã chốt. |
| BR-21 | [ĐỀ XUẤT] | Hạn trả tính theo **ngày lịch Việt Nam (Asia/Ho_Chi_Minh)** từ ngày nhận hợp lệ; ví dụ nhận 21/11, mượn 7 ngày thì hạn cuối 28/11. `OVERDUE` được **suy ra** từ ngày và trạng thái, không thay thế trạng thái giao dịch. |
| BR-22 | [ĐÃ CHỐT] | Khi trả sách, B có thể trả trực tiếp hoặc nhờ người giao hộ; nếu qua người giao hộ, đây là **DeliveryTask mới**, có các Handover và ảnh riêng. |
| BR-23 | [ĐỀ XUẤT] | Không hủy giao dịch mượn đơn giản khi B/C đã giữ sách; phải hoàn trả hợp lệ hoặc mở Issue. Gia hạn mượn không thuộc MVP ban đầu. |

## 5. Quy tắc chuyển nhượng (tặng / bán)

| Mã | Trạng thái | Quy tắc nghiệp vụ |
|---|---|---|
| BR-24 | [ĐÃ CHỐT] | DONATE không phát sinh thanh toán; sau khi người nhận xác nhận bàn giao hợp lệ, Transaction hoàn tất và `owner_id` chuyển sang người nhận. |
| BR-25 | [ĐÃ CHỐT] | Với SELL, ứng dụng **không chuyển tiền và không tự kiểm tra tài khoản ngân hàng**. Người mua chuyển khoản **ngoài ứng dụng** theo QR/thông tin người bán; A kiểm tra và bấm xác nhận đã nhận tiền. |
| BR-26 | [ĐÃ CHỐT] | SELL chỉ `COMPLETED` khi **đã xác nhận giao nhận** và **A đã xác nhận tiền**. Trước khi đủ hai điều kiện, `owner_id` vẫn là A; nếu B đã nhận sách thì `holder_id` là B. |
| BR-27 | [ĐỀ XUẤT] | QR chuyển khoản chỉ hiển thị **sau khi A chấp thuận yêu cầu mua**, tránh B chuyển tiền khi chưa được A đồng ý bán. |
| BR-28 | [ĐỀ XUẤT] | Giá và nội dung chuyển khoản được cố định khi duyệt; QR thể hiện thông tin ngân hàng/đích nhận, số tiền và mã tham chiếu giao dịch. B có thể chọn “Tôi đã chuyển khoản” chỉ để **thông báo**, không phải xác nhận thành công. |
| BR-29 | [ĐỀ XUẤT] | Luồng mặc định là A xác nhận tiền **trước** khi giao sách; vẫn cho phép bàn giao trước thanh toán, khi đó giao dịch chờ xác nhận tiền và không được mở bán lại. |

**Ba QR khác nhau:** (1) **QR tài liệu** định danh Material, (2) **QR lượt bàn giao/giao dịch** định danh Handover thuộc Transaction, (3) **QR chuyển khoản** cung cấp thông tin để trả tiền qua ngân hàng. Không được dùng QR chuyển khoản thay bằng chứng giao sách.

## 6. Quy tắc bàn giao, QR và ảnh minh chứng

| Mã | Trạng thái | Quy tắc nghiệp vụ |
|---|---|---|
| BR-30 | [ĐÃ CHỐT] | **Mọi Handover** đều phải có ít nhất **một ảnh minh chứng**, bao gồm giao trực tiếp, A→C, C→B, trả trực tiếp và trả qua C. |
| BR-31 | [ĐÃ CHỐT] | Người **nhận được chỉ định** phải xác nhận thực sự đã nhận; người giao không được xác nhận thay. **[ĐỀ XUẤT]** Người giao là bên chụp/gửi ảnh cho mỗi lượt bàn giao. |
| BR-32 | [ĐÃ CHỐT] | Ưu tiên **QR tài liệu**; nếu **không có mã dán** hoặc **camera không đọc được mã**, cho phép đối chiếu bằng **QR lượt bàn giao** hoặc **thủ công có ghi lý do**. Dù dùng cách thủ công, vẫn phải có ảnh và người nhận xác nhận. **Mã QR đọc được nhưng không khớp không phải lý do để bỏ qua xác thực** (xem BR-50). |
| BR-50 | [ĐÃ CHỐT – v1.2] | Nếu hệ thống **đọc được QR nhưng mã không khớp** với Material/Handover cần bàn giao, **chặn xác nhận lượt bàn giao hiện tại**, báo sai mã và yêu cầu kiểm tra/đối chiếu lại đúng tài liệu. **Không cho chuyển sang thủ công để vượt qua kết quả không khớp đó.** |
| BR-33 | [ĐÃ CHỐT] | Chỉ sau khi ảnh đã được server ghi nhận và người nhận xác nhận, Handover mới thành công và server cập nhật `holder_id`, lịch sử, trạng thái liên quan. |
| BR-34 | [ĐÃ CHỐT] | Nếu người nhận báo sai/hỏng/chưa nhận, Handover là `DISPUTED`; **không** đổi `holder_id` theo lượt bàn giao chưa xác nhận và phải ghi Issue. |
| BR-35 | [ĐÃ CHỐT] | Khi mất mạng hoặc upload lỗi: lưu ảnh/bản nháp trên điện thoại, hiển thị “chưa gửi/chưa xác nhận”; **không** tự thông báo bàn giao hoàn tất. |
| BR-36 | [ĐỀ XUẤT] | Mỗi Handover có ID ổn định và kiểm tra quyền ở server; nhấn xác nhận/gửi lại nhiều lần **không** tạo nhiều lần chuyển người giữ hoặc nhiều sự kiện trùng. |

**Phân biệt ảnh thực tế và trạng thái server:** Ảnh có thể đã chụp trên máy nhưng chưa được tải lên. Chỉ ảnh đã được server chấp nhận mới là bằng chứng đủ điều kiện mở thao tác xác nhận bên nhận.

## 7. Quy tắc giao hộ, GPS và chỉ đường

| Mã | Trạng thái | Quy tắc nghiệp vụ |
|---|---|---|
| BR-37 | [ĐÃ CHỐT] | Có hai phương thức: **giao trực tiếp** (A→B) và **giao hộ** (A→C→B). |
| BR-38 | [ĐÃ CHỐT] | Với giao hộ, sinh viên C **tự đăng ký** nhận nhiệm vụ; **người tạo nhiệm vụ** chọn và chấp thuận một người giao hộ. |
| BR-39 | [ĐÃ CHỐT] | Giao hộ có **hai Handover riêng**: bên gửi→C và C→bên nhận cuối. Việc C tự bấm “đã giao” không đủ để kết thúc lượt thứ hai. |
| BR-40 | [ĐÃ CHỐT] | StudyShare v1.1 hỗ trợ **GPS để xác định vị trí tham khảo/điểm lấy và điểm giao, hỗ trợ chỉ đường** giữa các điểm hẹn. |
| BR-41 | [ĐỀ XUẤT] | Người tạo nhiệm vụ là người **đang giữ và cần gửi sách ở chặng đó** (lúc trả có thể là B). Chỉ một ứng viên giao hộ được duyệt; không cho chọn người giao hộ là người gửi hoặc người nhận cuối của chính chuyến đó. |
| BR-42 | [ĐỀ XUẤT] | Điểm lấy/điểm giao **phải có mô tả**; tọa độ GPS có thể được cấp quyền hoặc nhập/chọn thủ công. Không bắt buộc GPS, không theo dõi vị trí liên tục trong MVP. |
| BR-43 | [ĐỀ XUẤT] | Chỉ cho người giao hộ đã được duyệt và những bên có liên quan xem vị trí hẹn chi tiết. Việc mở ứng dụng bản đồ để chỉ đường không phải bằng chứng đã giao thành công. |
| BR-44 | [ĐÃ CHỐT] | Nếu C đã xác nhận lấy sách nhưng giao thất bại, hệ thống tiếp tục ghi nhận C đang giữ; phải giao lại, bàn giao trả hoặc mở Issue, **không tự đặt lại AVAILABLE**. |

## 8. Quy tắc hủy, lỗi, tranh chấp và thông báo

| Mã | Trạng thái | Quy tắc nghiệp vụ |
|---|---|---|
| BR-45 | [ĐỀ XUẤT] | Người yêu cầu có thể hủy khi `PENDING`. Sau `ACCEPTED`, chỉ hủy Transaction đơn giản nếu **chưa có bàn giao gửi/chờ xác nhận, chưa có bàn giao thành công và chưa xác nhận tiền**. |
| BR-46 | [ĐÃ CHỐT] | Không tự chuyển sang `COMPLETED` chỉ vì quá thời gian người nhận chưa phản hồi; giữ `AWAITING_RECEIVER_CONFIRMATION`, cho nhắc xác nhận hoặc mở Issue. |
| BR-47 | [ĐỀ XUẤT] | Các hướng xử lý sự cố gồm: thử giao lại, tạo lượt trả về người gửi, các bên xác nhận khắc phục hoặc chuyển chờ quản trị. Không tự sửa `holder_id`/`owner_id` để đóng Issue. |
| BR-48 | [ĐỀ XUẤT] | MVP có trang danh sách/chi tiết Issue và thông báo **trong ứng dụng**; không bắt buộc xây UI Admin đầy đủ hoặc push notification. |

## 9. Những bất biến phải được giữ ở server

1. Không có **hai Transaction hoạt động** trên cùng Material tại một thời điểm.
2. Không có **hai ExchangeRequest ACCEPTED** cạnh tranh trên cùng một lần đăng hiện hành.
3. Không đổi `holder_id` theo Handover thiếu ảnh hoặc chưa được bên nhận xác nhận.
4. Không đổi `owner_id` theo SELL khi chưa đủ bàn giao hợp lệ và người bán xác nhận nhận tiền.
5. Không hoàn tất BORROW khi A chưa nhận lại đúng Material qua Handover hợp lệ.
6. `created_at`, sự kiện duyệt, xác nhận, chuyển quyền là **sự kiện server**; không tin thời gian hoặc `actor_id` tùy ý từ client.
7. Các thao tác liên quan nhiều bảng được thực hiện **nguyên tử** (transaction/RPC có kiểm tra quyền), không để Flutter gửi nhiều câu lệnh cập nhật rời rạc.
8. Các ảnh minh chứng lưu **private**, chỉ những bên có quyền trong giao dịch được xem; không đưa khóa `service_role` vào ứng dụng Android.

**Không được cung cấp API chung** cho client như `updateStatus(id, 'COMPLETED')` để vượt qua nghiệp vụ. Client chỉ yêu cầu các hành động có ý nghĩa, ví dụ `approveRequest`, `submitHandoverEvidence`, `confirmHandover`, `requestReturn`, `confirmSellerPayment`. Chữ ký Dart cụ thể sẽ được khóa riêng trong `CONTRACTS.md`.

## 10. Pipeline nghiệp vụ dùng chung

### P1 – Đăng tài liệu (Trường)

`Đăng nhập → Tạo Material nếu là bản mới → Chụp ảnh/nhập thông tin → Tạo Listing một hình thức → Kiểm tra hợp lệ → Công khai → Sinh/hiển thị QR tài liệu`.

**Điểm kiểm tra:** tài liệu vật lý có ID riêng; chủ sở hữu hợp lệ; không tạo hai Listing hiện hành; không sửa sai thỏa thuận đang hoạt động.

### P2 – Gửi và chấp thuận yêu cầu (Khanh)

`Tìm tài liệu → Xem chi tiết → Gửi ExchangeRequest (PENDING, created_at server) → A xem danh sách theo thời gian → A duyệt một người → server giữ chỗ + tạo Transaction + từ chối yêu cầu khác`.

**Điểm kiểm tra:** hai người duyệt cùng lúc không thể cùng thành công; tất cả module nhìn thấy cùng kết quả.

### P3 – Bàn giao trực tiếp hoặc giao hộ (Đăng)

`Transaction hợp lệ → Chọn trực tiếp/giao hộ → Nếu giao hộ: tạo DeliveryTask → C ứng tuyển → người tạo duyệt → tạo Handover → quét QR/đối chiếu thủ công → người giao chụp ảnh → upload → người nhận xác nhận → server cập nhật holder và sự kiện`.

**Điểm kiểm tra:** mỗi chặng giao hộ là một Handover riêng; GPS/chỉ đường chỉ hỗ trợ; ảnh và xác nhận là bắt buộc.

### P4 – Mượn và trả (Khanh + Đăng + Sơn)

`B xác nhận nhận → bắt đầu kỳ mượn → đến hạn / quá hạn → B yêu cầu trả → chọn trực tiếp/giao hộ → các Handover trả sách → A xác nhận nhận lại → server kết thúc giao dịch và giải phóng Material`.

**Điểm kiểm tra:** hạn trả bắt đầu từ ngày nhận hợp lệ; không đóng giao dịch chỉ vì B đã bấm “Yêu cầu trả”.

### P5 – Tặng / bán tài liệu (Sơn + Đăng)

- **DONATE:** `A duyệt → giao nhận đủ ảnh/xác nhận → hoàn tất → owner chuyển sang B`.
- **SELL:** `A duyệt → B thấy QR chuyển khoản → B chuyển tiền ngoài app → A tự kiểm tra và xác nhận → giao nhận đủ ảnh/xác nhận → hoàn tất → owner chuyển sang B`. Thứ tự xác nhận tiền và giao sách có thể khác nhau; **cả hai điều kiện đều phải có**.

## 11. Phân định trách nhiệm bốn thành viên

| Người phụ trách | Sở hữu nghiệp vụ / UI riêng | Không được làm thay / cập nhật tùy ý |
|---|---|---|
| **Nguyễn Văn Trường** | Auth, hồ sơ, Material, Listing, ảnh bìa, QR tài liệu, khả dụng; kiến trúc, Shared Models, Mock fixture & repository skeleton, tích hợp | Không tự hoàn tất Transaction/hủy nghĩa vụ mượn chỉ bằng sửa status Material. |
| **Vũ Tuấn Khanh** | Khám phá, chi tiết tài liệu, ExchangeRequest, duyệt/từ chối, hạn mượn, yêu cầu trả, danh sách yêu cầu theo thời gian | Không tự xác nhận bàn giao hoặc đặt Transaction thành COMPLETED. |
| **Vũ Hải Đăng** | DeliveryTask, ứng tuyển giao hộ, GPS/điểm hẹn/chỉ đường, quét QR, ảnh, Handover, ảnh offline chờ upload | Không tự chuyển chủ sở hữu hoặc xác nhận tiền thay người bán. |
| **Lý Đình Sơn** | Transaction workflow, QR chuyển khoản/thanh toán thủ công, lịch sử, Issue, thông báo và điều kiện hoàn tất | Không tự sửa ảnh bàn giao, quyền giữ sách hoặc duyệt yêu cầu vượt qua kiểm tra của module khác. |

**Điểm tích hợp quan trọng:** Khanh là owner thao tác **duyệt**, Đăng là owner thao tác **bàn giao**, Sơn là owner **quy tắc hoàn tất giao dịch**, Trường là owner **mô hình bản sách/khả dụng**. Khi một thao tác thay đổi nhiều đối tượng, server cập nhật trong một transaction/RPC; không để mỗi màn hình tự sửa bảng tương ứng.

## 12. Những tình huống kiểm thử nghiệp vụ tối thiểu

| ID | Tình huống | Kết quả phải quan sát được |
|---|---|---|
| TC-01 | Hai quyển cùng tên/ISBN | Hai Material ID và QR khác nhau. |
| TC-02 | Ba người gửi yêu cầu; A duyệt người thứ hai | Thứ tự gửi vẫn hiển thị; chỉ người thứ hai ACCEPTED, hai người khác REJECTED. |
| TC-03 | Hai thao tác duyệt đồng thời | Chỉ một Transaction được tạo. |
| TC-04 | B nhận sách mượn muộn | Thời gian mượn tính từ xác nhận nhận thành công. |
| TC-05 | Bàn giao thiếu ảnh | Không cho gửi/hoàn tất Handover. |
| TC-06 | Không có QR dán hoặc camera không đọc được mã | Cho đối chiếu QR lượt giao hoặc thủ công có lý do; vẫn phải có ảnh và xác nhận bên nhận. |
| TC-17 | Đã quét được QR nhưng mã không khớp | Không được xác nhận bàn giao, không cho dùng thủ công để bỏ qua mã sai; người dùng phải đối chiếu lại. |
| TC-18 | Listing PUBLISHED nhưng Material RESERVED | Vẫn xuất hiện trong tìm kiếm với nhãn **Đã được đặt**, khóa nút gửi yêu cầu; server cũng từ chối yêu cầu mới. |
| TC-19 | Listing đã ARCHIVED | Không xuất hiện trong danh sách khám phá thông thường. |
| TC-07 | C đã nhận sách, B chưa xác nhận | Holder được ghi nhận vẫn là C; trạng thái bàn giao đang chờ. |
| TC-08 | C giao thất bại | Có Issue; holder vẫn là C; không tự giải phóng Material. |
| TC-09 | Mất Internet khi chụp/upload ảnh | Có bản nháp local; server chưa coi đã giao. |
| TC-10 | B đã nhận sách SELL nhưng A chưa xác nhận tiền | Holder B; owner A; giao dịch chưa hoàn tất. |
| TC-11 | A đã xác nhận tiền nhưng B chưa nhận | Owner A; chưa hoàn tất. |
| TC-12 | B đã nhận SELL và A đã xác nhận tiền | Chuyển owner B đúng một lần. |
| TC-13 | B trả sách qua người giao hộ | Có hai lượt bàn giao trả riêng với ảnh; hoàn tất khi A nhận lại. |
| TC-14 | Không cấp quyền GPS | Có điểm hẹn thủ công và vẫn làm được giao nhận. |
| TC-15 | Gửi lại/xác nhận lại Handover | Không nhân đôi sự kiện hoặc chuyển holder lần thứ hai. |
| TC-16 | Sinh viên không liên quan đọc ảnh private | Server từ chối. |

## 13. Vấn đề còn mở – cần chốt trước khi khóa Contracts

> **Không để AI tự biến các phương án dưới đây thành tính năng bắt buộc.** Nhóm trưởng chốt cùng các thành viên, sau đó cập nhật trạng thái trong tài liệu và PR.

| ID | Câu hỏi cần trả lời | Mặc định đề xuất |
|---|---|---|
| OPEN-01 | Sau trả sách thành công, có tự mở lại bài đăng cũ không? | **Không**; chủ sách tạo Listing mới. |
| OPEN-02 | B đề xuất số ngày mượn hay chọn ngày trả cụ thể? Có giới hạn tối thiểu/tối đa? | B đề xuất số ngày; A duyệt/từ chối; giới hạn ngày sẽ thống nhất. |
| OPEN-03 | Nếu B không xác nhận lượt giao trong thời gian dài, sau bao lâu cho phép mở Issue? | Có nút báo sự cố; không tự CONFIRMED. |
| OPEN-04 | Hủy giao dịch sau khi duyệt: những điều kiện nào được phép hủy đơn giản? | Chỉ khi chưa gửi ảnh bàn giao/chưa có xác nhận tiền. |
| OPEN-05 | Vị trí của người yêu cầu trên danh sách A duyệt: chỉ khu vực hay tọa độ cụ thể? | Khu vực tự khai báo; không dùng GPS tự động xếp hạng. |
| OPEN-06 | QR thanh toán hiển thị trước hay sau khi A duyệt? | Sau khi A chấp thuận. |
| OPEN-07 | Thời gian/ngày mượn: ngày cuối tính theo múi giờ nào, khi nào quá hạn? | Ngày lịch Việt Nam; quá hạn sau hết ngày. |
| OPEN-08 | Với tranh chấp kéo dài, ai được phép đóng Issue? Có cần Admin ở MVP? | Các bên xác nhận khắc phục; escalated giữ chờ, chưa xây Admin đầy đủ. |
| OPEN-09 | Người giao hộ ứng tuyển: điều kiện tài khoản và quyền từ chối/hủy trước khi nhận sách? | Sinh viên đăng nhập, người tạo duyệt; được rút trước PICKED_UP. |
| OPEN-10 | Vị trí giao nhận: chọn điểm trên bản đồ hay chỉ nhập mô tả/mở Google Maps? | Mô tả bắt buộc; GPS/chọn điểm tùy chọn; mở ứng dụng bản đồ dẫn đường. |

## 14. Quy trình kiểm soát thay đổi tài liệu

1. Thành viên phát hiện điểm chưa rõ → mở GitHub Issue hoặc bình luận trong PR, dẫn mã `BR-xx`/`OPEN-xx`.
2. Nêu tình huống thực tế, tác động đến UI / database / tests và phương án xử lý.
3. Nhóm thống nhất trước khi sửa **Shared Models, enums, Repository Interfaces, RPC**.
4. Người chịu trách nhiệm tạo PR sửa tài liệu này cùng tài liệu/kiểm thử chịu ảnh hưởng.
5. Khi merge, cập nhật phiên bản và thông báo cả bốn thành viên, kể cả AI coding assistants phải dùng phiên bản mới nhất.

**Tài liệu đọc cùng:** `QUY_TRINH_HOAT_DONG.md` (**đã có, v1.2**) và `QUY_TRINH_GIT_NHOM.md` (**đã soạn, chờ PR**). Tài liệu dự kiến chưa khóa/tạo gồm `TRANG_THAI_NGHIEP_VU.md`, `MO_HINH_DU_LIEU.md`, `HOP_DONG_LAP_TRINH.md`.

**Lịch sử:** v1.2 bổ sung BR-49 (hiển thị tài liệu được giữ chỗ) và BR-50 (QR sai không được bỏ qua), giữ nguyên ID BR cũ để tránh phá liên kết của nhóm và AI.
