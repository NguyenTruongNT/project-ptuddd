# QR Material và Trang chủ — bàn giao ngày 4

Tài liệu triển khai của phần Trường, dựa trên `QUY_TAC_NGHIEP_VU.md`,
`CONTRACTS.md` và các state machine hiện có. Không thay thế nguồn nghiệp vụ
chung hoặc đại diện cho xác nhận review của Đăng, Sơn, Khanh.

## 1. QR gắn với bản vật lý

- Một Material có một credential. Hai bản cùng tên/ISBN vẫn khác ID và QR.
- `ensure_material_qr(p_material_id, p_idempotency_key)` phát hành khi xem lần đầu;
  Material chưa có ảnh hoặc Listing vẫn được cấp mã.
- Chỉ **owner hiện tại** lấy được QR. Đang có Transaction hoặc holder khác owner
  không tự làm mất quyền này. Người giao hộ không được gọi RPC thay owner.
- Tái đăng tạo Listing mới, giữ Material ID/QR. Chuyển owner sau SELL/DONATE
  cũng giữ QR; việc chuyển owner vẫn thuộc workflow ACK của Handover.
- Không có nút xoay mã hoặc hạn hết tự động cho QR đã in trên sách.

Payload phiên bản 1: `studyshare:material:1:<material_uuid>:<hmac_sha256_hex>`.
HMAC gồm loại, phiên bản và ID, dùng khóa 32 byte được sinh trong database.
`studyshare_private.material_qr_signing_keys` không cấp SELECT/EXECUTE lấy mã
cho app. Credential chỉ lưu SHA-256 của toàn payload và format version.
Không đưa payload/khóa vào ListingDetails, Home, URL, log, nháp hoặc preferences.

Đây là dấu nhận diện có thể sao chép từ bản in, không chứng minh quyền sở hữu
hoặc tự xác nhận đã giao sách. Xác nhận bàn giao vẫn cần đúng người, ảnh và ACK.

## 2. Tính ổn định, retry và đầu vào

| Trường hợp | Xử lý |
|---|---|
| Chưa đăng nhập | AUTH_REQUIRED; anon không có EXECUTE |
| Material ID không đúng UUID | INVALID_INPUT; không gọi HTTP từ repository |
| Key trống, quá 128 ký tự, có ký tự điều khiển/khoảng trắng đầu cuối | INVALID_INPUT |
| Không tồn tại hoặc không còn là owner | FORBIDDEN; không tiết lộ sự tồn tại |
| Cùng actor/key, cùng Material | Cùng command receipt và QR |
| Cùng actor/key, Material khác | CONFLICT |
| Nhiều request/key cạnh tranh trên một Material | Khóa dòng Material, chỉ một credential |
| Mất ACK/DTO ACK không đọc được | TIMEOUT_UNKNOWN; giữ key, thử lại cùng ý định |
| Chủ cũ replay receipt sau chuyển owner | FORBIDDEN; quyền được kiểm tra trước receipt |
| Credential cũ format 0 hoặc không phục hồi được khóa/hash | BACKEND_UNAVAILABLE; không tự ghi đè/đổi mã |
| Thiếu migration/RPC khi app dùng backend thật | BACKEND_UNAVAILABLE; không thay bằng QR demo |

Receipt chỉ giữ command ID, revision và Material ID. RPC tái dựng payload sau
khi kiểm tra owner hiện tại; không lưu raw QR trong `result_json`.
Phát hành QR không tăng Material revision, không tạo TransactionEvent.

Khóa ký phải được sao lưu cùng dữ liệu private; mất khóa thì phục hồi đúng bản
sao lưu, không sinh khóa mới để làm lỗi biến mất. Trước triển khai cần chạy
`src/supabase/audits/material_qr.sql`. Credential format 0 cần quy trình phục hồi
riêng sau khi đối chiếu dữ liệu; thay đổi này không có backfill xoay mã tự động.

## 3. Giao diện và vòng đời

