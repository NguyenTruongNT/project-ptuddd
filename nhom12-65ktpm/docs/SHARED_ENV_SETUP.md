# SS-ENV – Hướng dẫn môi trường phát triển StudyShare

> Tài liệu cho **bộ khung chung**, không phải hướng dẫn hoàn thiện chức năng riêng của thành viên.
> Vị trí dự án: `nhom12-65ktpm/src/`. Nền tảng nộp: **Android**.

## 1. Chuẩn bị

1. Cài Git, Flutter SDK/Dart, Android Studio hoặc VS Code và Android SDK.
2. Mở Android Emulator hoặc kết nối điện thoại Android đã bật USB debugging.
3. Kiểm tra: `flutter doctor`, `flutter devices`.
4. Ở thư mục gốc repo, chuyển về nhánh làm việc hoặc nhánh integration đã được đồng bộ.

## 2. Chạy ứng dụng sau khi pull code

```powershell
cd nhom12-65ktpm\src
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d emulator-5554
```

- Nếu mã thiết bị thay đổi, dùng đúng ID trong `flutter devices`.
- Mặc định ứng dụng kết nối Supabase Cloud development bằng `src/assets/config/supabase.public.json` đã có trong Git. Không cần tạo file JSON cá nhân; cần Internet và tài khoản thử nghiệm riêng của từng thành viên.
- Auth/Profile, Material/ảnh SCR-07/08/09 và Transactions/Payment/Issues dùng Supabase thật khi đăng nhập. Listing/Request/Delivery/Handover chưa tích hợp vẫn giữ trạng thái hiện có; không coi chúng là đã nối backend chỉ vì có bảng hoặc dữ liệu.
- File cấu hình công khai nằm ngoài `.dart_tool/`, nên được giữ lại sau `flutter clean`.

Để phát triển giao diện với dữ liệu mock mà không kết nối Supabase:

```powershell
flutter run -d emulator-5554 --dart-define=SUPABASE_ENABLED=false
```

