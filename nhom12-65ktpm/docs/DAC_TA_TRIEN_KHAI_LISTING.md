# Đặc tả triển khai Listing

Tài liệu này mô tả triển khai và kiểm thử, không thay thế nguồn quy tắc [SS-BR §3.1.2](QUY_TAC_NGHIEP_VU.md#312-quy-tắc-listing). Chữ ký DTO/RPC và mã lỗi nằm trong [CONTRACTS §15](CONTRACTS.md#15-listing-ngày-3). Trạng thái tích hợp được xác nhận qua review PR; nội dung trong tài liệu không thay cho xác nhận của thành viên phụ trách module.

## 1. Luồng UI

- `/publish`: quản lý tin, nháp local, tìm kiếm và bảng chọn trạng thái; CTA “Đăng tin mới”.
- `/listings/select-material`: màn con có header/Back, chọn Material và thêm Material. Hiển thị tiếp tục DRAFT/quản lý PUBLISHED/HIDDEN thay vì tạo tin trùng.
- `/listings/new`: tạo/sửa/quản lý theo dữ liệu server. Lưu server cho HIDDEN không đổi về DRAFT nên SELL vẫn bắt buộc giá. Lưu local được giữ nội dung chưa hoàn chỉnh, không phải ACK.
- `/listings/:listingId`: projection công khai qua `listingDetailsProvider`; Khanh hoàn thiện SCR-06/Request trên contract này. Null/error có trạng thái riêng; không đọc `getMyMaterial` hoặc fixture từ UI.
- Màn con ngoài Shell có Back; giữ bộ lọc/từ khóa/vị trí danh sách. Sau công bố, đóng form/bước chọn rồi mở chi tiết. Thêm/sửa Material trả kết quả về đúng màn nguồn.

## 2. Command, khóa và retry

- Listing khóa Material rồi Listing, kiểm tra owner/holder, revision, trạng thái và đầu vào trước ghi. DRAFT/HIDDEN cũng chiếm suất hiện hành; unique index bảo vệ cạnh tranh.
- Command Request của Khanh cần khóa Material trước Request, kiểm tra PUBLISHED/khả dụng, chuyển Request thành ACCEPTED rồi tạo Transaction trong cùng transaction DB. Khóa lại cùng Material trong trigger là hợp lệ.
- Guard Request áp dụng dưới role authenticated, kể cả RPC SECURITY DEFINER. Luồng bảo trì không dùng để chứng minh nghiệp vụ JWT đã đạt.
- `save_listing` ghi domain và receipt nguyên tử. Retry giữ payload/revisions/key; mất ACK tra receipt trước. Đổi tài khoản loại kết quả của phiên cũ.
- Gateway giữ mã nghiệp vụ đã biết, phân biệt CONFLICT/BACKEND_UNAVAILABLE/UNEXPECTED_ERROR. Lệnh chưa rõ ACK vẫn TIMEOUT_UNKNOWN. Ma trận dùng chung và trạng thái review tại CONTRACTS §15.2.

## 3. Snapshot và điểm nối Transaction

- Snapshot công bố version 1 gồm Material/Listing revisions, nội dung công khai, người đăng an toàn và ID ảnh theo thứ tự; không chứa URL ký, QR hoặc thông tin riêng tư.
- Namespace `terms_snapshot.listing` do trigger Listing lấy từ server; dữ liệu caller tại khóa này bị thay bằng snapshot công bố. Các khóa ngoài `listing` của Transaction/Issue được giữ. Đây là contract cần Sơn review trước merge.
- Trigger chỉ bổ sung khi Listing có snapshot; không tự sửa Transaction lịch sử. Tính hợp lệ của Request/giá/số ngày và Event/receipt khi duyệt vẫn do RPC Request quản lý.
- RPC hủy/archive của Sơn giữ nguyên ID và nội dung snapshot; cập nhật Listing làm tăng revision/updated_at. Các màn đang giữ revision cũ phải tải lại khi mutation báo CONFLICT.
- Ảnh lịch sử giữ tham chiếu độc lập gallery; quyền A/B của Transaction tách khỏi quyền ảnh PUBLISHED. URL thật tối đa 300 giây.

## 4. Chuyển đổi dữ liệu và kiểm chứng

- Giữ nguyên migration đã triển khai. Migration `20261126000500_listing_review_contracts.sql` sửa validation và thêm báo cáo private chỉ đọc; chạy kiểm thử local trước khi triển khai chung.
- `supabase/audits/listing_snapshots.sql` thống kê theo trạng thái, snapshot và lý do SKIPPED/ELIGIBLE. Báo cáo không sửa dữ liệu, không mở quyền cho mobile.
- Tin legacy bị bỏ qua khi sai chủ, thiếu/thừa ảnh, registry chưa gắn, thiếu object/sai metadata hoặc có tham chiếu dang dở. Chủ tin sửa điều kiện trước; quản trị xem xét backfill. Không bỏ điều kiện snapshot của query Khám phá.
- Số liệu cloud ngày 26/11/2026 lúc 22:30 +07:00: 176 Listing = 136 PUBLISHED + 4 HIDDEN + 4 DRAFT + 32 ARCHIVED. Cả 136 PUBLISHED và 4 HIDDEN có snapshot; PUBLISHED thiếu snapshot = 0. Đây là số liệu tại thời điểm đọc, không bảo đảm dữ liệu tương lai luôn hợp lệ.
- Test JWT local dùng harness chỉ cài tạm trên local và chỉ chấp nhận account fixture. Harness kiểm tra điểm giao trigger, không thay thế RPC Request sản phẩm của Khanh. Kết quả phải phân biệt kiểm thử harness và kiểm thử module hoàn chỉnh.

## 5. Ma trận nghiệm thu

Các mã N3-AC giữ liên tục với đặc tả trước. Bảng là kịch bản, không tự đánh dấu toàn bộ đã đạt; kết quả chạy và phụ thuộc được ghi riêng trong CONTRACTS.

| Mã | Tình huống và dữ liệu biên | Kết quả mong đợi |
|---|---|---|
| N3-AC01 | Ba Material đủ điều kiện, mỗi bản có ít nhất 1 ảnh; A tạo riêng BORROW, DONATE và SELL | Công bố được; mỗi Listing đúng một offer; chỉ SELL có giá; B đọc qua repository thật |
| N3-AC02 | Material có 0 ảnh; DRAFT SELL chưa nhập giá | Lưu DRAFT theo N3-D01; công bố bị chặn cả app lẫn server |
| N3-AC03 | Chỉ có ảnh local, PENDING, VERIFIED chưa gắn; ảnh của Material khác; ảnh bị thiếu object | Không công bố; không dùng URL tùy ý để vượt chặn |
| N3-AC04 | 1/5 ảnh hợp lệ; 6 ảnh hoặc ID ảnh trùng trong luồng Material | 1 và 5 được dùng; vượt/trùng bị chặn tại nơi lưu Material; publish kiểm tra lại gallery |
| N3-AC05 | SELL giá null, 0, âm, lẻ, kiểu string/bool, dạng mũ, quá bigint; biên 1 và bigint tối đa | Sai bị chặn; biên hợp lệ được giữ nguyên, không overflow/làm tròn. Null chỉ được ở DRAFT SELL theo N3-D01 |
| N3-AC06 | Đổi SELL sang DONATE/BORROW và gửi payload còn giá | UI bỏ giá; RPC từ chối payload sai thay vì lưu giá ngầm |
| N3-AC07 | Offer null/chuỗi lạ/nhiều offer, tự gửi owner/holder/status/snapshot | INVALID_INPUT; chưa chọn offer chỉ lưu local, không tự mặc định |
| N3-AC08 | Mô tả rỗng/2.000/2.001 ký tự; khu vực rỗng/200/201; control; tiếng Việt/emoji | Trim/rỗng thành null; đúng biên được lưu, vượt bị chặn; app/server đếm và lọc thống nhất |
| N3-AC09 | Có DRAFT, HIDDEN hoặc PUBLISHED rồi tạo tin khác cho cùng M1, kể cả khác offer | Chặn cả ba; mở tin hiện có. Ẩn không mở suất mới |
| N3-AC10 | M1/M2 cùng tên và ISBN, khác Material ID | Mỗi bản có Listing hiện hành riêng; không báo trùng theo tên/ISBN |
| N3-AC11 | B gọi trực tiếp lệnh sửa/công bố/ẩn tin A; không session; holder C không là owner | Chặn server, không rò rỉ dữ liệu; UI guard không phải lớp bảo vệ duy nhất |
| N3-AC12 | Sửa DRAFT rồi mở lại app; sửa HIDDEN | Khôi phục dữ liệu đúng từ server khi đã ACK; không tự công bố HIDDEN |
| N3-AC13 | Tin PUBLISHED không giao dịch; bấm sửa | Hướng dẫn ẩn trước. Khi HIDDEN không PENDING/active mới sửa được |
| N3-AC14 | Ẩn tin còn hai Request PENDING | Request giữ nguyên; tạo/approve mới bị chặn; A từ chối và B rút vẫn hoạt động theo quyền |
| N3-AC15 | Hiện tin HIDDEN còn PENDING; thử đổi giá/mô tả đồng thời | Chỉ hiện nguyên nội dung; sửa bị chặn, không thay điều kiện B đã yêu cầu |
| N3-AC16 | Duyệt Request làm Material RESERVED, Listing vẫn PUBLISHED | B/người khác vẫn thấy tin và ảnh với “Đã được đặt”, Request disabled và RPC từ chối |
| N3-AC17 | Tin có SELL AWAITING_PAYMENT hoặc BORROWING, holder ở B/C | Không sửa/tạo tin mới; owner được ẩn/hiện nguyên tin theo N3-D04; holder/Transaction không đổi |
| N3-AC18 | A sửa Material khi tin ẩn, hết PENDING/active rồi hiện lại | Kiểm tra revisions và ảnh mới, chụp snapshot từ bản A xác nhận; không âm thầm lấy dữ liệu cũ |
| N3-AC19 | Hai thiết bị tạo/sửa; sửa Material hoặc gỡ ảnh đồng thời công bố | Kết quả đúng mục 2; chỉ một tin hiện hành, không mất cập nhật, không PUBLISHED rỗng ảnh |
| N3-AC20 | Ẩn đua với tạo Request/approve; hiện đua với archive | Kết quả theo thứ tự commit, không Request được duyệt trên tin ẩn, không hồi sinh ARCHIVED |
| N3-AC21 | Bấm đúp, retry sau timeout cùng key; cùng key khác payload | Một receipt/tác động; payload khác bị CONFLICT; không tạo ID mới |
| N3-AC22 | Công bố đã commit nhưng mạng đứt; ACK cũ về sau khi tin đã ẩn | Tra được kết quả và trạng thái mới nhất; không báo công bố lần hai hoặc tự hiện tin |
| N3-AC23 | Offline, khởi động lại app, đổi A sang B khi form/lệnh đang mở | Chỉ nháp local có nhãn; không lộ nháp A, không phát lại lệnh dưới B; kiểm tra revision khi khôi phục |
| N3-AC24 | B xem ảnh PUBLISHED/RESERVED; thử ảnh DRAFT/HIDDEN, upload tạm, QR/evidence/ngân hàng | Chỉ đúng gallery snapshot được đọc; không ký URL theo path tùy ý, không lộ dữ liệu riêng tư |
| N3-AC25 | Ẩn tin rồi mở deep link/refresh ảnh; URL đã cấp chưa/quá 5 phút | Không đọc DTO/cấp URL mới qua Discovery; URL cũ có thể còn hạn như mục 3, không cam kết thu hồi tức thì |
| N3-AC26 | BORROW hoàn tất/hủy hợp lệ; A muốn cho mượn lại | Tin cũ ARCHIVED, chỉ đọc; tạo Listing ID mới cho cùng Material/QR, không tự công bố |
| N3-AC27 | DONATE/SELL hoàn tất chuyển A → B | A không sửa Material/tin hiện hành của B; B tạo tin mới cho cùng Material, dùng được ảnh đã gắn dù uploader=A; lịch sử A giữ nguyên |
| N3-AC28 | Xóa ảnh khỏi gallery sau archive, đọc lại snapshot Transaction có quyền | File/tham chiếu lịch sử vẫn dùng được; không cấp lại quyền công khai cho tin đã archive |
| N3-AC29 | Query Listing backend lỗi; tải SCR-06/ảnh lỗi sau ACK | Có lỗi/thử lại đúng phạm vi; không fallback mock, không tạo lại tin, không báo rollback giả |
| N3-AC30 | Gửi Request với tư cách owner, viewer đã có PENDING hoặc viewer khác chưa có | DTO khóa đúng theo viewer; RPC kiểm tra lại; PENDING người khác không khóa yêu cầu mới |