- SCR-09 có khối “QR tài liệu”, độc lập với quyền sửa/đăng Listing.
- Chỉ gọi server khi bấm xem. Material từ cache offline vô hiệu hóa nút xem.
- QR có nền trắng, nét đen và khoảng trống quanh mã; kèm tên/ID Material.
- “Mở QR lớn” tới `/materials/:materialId/qr`, không thêm mã SCR mới.
- Trang QR trực tiếp có Back về Material, kể cả khi lỗi/không có quyền.
- Ra nền hoặc đổi phiên: xóa bản QR trong state; kết quả HTTP cũ trả muộn bị bỏ.
  Mở lại kiểm tra server; không đọc QR từ SQLite/preferences.
- Demo dùng namespace `studyshare:demo:...` và nhãn mô phỏng, không phải token thật.
- `/materials` là màn con ngoài shell, có header Back; Home/Cá nhân push vào
  thì Back về nguồn. Mở trực tiếp thì Back về Home. Không lặp bottom navigation.

## 4. Contract bàn giao cho Đăng

Giữ chữ ký `verify_material_code` và `HandoverFeatureRepository` hiện có.
Giver của đúng chặng gửi **nguyên payload đã đọc**, không gửi ISBN, Material UUID
hoặc Handover UUID thay mã. Không cần quyền `getMyMaterial` của owner để đối chiếu.

| Luồng | Kết quả |
|---|---|
| QR đúng credential Material của Transaction | Ghi verification QR, Event và receipt |
| QR sai/UUID thuần/QR sách khác | QR_MISMATCH, lưu `handovers.qr_mismatch_at`, xóa xác minh cũ |
| Đổi key/mở lại màn rồi fallback sau mismatch | Vẫn QR_MISMATCH |
| Replay receipt thành công cũ sau mismatch mới | Vẫn bị chặn; không dùng ACK cũ gỡ cờ |
| Quét lại đúng mã bằng ý định mới | Gỡ mismatch; có thể tiếp tục nộp ảnh |
| Chưa từng mismatch, mã hỏng không đọc được | FALLBACK cần lý do 1–1000 ký tự, mã quét rỗng |
| SELL chưa có xác nhận tiền của A | PAYMENT_NOT_CONFIRMED |
| Đúng QR nhưng chưa nộp ảnh | Chưa đủ điều kiện chuyển sang chờ nhận |

`get_handover_details` thêm boolean `qr_mismatch_blocked`; không trả raw token.
Trigger chặn chuyển sang chờ nhận/xác nhận hoặc gắn verification khi còn mismatch.
QR đúng không đổi holder/owner/Transaction. `create_handover` vẫn có thể chuyển
Transaction sang HANDOVER_IN_PROGRESS theo workflow riêng của Đăng.

Scanner giữ random key khi retry cùng mã, không ghép token vào key/success text.
Chỉ demo hiện chip fixture. Camera đọc QR thực tế trong SCR-19 vẫn là phần tích
hợp của Đăng; thay đổi này cung cấp mã thật, verifier thật và ô nhập payload để
đối chiếu. Không xem icon khung camera là bằng chứng đã có camera scanner.

Sửa kèm policy Storage: phép kiểm tra ảnh handover đi qua hàm SECURITY DEFINER
trả boolean theo JWT. Không cấp SELECT các bảng evidence/handover/Transaction
cho app để chữa lỗi. Giữ quyền đọc thư mục upload của chính mình và ảnh gắn với
chặng/giao dịch liên quan; ảnh Material/Listing không bị lỗi quyền chéo bucket.

## 5. Home SCR-04