- Chọn **Xem bản demo** trên màn đăng nhập. Lỗi đọc cấu hình hoặc khởi tạo Supabase sẽ hiện trạng thái lỗi Auth, không tự chuyển sang demo.
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
- Flutter mặc định đọc **Project URL** và **publishable key** từ `src/assets/config/supabase.public.json`. Đây là cấu hình development công khai được nhóm trưởng cho phép đưa lên Git; file chỉ được chứa hai trường `SUPABASE_URL` và `SUPABASE_PUBLISHABLE_KEY`.
- Nếu dùng project khác hoặc Supabase local, truyền đủ cặp URL/key qua `--dart-define` hoặc `--dart-define-from-file`. Hai trường ghi đè được dùng cùng nhau; thiếu một trường hoặc URL không hợp lệ sẽ báo lỗi, không ghép với cấu hình development.
- File ghi đè cá nhân có thể đặt ở `src/.env.supabase.json` (đã bị Git bỏ qua), rồi chạy `flutter run -d emulator-5554 --dart-define-from-file=.env.supabase.json`. Flutter không tự đọc file này khi thiếu tham số.
- Publishable key được thiết kế để dùng trong ứng dụng phía người dùng; quyền dữ liệu vẫn phải được bảo vệ bằng Auth/RLS. Bí mật quản trị chỉ dùng ở môi trường tin cậy, không đưa vào ứng dụng hoặc repo công khai. Nguồn: [Supabase API keys](https://supabase.com/docs/guides/getting-started/api-keys).
- Migration chỉ được áp dụng lên cloud **sau review và kiểm thử local**; sao lưu trước thay đổi phá hủy.
- RPC Transactions/Payment/Issues đã có ở migration `20261125120000_transactions_payment_issues_rpc.sql`. Các workflow khác phải kiểm tra riêng; không mở quyền ghi trực tiếp chỉ để demo.
- Chỉ lưu khóa publishable development đã được duyệt trong file JSON công khai nói trên; không chép giá trị khóa vào `README.md`, file `.dart`, Issue, PR hoặc ảnh chụp màn hình. Không đưa secret key, `service_role`, mật khẩu database, SMTP hoặc OAuth Client Secret vào JSON.

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
- Lỗi thiếu `.dart_tool/supabase.cloud.json`: bỏ tham số `--dart-define-from-file=.dart_tool/supabase.cloud.json` để dùng cấu hình development đi kèm ứng dụng. Nếu cần project riêng, tạo `src/.env.supabase.json` và truyền đường dẫn đó; không giữ cấu hình cá nhân trong thư mục sẽ bị `flutter clean` xóa.
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

Đây là kiểm tra cấu trúc/quyền trên Cloud, chưa phải nghiệm thu toàn bộ Auth/Profile với email thật hoặc hai phiên người dùng Cloud. Password policy Cloud được đồng bộ ở mục 9. Các bước còn lại: SMTP, callback Android/web, rồi kiểm thử đăng ký/xác minh/khôi phục, hồ sơ và phân quyền giữa hai tài khoản.

Cấu hình Flutter Cloud hiện ở `src/assets/config/supabase.public.json`, được Git quản lý và đóng gói cùng ứng dụng, với đúng hai trường `SUPABASE_URL` và `SUPABASE_PUBLISHABLE_KEY`. File `.dart_tool/supabase.cloud.json` dùng ở các lượt kiểm tra trước không còn bắt buộc. Không dùng prefix `NEXT_PUBLIC_` trong Flutter. Kết quả dry-run, deploy và audit được giữ trong `src/.dart_tool/cloud-step3-*`; không chứa trong commit.

CLI 3.x mặc định nhắm local. Khi kiểm tra Cloud, cần chỉ rõ đích; ví dụ từ `src/`:

```powershell
$projectRef = '<PROJECT_REF_CUA_BAN>'
npx.cmd supabase@3.3.0 migration list "--remote=$projectRef"
npx.cmd supabase@3.3.0 db push "--remote=$projectRef" --dry-run --skip-vault
```

Hai lệnh trên chỉ kiểm tra lịch sử/xem trước; không áp dụng migration mới. Không dùng `migration repair` để che lỗi lệch lịch sử. Các lựa chọn Auth trong `supabase/config.toml` local chưa được đồng bộ lên Cloud bởi lệnh triển khai database này.

## 9. Đồng bộ Auth Cloud — 24/11/2026

Đã áp dụng chính sách riêng tại `src/tool/cloud_auth_policy/supabase/config.toml` lên project development. File chỉ khai báo các thuộc tính Auth cần quản lý; không dùng config của stack local để ghi đè cấu hình Cloud.

| Thuộc tính | Kết quả Cloud |
| --- | --- |
| Email/password provider | Bật |
| Cho phép đăng ký | Bật |
| Xác minh email | Bật (`mailer_autoconfirm = false`) |
| Độ dài mật khẩu tối thiểu | 8 ký tự, tăng từ 6 |
| Nhóm ký tự bắt buộc | Chữ hoa A–Z, thường a–z, số 0–9, symbol; `lower_upper_letters_digits_symbols` |

CLI 3.3.0 chỉ push thuộc tính được khai báo tường minh trong file này. Preview trước cập nhật xác nhận đúng hai thay đổi mật khẩu; kiểm tra sau cập nhật không còn chênh lệch thuộc tính được quản lý. Mười thuộc tính ngoài phạm vi được liệt kê trong preview có giá trị remote giữ nguyên; không đồng bộ SMTP, redirect URL, MFA hoặc cấu hình database/Storage bằng bước này.

Thao tác từ `src/`, luôn truyền project ref đúng với môi trường đích:

```powershell
$projectRef = '<PROJECT_REF_CUA_BAN>'
npx.cmd supabase@3.3.0 config diff "--remote=$projectRef" --workdir tool/cloud_auth_policy
```

Chỉ khi diff đúng phạm vi đã được giao mới áp dụng, rồi kiểm tra lại:

```powershell
npx.cmd supabase@3.3.0 config push "--remote=$projectRef" --workdir tool/cloud_auth_policy
npx.cmd supabase@3.3.0 config diff "--remote=$projectRef" --workdir tool/cloud_auth_policy
```

Kiểm thử trực tiếp Cloud bằng publishable key, không qua validator Flutter: năm yêu cầu signup thiếu lần lượt chữ hoa, chữ thường, số, symbol hoặc độ dài đều bị từ chối **HTTP 422 / `weak_password`**. REST probe gửi `X-Supabase-Api-Version: 2024-01-01` như phiên bản API của SDK đang dùng để nhận mã lỗi dạng mới. Địa chỉ QA dùng domain `.invalid`; kiểm tra `auth.users` sau thử nghiệm xác nhận không có tài khoản QA nào được tạo.

Đã kiểm tra lại endpoint Auth settings: email provider, signup và xác minh email vẫn bật. Chưa nghiệm thu đăng ký hợp lệ/gửi email thật hoặc đổi mật khẩu qua recovery trên Cloud; các luồng đó chờ cấu hình SMTP/callback và bước kiểm thử tiếp theo. Kết quả kiểm tra được lưu trong `src/.dart_tool/cloud-step4-*`, bị Git bỏ qua. Không thay UI, không thay config Auth local.

Nguồn chính thức: [Password security](https://supabase.com/docs/guides/auth/password-security), [CLI config push](https://supabase.com/docs/reference/cli/supabase-config-push).

## 10. Gmail SMTP trên Cloud — 25/11/2026

Chủ project đã cấu hình Gmail trong **Authentication → Emails → SMTP Settings** bằng mật khẩu ứng dụng Google. Kiểm tra read-only từ CLI xác nhận:

- Custom SMTP đã bật; host `smtp.gmail.com`, port `465`.
- Sender email và SMTP username có giá trị, trùng nhau.
- Mật khẩu SMTP được nhập trực tiếp trên Dashboard; không đọc hoặc đưa vào Flutter/Git.

Để thiết lập lại, bật xác minh 2 bước Google, tạo mật khẩu ứng dụng tên `StudyShare Supabase`, rồi nhập vào SMTP Settings cùng Gmail gửi thư và sender name `StudyShare`. Không dùng mật khẩu đăng nhập Google thông thường. Xem [hướng dẫn mật khẩu ứng dụng Google](https://support.google.com/accounts/answer/185833?hl=vi), [host/port SMTP Google](https://developers.google.com/workspace/gmail/imap/imap-smtp) và [SMTP Supabase](https://supabase.com/docs/guides/auth/auth-smtp).

Sau khi chủ project cung cấp email và đồng ý nhận thư thử, kiểm tra `auth.users` xác nhận email đó chưa tồn tại. Một yêu cầu đăng ký hợp lệ tới Cloud trả **HTTP 200**, tạo đúng một tài khoản chưa xác nhận và không trả phiên đăng nhập. Mật khẩu thử sinh ngẫu nhiên chỉ giữ trong file local bị Git bỏ qua. Chủ tài khoản có thể xác nhận email, sau đó dùng luồng **Quên mật khẩu** để đặt mật khẩu riêng.

Đây là phép thử gửi thư qua REST, không phải kiểm thử Flutter PKCE. Sau phản hồi HTTP 200, chủ project xác nhận **đã nhận thư và bấm link mở được app** tại origin phát triển. Kiểm tra read-only tiếp theo xác nhận đúng một tài khoản khớp email và `email_confirmed_at` đã có giá trị. Vì vậy đã có bằng chứng thư đến hộp nhận, xác nhận email trên server và mở callback web; chưa nghiệm thu đổi mật khẩu hoặc đăng nhập lại bằng mật khẩu do người dùng chọn. Dữ liệu chẩn đoán nằm trong `src/.dart_tool/cloud-step5-*`; không commit địa chỉ nhận, mật khẩu thử hoặc payload Auth.

## 11. Callback Android/web trên Cloud development — 25/11/2026

Trước cập nhật, Cloud còn Site URL `http://localhost:3000`, chưa có Redirect URLs; code đăng ký/khôi phục/gửi lại thư đều dùng deep link Android khi chạy web. Đã sửa `AuthSessionService` để web quay về origin đang chạy, giữ đúng host/cổng và bỏ path/query/fragment; Android tiếp tục dùng deep link đã đăng ký trong manifest. Áp dụng cho đăng ký, gửi lại xác nhận và khôi phục mật khẩu. SDK Supabase xử lý phiên từ callback; router không tự cấp quyền recovery từ URL.

Cấu hình Cloud riêng nằm tại `src/tool/cloud_auth_redirects/supabase/config.toml`:

| Thuộc tính | Giá trị development |
| --- | --- |
| Site URL | `http://127.0.0.1:5180/` |
| Redirect URL web | `http://127.0.0.1:5180/` |
| Redirect URL web localhost | `http://localhost:5180/` |
| Redirect URL Android | `studyshare://auth/callback` |

File này chỉ quản lý hai thuộc tính `auth.site_url` và `auth.additional_redirect_urls`, không chứa SMTP credentials hoặc khóa dự án. Preview trước cập nhật xác nhận đúng hai thuộc tính này. Sau áp dụng, diff không còn chênh lệch thuộc tính được khai báo; **18 thuộc tính remote ngoài phạm vi giữ nguyên**, bao gồm cấu hình SMTP và chính sách mật khẩu đã đặt.

Thao tác từ `src/`, kiểm tra đích và preview trước khi áp dụng:

```powershell
$projectRef = '<PROJECT_REF_CUA_BAN>'
npx.cmd supabase@3.3.0 config diff "--remote=$projectRef" --workdir tool/cloud_auth_redirects
npx.cmd supabase@3.3.0 config push "--remote=$projectRef" --workdir tool/cloud_auth_redirects
npx.cmd supabase@3.3.0 config diff "--remote=$projectRef" --workdir tool/cloud_auth_redirects
```

Chạy web ở đúng origin trong allow-list, dừng preview cũ nếu nó đang giữ cổng `5180`:

```powershell
flutter run -d chrome --web-hostname=127.0.0.1 --web-port=5180
```

Khi thử đăng ký hoặc khôi phục từ app, mở link email bằng cùng trình duyệt và cùng origin đã khởi tạo yêu cầu để SDK đọc được PKCE verifier. Không gửi link xác nhận/khôi phục vào chat hoặc lưu vào log. Khi triển khai web công khai, thay Site URL và allow-list bằng origin HTTPS của môi trường đó.

Kiểm tra code: **123 test đạt, 2 integration test local được bỏ qua theo cờ opt-in**, `flutter analyze` không báo vấn đề và build web với cấu hình Cloud thành công. Ba test callback mới kiểm tra deep link Android, hai host phát triển và HTTPS; các ca web xác nhận query/fragment chứa code/token không bị đưa vào redirect mới. Kết quả SMTP/email thật và mở callback web đã ghi tại mục 10. Chưa nghiệm thu Flutter PKCE trên Cloud, khôi phục mật khẩu, phân quyền giữa hai tài khoản hoặc thao tác mở link trực tiếp trên Android. Chẩn đoán CLI/build/test ở `src/.dart_tool/cloud-step6-*`, bị Git bỏ qua.

Nguồn chính thức: [Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls), [Mobile deep linking](https://supabase.com/docs/guides/auth/native-mobile-deep-linking), [Flutter password recovery](https://supabase.com/docs/reference/dart/auth-resetpasswordforemail).

## 12. Đăng nhập Google/GitHub — chuẩn bị OAuth

Theo yêu cầu mới nhất của Trường, hai nút Google/GitHub hiện là **UI xem trước** trên cả đăng nhập và đăng ký. Giữ logo và vị trí đã duyệt, nhãn rút gọn thành “Google”/“GitHub” dưới dòng “Hoặc tiếp tục với”. Có hover/focus; bấm chỉ hiện “Tính năng đang phát triển.” trong 3,5 giây, không gọi Auth settings, không mở provider, không tạo user/session. Hai nút tạm khóa khi form email đang xử lý. Email/mật khẩu tiếp tục là phương thức đăng nhập hoạt động.

Adapter OAuth và các unit test đã chuẩn bị trước đó được giữ để có thể dùng lại, nhưng form hiện không gọi adapter. Bật provider trong Supabase không tự kích hoạt hai nút; cần yêu cầu triển khai tiếp và nối lại callback UI. Hướng dẫn dưới đây dành cho lần kích hoạt đó, không phải điều kiện để chạy bản UI hiện tại.

Kiểm tra Cloud ngày 25/11/2026 xác nhận **Google và GitHub đều chưa bật**; chủ project cũng xác nhận chưa tạo OAuth credentials. Chưa thay đổi cấu hình provider trên Cloud và chưa nghiệm thu đăng nhập bằng tài khoản Google/GitHub thật. Gmail SMTP đã làm ở mục 10 chỉ phục vụ gửi thư, không thay thế cấu hình OAuth dưới đây.

### 12.1. Cấu hình Google trước

Luồng hiện tại sử dụng đăng nhập qua trình duyệt và callback về app. Chuẩn bị tại [Google Cloud Console](https://console.cloud.google.com/):

1. Tạo hoặc chọn Google Cloud project riêng cho StudyShare.
2. Mở **Google Auth Platform**. Khởi tạo phần **Branding** với tên ứng dụng `StudyShare`, email hỗ trợ và email liên hệ của chủ project.
3. Ở **Audience**, chọn **External** nếu cần dùng Gmail cá nhân ngoài tổ chức. Khi ứng dụng còn ở chế độ **Testing**, thêm các Gmail được dùng kiểm thử vào danh sách **Test users**.
4. Chỉ sử dụng thông tin nhận diện cần cho đăng nhập: OpenID, email và hồ sơ cơ bản.
5. Vào **Clients → Create client**, chọn loại **Web application**, đặt tên `StudyShare Supabase`.
6. Trong **Authorized redirect URIs**, thêm **callback của Supabase** lấy tại Dashboard → Authentication → Sign In / Providers → Google. Với project development hiện tại, callback là `https://dacrjfgleursgtnzeoix.supabase.co/auth/v1/callback`. Không điền URL Flutter cổng `5180` vào ô callback nhà cung cấp này.
7. Nếu khai báo **Authorized JavaScript origins** cho web development, dùng `http://localhost:5180` và origin web chính thức khi triển khai.
8. Tạo client, giữ Client ID và Client Secret. Nhập trực tiếp hai giá trị vào **Supabase → Authentication → Sign In / Providers → Google**, bật provider và lưu. Không đưa Client Secret vào Flutter, chat, ảnh chụp hoặc Git.
9. Trong app, chọn **Tiếp tục với Google**, dùng Gmail đã thêm ở Test users, cấp quyền và kiểm tra quay về app. Giữ URL chuyển hướng của app theo mục 11.

Hướng dẫn chính thức: [Supabase Google](https://supabase.com/docs/guides/auth/social-sign-in/auth-google).

### 12.2. Cấu hình GitHub

1. Mở [Register a new OAuth application](https://github.com/settings/applications/new).
2. **Application name:** `StudyShare Development`.
3. **Homepage URL:** `http://127.0.0.1:5180/` cho môi trường phát triển hiện tại.
4. **Authorization callback URL:** callback Supabase lấy tại Dashboard → Authentication → Sign In / Providers → GitHub; project hiện tại dùng `https://dacrjfgleursgtnzeoix.supabase.co/auth/v1/callback`.
5. Giữ **Enable Device Flow** không được chọn, rồi đăng ký ứng dụng.
6. Sao chép Client ID, tạo Client Secret và nhập trực tiếp vào provider GitHub trong Supabase. Bật provider rồi lưu; không gửi secret vào chat hoặc đưa vào mã nguồn.
7. Trong app, chọn **Tiếp tục với GitHub**, cấp quyền và kiểm tra callback về web/Android.

Hướng dẫn chính thức: [Supabase GitHub](https://supabase.com/docs/guides/auth/social-sign-in/auth-github).

### 12.3. Nghiệm thu sau khi bật provider

- Đăng nhập lần đầu tạo đúng hồ sơ của `auth.uid()`; đăng nhập lại dùng cùng user và giữ tên hồ sơ đã chỉnh.
- Thử tài khoản email đã được xác nhận cùng địa chỉ với provider; đối chiếu user/identities trên Supabase để xác nhận liên kết đúng, không tạo hồ sơ trùng. Không tự gộp user bằng email trong Flutter. Xem [Identity linking](https://supabase.com/docs/guides/auth/auth-identity-linking).
- Hủy cấp quyền hoặc lỗi callback không cấp phiên giả; người dùng vẫn thao tác lại được trên màn đăng nhập.
- Kiểm thử cả Chrome và Android, đăng xuất/đăng nhập lại và phân quyền giữa hai user như Auth email/password. Không mở rộng RLS/Storage grants để làm OAuth chạy.
- Bật provider không cần thêm Client Secret vào `assets/config/supabase.public.json`. Flutter tiếp tục dùng Project URL và publishable key hiện có.

## 13. Material/ảnh ngày 2 — 25/11/2026

Material SCR-07/08/09 dùng Cloud development mặc định. Từ Cá nhân → Tài liệu của tôi → Thêm tài liệu. Demo tường minh dùng store mock riêng, không fallback khi Supabase lỗi.

Bốn migration Material ngày 25/11 và Edge verify-material-image đã triển khai đúng project development. Không đưa key backend vào asset hoặc Dart define.

- Local: mở stack, chạy riêng npx supabase@3.3.0 functions serve verify-material-image --no-verify-jwt, rồi ./tool/test_material_local.ps1.
- Cloud development: ./tool/test_material_cloud.ps1. CLI cần quyền project; script giữ key trong tiến trình, khôi phục biến môi trường, không ghi key ra log.
- Cả hai chạy test/integration/material_supabase_test.dart: Auth A/B, JPEG/PNG/WebP, giả MIME, create/update, trùng ISBN khác ID, retry/conflict, bìa, revision race, session mới, RLS và chuyển chủ.
- Database: npx supabase@3.3.0 test db và db lint. Flutter: flutter analyze, flutter test, flutter build apk --debug.
- Test integration mặc định skip khi không có RUN_MATERIAL_SUPABASE. Lỗi cleanup giữ UUID test trong .dart_tool để dọn chính xác; không reset DB hoặc xóa dữ liệu người khác.
- Ảnh chụp/log/dữ liệu QA ở .dart_tool, không commit. QR và publish Listing thuộc ngày 4/3.
- Kết quả 25/11: analyze sạch; 224 test Flutter đạt (3 integration opt-in mặc định skip), 13 test Material mock/UI, 74 kiểm tra pgTAP đạt và db lint sạch. Integration opt-in đã chạy riêng trên local/Cloud, có cache offline và tách A/B.
- Android đã thử thư viện ảnh thật, nháp SQLite qua force-stop, tạo/sửa có confirm, mở lại tải đúng Cloud; đã sửa SafeArea và nút lưu trên bàn phím. Giữ một account/bản sách QA để người dùng nghiệm thu; tài khoản của test tự động được dọn riêng.

Khi Cloud có migration đồng đội chưa trong checkout: đọc lịch sử, đối chiếu nguồn và dry-run từ snapshot riêng đủ lịch sử. Không migration repair để bỏ qua phiên bản lạ, không tự merge/commit code đồng đội.

## 14. Transactions, Payment và Issues — tích hợp Supabase

Trường duyệt tích hợp ba module của Sơn với backend thật. Thành viên được viết adapter Flutter trong phạm vi đã giao; quyền quản lý project, schema, RLS và triển khai Cloud tiếp tục do Trường phụ trách.

- `20261125120000_transactions_payment_issues_rpc.sql` được phục hồi từ 50 câu lệnh trong lịch sử migration Cloud, bổ sung dấu `;` phân cách mà lịch sử không lưu lại. Nội dung từng câu lệnh giữ nguyên; cú pháp SQL và thân hàm PL/pgSQL đã được kiểm tra bằng parser PostgreSQL. Đây là **nguồn backend**, không có dữ liệu demo, tài khoản hoặc SQL seed. Cloud đã áp dụng phiên bản này; không chạy lại, xóa lịch sử hoặc `migration repair` để vượt qua sai lệch.
- `workflowRpcProvider` chọn backend theo `sessionBoundaryProvider` và `supabaseClientProvider`. Chỉ trả mock khi người dùng chọn demo và backend không cấu hình. Khi Auth lỗi/chưa đăng nhập, không có fallback sang mock.
- Các provider đọc giao dịch/sự cố, lệnh thanh toán, hủy giao dịch và xử lý sự cố cùng sử dụng một phiên thật. `issueTransactionContextProvider` đọc đúng nguồn Transaction, không trộn dữ liệu mock và Cloud.
- RPC chỉ nhận ID nghiệp vụ, nội dung và `p_idempotency_key`. Actor lấy từ JWT; client không gửi owner, holder, trạng thái mới hoặc đồng thuận thay người khác. Mỗi request giữ JWT của tài khoản đã bắt đầu thao tác và kiểm tra lại phiên trước khi trả dữ liệu/ACK.
- Command thành công phải có `ok=true`, `event_id` và DTO hợp lệ. Mất mạng/timeout/ACK không đọc được giữ trạng thái chưa rõ và cùng key để đối soát lại. Không tự tạo ACK, không dùng message lỗi thô từ server.
- Sau command, UI tải lại snapshot/timeline. Thay đổi tài khoản làm tái tạo repository và cache phụ thuộc; dữ liệu phiên trước không được hiển thị cho tài khoản mới. Ngày hạn mượn `yyyy-MM-dd` giữ theo lịch Việt Nam; timestamp được đọc về UTC.

| Nhóm | RPC có sẵn | Kết quả |
|---|---|---|
| Transaction | `get_my_transactions()`, `get_transaction_details(p_transaction_id)`, `get_transaction_timeline(p_transaction_id)` | Danh sách DTO, DTO hoặc null, danh sách event. Chỉ A/B của giao dịch. |
| Payment | `report_buyer_transfer`, `confirm_seller_payment`, `report_seller_refund`, `confirm_refund_received` | Nhận `p_transaction_id`, `p_idempotency_key`; trả Command ACK + TransactionDetails. |
| Hủy | `propose_transaction_cancellation`, `withdraw_transaction_cancellation`, `decline_transaction_cancellation`, `accept_transaction_cancellation` | Cùng tham số ID/key; đề nghị thêm `p_reason` 1–500 ký tự. Server kiểm tra nghĩa vụ sách/tiền/sự cố. |
| Issue đọc | `get_my_issues()`, `get_issue_details(p_issue_id)`, `get_issue_timeline(p_issue_id)` | DTO đã lọc quyền A/B và bên trực tiếp của chặng; không phát ảnh private. |
| Issue ghi | `report_issue`, `propose_issue_resolution`, `confirm_issue_resolution` | Lần lượt: transaction/type/reason/handover tùy chọn; issue/summary; issue/revision. Mọi lệnh có key. Nội dung 1–1000 ký tự; revision xác nhận phải khớp bản hiện hành. |

Tham số chính xác dùng prefix `p_`, xem adapter và migration đi kèm. Response đọc là JSON trực tiếp; response ghi là `{ok:true,event_id,data}` hoặc `{ok:false,code,message}`. Null/rỗng không được diễn giải thành lỗi quyền khác nhau hoặc thêm fixture vào kết quả.

Kiểm tra thông thường từ `src/`:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Kiểm tra đọc Cloud opt-in (file thông tin đăng nhập local **phải bị Git bỏ qua**, không đặt mật khẩu vào lệnh hoặc source):

```powershell
$env:WORKFLOW_TEST_ACCOUNTS_FILE = '<duong-dan-file-local-bi-Git-bo-qua>'
flutter test test/integration/workflow_supabase_test.dart --dart-define=RUN_WORKFLOW_SUPABASE=true
```

File local có `project_ref` và mảng `accounts` gồm `id`, `email`, `password`; dùng bốn tài khoản kiểm tra được nhóm trưởng cấp riêng. Test đăng nhập qua SDK rồi gọi adapter thật để kiểm tra DTO, quyền đọc, timeline và phiên mới. Không nạp/reset dữ liệu khi chạy test đọc.

Test ghi cần thêm `RUN_WORKFLOW_WRITE_TESTS=true` và biến môi trường `WORKFLOW_WRITE_FIXTURE_FILE`; chỉ chạy khi Trường đã chuẩn bị fixture QA tách biệt (`purpose=workflow-adapter-integration-test`, tài khoản prefix `workflow-qa-`, bản sách prefix `[WORKFLOW QA `). Công cụ chuẩn bị/dọn và thông tin tài khoản chỉ giữ local, không thuộc commit. Không dùng bản ghi demo của nhóm để chạy test ghi tự động.

Phần tích hợp này giữ nguyên UI/confirm hiện có và Shared Contracts. Listing/Request/Delivery/Handover, QR ngân hàng và quyền đọc/upload ảnh chứng cứ cần nghiệm thu riêng theo phân công. Issue hiện trả `evidenceCount=0`, `canViewEvidence=false` cho tới khi backend chứng cứ hoàn thiện; không mở bucket hoặc cấp quyền trực tiếp để lách giới hạn đó.
