# SS-ENV – Hướng dẫn môi trường phát triển StudyShare

> Tài liệu cho **bộ khung chung**, không phải hướng dẫn hoàn thiện chức năng riêng của thành viên.
> Vị trí dự án: `nhom12-65ktpm/src/`. Nền tảng nộp: **Android**.

## 1. Chuẩn bị

1. Cài Git, Flutter SDK/Dart, Android Studio hoặc VS Code và Android SDK.
2. Mở Android Emulator hoặc kết nối điện thoại Android đã bật USB debugging.
3. Kiểm tra: `flutter doctor`, `flutter devices`.
4. Ở thư mục gốc repo, chuyển về nhánh làm việc hoặc nhánh integration đã được đồng bộ.

## 2. Chạy giao diện và mock, không cần backend

```powershell
cd nhom12-65ktpm\src
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d emulator-5554
```

- Nếu mã thiết bị thay đổi, dùng đúng ID trong `flutter devices`.
- Có thể mở tab **Cá nhân** → danh mục 26 màn hình và trang dữ liệu mock.
- Các màn hình nghiệp vụ chưa làm sẽ hiện **placeholder**.
- Không nhập tài khoản, số tài khoản hoặc chứng cứ giao nhận thật vào dữ liệu mock.

## 3. Supabase local (chỉ khi kiểm tra database)

**Cần:** Docker Desktop đang chạy, Node.js/npm, Supabase CLI gọi qua `npx supabase`.

```powershell
cd nhom12-65ktpm\src
npx supabase start
npx supabase status
npx supabase test db
npx supabase db lint
```

`npx supabase db reset` **xóa và khởi tạo lại dữ liệu local**; chỉ chạy khi chủ động muốn reset môi trường thử nghiệm và đã sao lưu dữ liệu cần thiết. Không chạy `db push`/migrate remote trong bước chốt khung.

Trên **Android Emulator mặc định**, URL backend local có thể là `http://10.0.2.2:54321`, không phải `127.0.0.1` của máy tính. Ví dụ chạy Flutter:

```powershell
$env:SUPABASE_URL = 'http://10.0.2.2:54321'
$env:SUPABASE_PUBLISHABLE_KEY = '<PUBLIC_KEY_LOCAL>'
flutter run -d emulator-5554 --dart-define="SUPABASE_URL=$env:SUPABASE_URL" --dart-define="SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY"
```

Lấy **public anon/publishable key** đúng với project local từ `npx supabase status`. Không dán `service_role`/secret key vào lệnh chạy Flutter. Giá trị có dạng `<PUBLIC_KEY_LOCAL>` là placeholder, **không thể dùng nguyên văn**.

Khi dùng điện thoại Android thật, địa chỉ `10.0.2.2` không áp dụng; phải cấu hình địa chỉ mạng/HTTPS truy cập được từ điện thoại và kiểm tra firewall.

## 4. Supabase Cloud

- Một thành viên chịu trách nhiệm tạo/quản lý project development và cấp quyền phù hợp.
- Chỉ cung cấp **Project URL** và **publishable key** cho Flutter qua `--dart-define`; bí mật quản trị chỉ dùng ở môi trường tin cậy, không đưa lên repo công khai.
- Migration chỉ được áp dụng lên cloud **sau review và kiểm thử local**; sao lưu trước thay đổi phá hủy.
- RLS/Storage đã có nền tảng, nhưng **không đồng nghĩa** các RPC giao dịch đã sẵn sàng; không mở quyền ghi trực tiếp chỉ để demo.
- Không lưu key thật vào `README.md`, file `.dart`, Issue, PR hoặc ảnh chụp màn hình.

## 5. Kiểm tra trước mỗi PR

Tại thư mục gốc repository:

```powershell
& .\nhom12-65ktpm\src\tool\check_shared.ps1
```

Kiểm tra sâu thêm khi Docker/Supabase local đang chạy:

```powershell
& .\nhom12-65ktpm\src\tool\check_shared.ps1 -Database
```

Kiểm tra build Android (không cần máy ảo đang chạy):

```powershell
& .\nhom12-65ktpm\src\tool\check_shared.ps1 -AndroidBuild
```

Script không tự reset database, không deploy cloud, không push Git và không ghi dữ liệu thật. Nếu PowerShell chặn chạy script, có thể chạy lần lượt các lệnh `flutter pub get`, `flutter analyze`, `flutter test` thủ công; không cần thay đổi thiết lập bảo mật toàn máy.

