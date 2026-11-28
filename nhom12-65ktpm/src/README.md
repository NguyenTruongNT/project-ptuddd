# StudyShare – Flutter Android

Ứng dụng StudyShare của nhóm 12, lớp 65KTPM. Mã nguồn Flutter nằm trong `nhom12-65ktpm/src/` theo README giảng viên.

## Chạy nhanh (Supabase Cloud development của nhóm)

```powershell
cd nhom12-65ktpm\src
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d emulator-5554
```

Nếu mã thiết bị khác `emulator-5554`, lấy mã chính xác bằng `flutter devices` rồi thay thế. Ứng dụng mặc định đọc `assets/config/supabase.public.json` đã có trong Git để kết nối project development của nhóm. Máy mới không cần tạo `.dart_tool/supabase.cloud.json`; `flutter clean` không xóa file cấu hình công khai này. Cần có Internet và mỗi thành viên dùng tài khoản thử nghiệm riêng.

Auth/Profile, Material/ảnh SCR-07/08/09 và Listing ngày 3 dùng Supabase thật. Cloud development đã có bốn migration Listing ngày 26/11/2026. QR Material và Home ngày 4 đã triển khai và kiểm thử Supabase Cloud development ngày 27/11/2026; camera scan QR và các module khác theo phân công tích hợp riêng. Chạy Chrome bằng `flutter run -d chrome` để kiểm tra với backend mặc định; không coi màn preview mock là dữ liệu Cloud.

## Chạy demo không kết nối Supabase

```powershell
flutter run -d emulator-5554 --dart-define=SUPABASE_ENABLED=false
```

Màn đăng nhập có nút **Xem bản demo**. Chế độ này có nhãn dữ liệu mô phỏng và không tạo phiên Supabase giả. Lỗi đọc cấu hình hoặc khởi tạo Supabase được hiển thị như lỗi Auth, không tự chuyển sang demo.

## Ghi đè cấu hình Supabase

Đọc **`../docs/SHARED_ENV_SETUP.md`** trước khi cấu hình. Để dùng Supabase local hoặc project khác, truyền đầy đủ `SUPABASE_URL` và `SUPABASE_PUBLISHABLE_KEY` bằng `--dart-define` hoặc `--dart-define-from-file`. Cặp ghi đè được ưu tiên toàn bộ, không lấy trường còn thiếu từ cấu hình development. Nếu chỉ truyền một trường hoặc URL không hợp lệ, ứng dụng báo lỗi cấu hình.

File `assets/config/supabase.public.json` chỉ chứa URL development và khóa `sb_publishable_` dành cho ứng dụng. Không đưa `service_role`, secret key, mật khẩu hay `.env` vào Git. Khóa publishable không thay thế đăng nhập, RLS hoặc kiểm tra quyền tại server.

## Kiểm tra một lần

Tại thư mục gốc repository:

```powershell
& .\nhom12-65ktpm\src\tool\check_shared.ps1
```

Để kiểm thử thêm database local, cần khởi động Docker Desktop và Supabase local rồi dùng tùy chọn `-Database` (xem tài liệu bên trên).

## Phạm vi hiện tại