| Khối | Nguồn và hành vi |
|---|---|
| Tên chào | Profile của phiên; không có tên thì lời chào chung |
| Tổng quan | `get_home_overview()`, COUNT toàn bộ theo auth.uid(), không lấy độ dài trang |
| Material | owner hiện tại; holder khác không làm đổi phạm vi |
| Listing | created_by và owner hiện tại đều là actor; PUBLISHED/DRAFT/HIDDEN đếm riêng |
| Transaction active | Actor là A/B, trạng thái khác COMPLETED/CANCELLED |
| Tiếp tục nháp | `searchMine(status: 'DRAFT', limit: 3)`; nháp server, không ghép nháp thiết bị |
| Tin mới | `searchPage(limit: 6)`; thứ tự/ảnh/quyền theo repository công khai, vẫn gồm RESERVED |
| Lối tắt | Thêm Material, Material của tôi, tab quản lý tin; tổng giao dịch mở tab Transaction |

Ba khối tải/lỗi/rỗng/retry riêng. Lỗi một nguồn không làm mất các khối khác hoặc
biến lỗi thành số 0. Retry chủ động từng khối; kéo tải lại/nút refresh tải cả ba.
Quay lại từ màn con, chọn lại tab Home hoặc app resume sẽ tải mới dữ liệu.
Form thêm từ Home trả Material sau ACK rồi đóng; Home mở chi tiết, Back không
đi qua form vừa lưu. Card công khai mở SCR-06 bằng Listing ID.

Không thêm số unread giả hay tìm kiếm giả khi module liên quan chưa tích hợp.
Nháp trên thiết bị tiếp tục do luồng Listing quản lý. URL ảnh hết hạn cần tải
lại read model theo quyền hiện thời; lỗi ảnh có placeholder.

## 6. Điểm phối hợp và nghiệm thu

- **Đăng:** camera scan gửi payload theo §4; kiểm tra camera thật trên Android,
  chuỗi A→C→B/hoàn trả, ảnh và receiver ACK trên môi trường chung.
- **Khanh:** SCR-06 tiếp tục dùng ListingDetails; Home không dùng Material owner
  query để dựng chi tiết công khai. Request/Khám phá sản phẩm cần nghiệm thu khi merge.
- **Sơn:** Home dùng read RPC đếm giao dịch A/B. Không thay mapping gateway chung,
  không triển khai backend Notification hoặc lấy code từ PR #30 chưa merge.

Migration bổ sung: `20261127000200_material_qr_home.sql`, chạy sau migration
Delivery/Handover `20261127000100`. Giữ nguyên lịch sử migration đã chia sẻ.
**Đã triển khai Cloud development ngày 27/11/2026** theo yêu cầu triển khai của
nhóm trưởng, gồm 3 migration còn thiếu `20261126000500`, `20261127000100`, `20261127000200`.
Ứng dụng dùng cấu hình mặc định đã gọi được RPC QR/Home Cloud. Bàn giao bằng 4 commit trên nhánh `feature/nhom12/truong-qr-home`; merge sau review.

Kiểm thử và lệnh chạy được ghi tại `CONTRACTS.md` §16 và `src/README.md`.
Kết quả tự động không thay thế review contract chung và nghiệm thu camera/Cloud.


## 7. Kết quả kiểm tra local ngày 27/11/2026

- `flutter analyze --no-pub`: không có issue.
- `flutter test --no-pub --reporter expanded`: 328 test đạt, 7 test tích hợp opt-in
  bỏ qua trong lệnh chung. Test QR/Home opt-in đã chạy riêng bằng script local và đạt.
- pgTAP: 223/223, 9 file; `db lint --local --level warning`: không có lỗi/cảnh báo schema.
- JWT thật: 8 lệnh phát hành cạnh tranh cùng QR/1 credential, retry mất ACK,
  A/B phân quyền, owner khác holder, chuyển owner giữ QR và chặn receipt chủ cũ,
  UUID thô/mismatch/fallback bị chặn, quét đúng không đổi holder và vẫn cần ảnh,
  tổng Home vượt 20 bản ghi và logout. Sau test còn 0 account fixture `n4-a/b`.