## 6. Các vấn đề dễ gặp trên Windows

- `No supported devices`: mở Android Emulator → `flutter devices` → dùng ID hiện tại.
- `assembleDebug` chạy lâu: để Gradle biên dịch; chỉ ghi là đạt khi app thực sự mở được.
- Lỗi incremental Kotlin cache: dừng Gradle, `flutter clean`, `flutter pub get`, chạy lại; bản nhóm đã có fix trên `android/gradle.properties`. Không chỉnh cấu hình Gradle thêm tùy tiện.
- Cảnh báo nâng cấp package không đồng nghĩa test thất bại; không nâng cấp đồng loạt trong PR tài liệu.

## 7. Nguyên tắc khi bàn giao

Các thành viên phát triển **feature riêng** từ `integration/nhom12-65ktpm`, dùng chung các thư mục `core/contracts`, `core/providers`, `design_system` và `app/app_routes.dart`. Nếu cần thay đổi hợp đồng chung, mở PR nhỏ và nhờ các thành viên liên quan review trước. Chi tiết trong `SHARED_HANDOFF.md`.

## 8. Ghi nhận triển khai Cloud development — 24/11/2026

Project `studyshare-nhom12-dev`, region Singapore (`ap-southeast-1`), đã được liên kết bằng Supabase CLI **3.3.0** và áp dụng hai migration nền tảng:

- `20261122000100_core_schema.sql`.
- `20261122000200_rls_and_storage.sql`.

Hai file khớp bản đã merge vào integration qua PR #18. Trước triển khai, ba file pgTAP local đạt **33/33 kiểm tra**, database lint không báo lỗi và dry-run chỉ liệt kê hai migration trên, không có seed/custom role. Triển khai dùng đích project Cloud tường minh và `--skip-vault`; không chuyển dữ liệu mock hoặc tài khoản local lên Cloud.

Kiểm tra sau triển khai:

- Lịch sử migration Cloud khớp cả hai phiên bản local.
- Có 19 bảng `public`, cả 19 đều bật RLS.
- Profile có ba policy SELECT/INSERT/UPDATE; role `authenticated` được đọc/tạo và sửa `display_name`, không được sửa `user_id` hoặc `created_at`.
- Role `authenticated` không được đọc trực tiếp `transactions`/`material_qr_credentials`, không được tự INSERT `command_receipts`.
- Hai bucket `studyshare-material-images` và `studyshare-handover-evidence` đều private, giới hạn mỗi ảnh 5 MB và MIME JPEG/PNG/WEBP. Chỉ có hai policy Storage đọc/upload ảnh tài liệu theo thư mục của chủ tài khoản; quyền minh chứng bàn giao vẫn chờ RPC.
- Thử REST với publishable key và không có phiên người dùng: truy cập `profiles`, `transactions`, `material_qr_credentials` đều bị chặn HTTP 401 / SQLSTATE `42501`.

Đây là kiểm tra cấu trúc/quyền trên Cloud, chưa phải nghiệm thu toàn bộ Auth/Profile với email thật hoặc hai phiên người dùng Cloud. Các bước còn lại: đồng bộ password policy Cloud, SMTP, callback Android/web, rồi kiểm thử đăng ký/xác minh/khôi phục, hồ sơ và phân quyền giữa hai tài khoản.

Cấu hình Flutter Cloud ở `src/.dart_tool/supabase.cloud.json`, được Git bỏ qua, với tên biến `SUPABASE_URL` và `SUPABASE_PUBLISHABLE_KEY`. Không dùng prefix `NEXT_PUBLIC_` trong Flutter. Kết quả dry-run, deploy và audit được giữ trong `src/.dart_tool/cloud-step3-*`; không chứa trong commit.

CLI 3.x mặc định nhắm local. Khi kiểm tra Cloud, cần chỉ rõ đích; ví dụ từ `src/`:

```powershell
$projectRef = '<PROJECT_REF_CUA_BAN>'
npx.cmd supabase@3.3.0 migration list "--remote=$projectRef"
npx.cmd supabase@3.3.0 db push "--remote=$projectRef" --dry-run --skip-vault
```

Hai lệnh trên chỉ kiểm tra lịch sử/xem trước; không áp dụng migration mới. Không dùng `migration repair` để che lỗi lệch lịch sử. Các lựa chọn Auth trong `supabase/config.toml` local chưa được đồng bộ lên Cloud bởi lệnh triển khai database này.
