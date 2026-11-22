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