- Có 5 tab, 26 route chính, theme/l10n, Supabase foundation và module Transaction mock (PR #21).
- Nhánh Auth/Profile bổ sung Splash, đăng nhập/đăng ký, xác minh email, quên/đổi mật khẩu qua PKCE deep link, auth guard, hồ sơ cá nhân và logout; lưu tùy chọn giao diện trên thiết bị.
- Material và Listing đã có repository/RPC/RLS thật; Transactions/Payment/Issues theo module của Sơn. ExchangeRequest/Handover/Notification còn điểm tích hợp theo phân công. Không lấy tài khoản A/B từ mock làm actor khi chạy thật; cache riêng tư được tái tạo khi đổi tài khoản hoặc logout. Xem [CONTRACTS §15](../docs/CONTRACTS.md#15-listing-ngày-3) để kiểm thử và bàn giao Listing.
- Không suy diễn dữ liệu mock là giao dịch đã được xác nhận; quyền và state transition phải được kiểm tra tại server.

Phân công module, quy trình commit và checklist bàn giao: **`../docs/SHARED_HANDOFF.md`** và **`../docs/QUY_TRINH_GIT_NHOM.md`**.

## Chạy và kiểm tra Auth/Profile ngày 1

1. Khởi động Docker Desktop; tại `src/`, chạy `npx supabase start`.
2. Local dùng `studyshare://auth/callback` trong `supabase/config.toml`. Nếu stack đang chạy từ trước khi sửa config, `npx supabase stop` rồi `npx supabase start` để nạp allowlist mới; không cần reset database.
3. Chạy Android với `--dart-define=SUPABASE_URL=http://10.0.2.2:54321` và `--dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key-local>`.
4. Email test ở `http://127.0.0.1:54324`. Khi mở liên kết email trên emulator, dùng `adb -s emulator-5554 reverse tcp:54321 tcp:54321` để địa chỉ localhost trong email trỏ về máy phát triển.
5. Chạy `flutter analyze`, `flutter test`, `npx supabase test db`. Test PKCE/Auth thật được tách riêng: `powershell -ExecutionPolicy Bypass -File .\tool\test_auth_local.ps1`.

Cloud cần tự cấu hình URL redirect `studyshare://auth/callback` trong Supabase Auth và SMTP phù hợp. Chỉ truyền publishable key cho app. Chính sách xác minh email theo server; Google Sign-In không nằm trong phần ngày 1.

Đăng ký/đặt mật khẩu mới yêu cầu **ít nhất 8 ký tự, có chữ hoa A–Z, chữ thường a–z, số 0–9 và ký tự đặc biệt**. Form liệt kê trực tiếp các điều kiện, báo điều kiện còn thiếu và chặn trước confirm/API; xác nhận mật khẩu phải khớp. Supabase local áp dụng cùng policy (`minimum_password_length = 8`, `password_requirements = "lower_upper_letters_digits_symbols"`) để chặn cả khi bỏ qua UI. Cấu hình Cloud phải đặt riêng cùng chính sách trước khi triển khai; sửa config local không thay đổi Cloud. `AUTH_MIN_PASSWORD_LENGTH` mặc định 8, không cho hạ dưới 8; nếu server yêu cầu dài hơn, truyền cùng giá trị qua `--dart-define`. Form đăng nhập chỉ bắt buộc nhập mật khẩu rồi để server xác thực, không chặn tài khoản cũ theo policy tạo mới.

Sau khi đổi config, restart Supabase local như bước 2; chạy kiểm thử server trực tiếp bằng `powershell -ExecutionPolicy Bypass -File .\tool\test_password_policy_local.ps1`. Test chỉ dùng localhost/khóa công khai, tạo tài khoản QA riêng rồi xóa đúng UUID của nó. Tham khảo [Supabase Password security](https://supabase.com/docs/guides/auth/password-security).

Luồng kiểm tra: đăng ký → xác minh nếu server yêu cầu → đăng nhập → Cá nhân → sửa tên → Cài đặt → đổi theme/ngôn ngữ → khởi động lại → logout. Khôi phục mật khẩu phải xuất phát từ email hợp lệ; mở đường dẫn reset trực tiếp không cấp quyền đổi mật khẩu.

## Duyệt giao diện Auth/Profile trên Chrome

Đặc tả bố cục và xác nhận: [UIUX_AUTH_PROFILE_REVIEW.md](../docs/UIUX_AUTH_PROFILE_REVIEW.md). Bản chỉnh giao diện hiện lưu bằng commit local trên nhánh Auth/Profile, chờ Trường duyệt trước khi push/cập nhật PR.

Trong `src/`, sau khi mở Docker Desktop và khởi động Supabase local:

```powershell
$s = (npx.cmd supabase status -o json 2>$null) | ConvertFrom-Json
flutter run -d chrome --dart-define=SUPABASE_URL=http://127.0.0.1:54321 "--dart-define=SUPABASE_PUBLISHABLE_KEY=$($s.PUBLISHABLE_KEY)"
```

Chrome/Windows dùng `127.0.0.1`; Android Emulator dùng `10.0.2.2`. Cần dừng và chạy lại nếu thay `--dart-define`. `web/index.html` dùng bootstrap chuẩn Flutter để có thể `flutter build web` phục vụ kiểm tra giao diện; không chứa cấu hình Cloud hoặc secret.

Kiểm tra ở 360/440 px và desktop: header mobile xanh đậm với họa tiết sách; mở bàn phím thì header gọn lại; đăng ký có confirm; Cá nhân mặc định chỉ xem, chọn **Sửa tên hiển thị** để mở form, lưu tên cần confirm. **Cài đặt chọn là áp dụng ngay và tự lưu**, không có nút Lưu/Hủy hoặc hỏi bỏ thay đổi khi Back. Nếu ghi lỗi, lựa chọn tự trở về bản lưu thành công gần nhất; toast và việc lưu vẫn hoạt động khi rời trang. Thay đổi liên tiếp gộp thông báo sau 650ms yên lặng; toast hiện góc trên phải 3,5 giây, có nút đóng.


## QR Material và Home ngày 4 (Cloud và local)

Xem [bàn giao triển khai](../docs/DAC_TA_TRIEN_KHAI_QR_HOME.md) và
[CONTRACTS §16](../docs/CONTRACTS.md#16-qr-material-và-home-ngày-4).
Từ `src/`, mở Docker/Supabase local rồi chạy:

```powershell
npx.cmd supabase@3.3.0 migration up --local --include-all
npx.cmd supabase@3.3.0 test db
./tool/test_qr_home_local.ps1
flutter analyze
flutter test --reporter expanded
```

Chạy Chrome với backend local (biến chỉ dùng trong terminal, không in đối tượng cấu hình):

```powershell
$qrLocalConfig = (npx.cmd supabase@3.3.0 status -o json 2>$null | Out-String) | ConvertFrom-Json
flutter run -d chrome --dart-define=SUPABASE_URL=http://127.0.0.1:54321 "--dart-define=SUPABASE_PUBLISHABLE_KEY=$($qrLocalConfig.PUBLISHABLE_KEY)"
```

Cloud development đã có các migration `20261126000500`, `20261127000100`,
`20261127000200`. Chạy `flutter run -d chrome` với cấu hình mặc định để dùng Cloud.
Dừng phiên app đang chạy với local defines trước khi chạy lại bằng cấu hình Cloud.
Để kiểm thử ghi Cloud bằng tài khoản QA dùng một lần: `./tool/test_qr_home_cloud.ps1`.
Script chỉ nhận đúng project development đã link, cần CLI quản trị đã đăng nhập,
và tự dọn fixture; không deploy migration. Test local tiếp tục dùng script ở trên.
Không dùng admin key trong app. Camera scan QR trên Android cần tích hợp với Đăng;
QR server/ô nhập payload và kiểm thử tự động không thay cho nghiệm thu camera thật.