- Widget/router: retry giữ key; dữ liệu cache không mở QR; ra nền/đổi phiên loại QR
  và HTTP muộn; QR trực tiếp có Back; Home lỗi từng khối; 360px/chữ lớn;
  Home→Material→QR và Home→Material→công bố Listing→chi tiết, không lặp form đã lưu.
- Build web và APK debug thành công. Chưa có thiết bị Android kết nối để thử camera trong đợt này.
- Kết quả trên ghi nhận bước local trước triển khai; kết quả Cloud bổ sung tại §8.


## 8. Triển khai và kiểm thử Cloud ngày 27/11/2026

Đích: `studyshare-nhom12-dev` (`dacrjfgleursgtnzeoix`), cùng project của cấu hình
ứng dụng. Triển khai Cloud và bàn giao Git là hai bước riêng; thay đổi Git cần PR và review trước khi merge.

- Đã áp dụng đúng 3 migration pending: `20261126000500_listing_review_contracts.sql`,
  `20261127000100_delivery_handover_rpc.sql`, `20261127000200_material_qr_home.sql`.
  Không chạy seed/custom roles, không cập nhật Vault/Auth config, không reset dữ liệu.
- Lịch sử Cloud/local khớp đủ 14 phiên bản; dry-run cuối không còn migration pending.
  DB lint Cloud không có lỗi/cảnh báo schema.
- Kiểm kê lúc **19:03:29 +07:00**: 222 Material, 176 Listing, 152 Transaction,
  148 Handover, 238 receipt, 363 Storage object. Số lượng và fingerprint cả 7 nhóm
  (gồm credential QR) giữ nguyên sau triển khai và sau dọn toàn bộ fixture.
- Trước triển khai có 0 credential QR; không có mã cũ bị đổi/ghi đè. Khóa ký phiên bản 1
  được sinh trực tiếp trong DB private, RLS bật; không xuất khóa ra log/repository.
- JWT Cloud qua repository thật đạt: 8 yêu cầu phát hành đồng thời cùng QR/1 credential,
  mất ACK rồi retry, A/B và chủ cũ bị chặn, owner khác holder, chuyển owner giữ QR,
  UUID thuần/mismatch/fallback bị chặn, quét lại đúng mã, chưa nộp ảnh bị chặn,
  tổng Home đủ 26 Material vượt trang 20; đọc được 6 tin công khai/URL ảnh và nháp riêng;
  logout không dùng lại repository của phiên cũ. Script local cũng chạy lại đạt.
- REST không đăng nhập bị chặn HTTP 401 ở cả RPC phát hành QR và tổng quan Home.
  App không có SELECT credential/khóa ký, không được execute helper sinh token;
  trigger mismatch bật. Sau test còn 0 account QA và 0 credential fixture;
  không có PUBLISHED thiếu snapshot.
- Công cụ QA Cloud dùng CLI quản trị cho setup/kiểm kê/cleanup vì service_role không
  có quyền bảng workflow/credential. Không cấp thêm quyền để làm test chạy.
  UUID/hậu tố fixture được kiểm tra trước SQL; file khôi phục chỉ có ID, không có secret.
  Không tạo RPC test trên Cloud, không dùng bản ghi demo có sẵn để thử lệnh ghi.
- `flutter test --no-pub`: 328 test đạt, 7 opt-in bỏ qua; test JWT Cloud/local chạy riêng đạt.
  `flutter analyze --no-pub` không có issue. Product code giữ như bản đã build web/APK debug.

Chạy Cloud bằng `flutter run -d chrome` với cấu hình mặc định, hoặc Android tương ứng.
Dừng phiên app có local defines trước khi chạy lại. Script chủ động:
`tool/test_qr_home_cloud.ps1`; không tự triển khai DB khi chạy script này.
Camera đọc QR thực tế và chuỗi bàn giao đầy đủ vẫn cần phối hợp Đăng;
không diễn giải test nhập payload thành nghiệm thu camera thật. Bàn giao PR vào `integration/nhom12-65ktpm`, giữ 4 commit và chờ thành viên khác review.
