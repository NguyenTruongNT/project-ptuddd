# StudyShare – Flutter Android

Ứng dụng StudyShare của nhóm 12, lớp 65KTPM. Mã nguồn Flutter nằm trong `nhom12-65ktpm/src/` theo README giảng viên.

## Chạy nhanh (giao diện + dữ liệu mock)

```powershell
cd nhom12-65ktpm\src
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d emulator-5554
```

Nếu mã thiết bị khác `emulator-5554`, lấy mã chính xác bằng `flutter devices` rồi thay thế. Không cần Supabase Cloud để xem giao diện mock.

## Chạy với Supabase

Đọc **`../docs/SHARED_ENV_SETUP.md`** trước khi cấu hình. Ứng dụng đọc `SUPABASE_URL` và `SUPABASE_PUBLISHABLE_KEY` từ `--dart-define`. Chỉ dùng khóa công khai của client, không đưa `service_role`, secret key, mật khẩu hay `.env` vào Git.

## Kiểm tra một lần

Tại thư mục gốc repository:

```powershell
& .\nhom12-65ktpm\src\tool\check_shared.ps1
```

Để kiểm thử thêm database local, cần khởi động Docker Desktop và Supabase local rồi dùng tùy chọn `-Database` (xem tài liệu bên trên).

## Phạm vi hiện tại

- Có 5 tab, 26 route, màn placeholder, theme/l10n, mock repositories **chỉ đọc**, Supabase foundation và bộ test nền tảng.
- **Chưa có** UI và RPC nghiệp vụ hoàn chỉnh cho Auth, Material/Listing, ExchangeRequest, giao nhận, thanh toán, Issue hay Notification.
- Không suy diễn dữ liệu mock là giao dịch đã được xác nhận; quyền và state transition phải được kiểm tra tại server.

Phân công module, quy trình commit và checklist bàn giao: **`../docs/SHARED_HANDOFF.md`** và **`../docs/QUY_TRINH_GIT_NHOM.md`**.
