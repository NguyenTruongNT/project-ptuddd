# Đặc tả điều chỉnh Auth, Hồ sơ, Cài đặt

Trạng thái: đặc tả mới đã được Nguyễn Văn Trường đồng ý; triển khai cục bộ để kiểm tra kết quả. Không push/cập nhật PR trước khi được yêu cầu. Phạm vi SCR-02, SCR-03, SCR-25, SCR-26 và các bước khôi phục mật khẩu; giữ logo gốc, 26 màn và quy tắc nghiệp vụ.

## 1. Vấn đề và nguyên tắc

- Form cũ căn giữa cả chiều cao, nhiều khoảng trống đầu trang, field chỉ có gạch chân và nút nhỏ; thứ bậc nội dung chưa rõ.
- Hồ sơ trộn đọc và sửa, có thể bấm lưu khi chưa thay đổi; Cài đặt dùng control rời rạc, tên màu chưa dịch và thiếu phản hồi lưu.
- Dùng Material 3 có sẵn trong Flutter: input có nhãn/viền, button cao ít nhất 48 dp, radius 12, card 20, spacing 8/12/16/24/32, nội dung 16 sp. Không khóa text scale, không thêm thư viện UI hoặc vẽ lại logo.
- Canvas trung tính, surface rõ ràng, màu thương hiệu theo tài liệu nhóm; màu lỗi kèm icon/văn bản. Light/Dark và vi/en có cùng cấu trúc.

## 2. Bố cục và vị trí

| Vùng | Mobile (< 900 dp) | Web rộng (>= 900 dp) |
| --- | --- | --- |
| Auth | Đầu trang xanh đậm, logo gốc 72x54, tagline, “Trao tài liệu. Nhận tri thức.” 32sp; họa tiết sách vector trang trí. Surface form liền mạch, bo hai góc trên 28 và chồng lên vùng xanh; lề form 24. | Khung tối đa 1100; cột giới thiệu thương hiệu bên trái, card form tối đa 460 bên phải. |
| Form | Heading, mô tả ngắn, field theo thứ tự tác vụ; quên mật khẩu sát field mật khẩu; CTA chính toàn chiều ngang; CTA chuyển luồng ở cuối. | Giữ thứ tự và độ rộng đọc; không kéo field đầy màn hình. |
| Hồ sơ | Một heading; card avatar, tên, email và nút sửa; nhóm lối tắt; khối tài khoản/đăng xuất phía dưới. Giữ 5 tab dưới. | Nội dung giới hạn 960, card nhận diện bên trái và nhóm lối tắt bên phải. |
| Cài đặt | AppBar có Back; trạng thái tự lưu; card Giao diện, Ngôn ngữ, Hiệu ứng; chọn là áp dụng ngay. Ba chế độ dùng SegmentedButton, chuyển dọc khi thiếu chỗ hoặc chữ lớn. | Nội dung giới hạn 760; control không tràn ngang; cùng thứ tự. |

Tất cả vùng nội dung cuộn được, SafeArea và keyboard inset; field có Next/Done, autofill phù hợp. Logo gốc giữ nguyên tỉ lệ, nằm trên surface trắng để không xuất hiện nền vuông lạc màu.

Màn đăng nhập mobile có tiêu đề form “Đăng nhập”, CTA cao 52; dòng “Chưa có tài khoản? Tạo tài khoản” ở cuối. Header giữ màu thương hiệu, control theo palette đã chọn. Khi mở bàn phím, màn thấp hoặc chữ lớn, header thu gọn còn logo/tagline, ẩn họa tiết và thông điệp lớn; signup/recovery dùng header gọn. Surface form đổi theo Light/Dark. Họa tiết là CustomPainter trong repo, không vẽ lại logo hoặc cần tải hình từ mạng.

## 3. Logic tương tác

- Đăng nhập: kiểm tra field rồi gửi một lần; nút loading, giữ thông báo lỗi cạnh form; không thêm confirm cho đăng nhập.
- Đăng ký: validate -> dialog tóm tắt tên/email (không hiển thị mật khẩu) -> xác nhận mới gọi Auth -> chuyển đích/xác minh theo session server.
- Quên mật khẩu: thông báo trung lập và cooldown như hiện tại; không tiết lộ email có tồn tại.
- Đổi mật khẩu: validate -> confirm -> SDK xác thực recovery -> cập nhật và đăng xuất như hiện tại.
- Hồ sơ mặc định chỉ đọc. Nút sửa mở dialog, field có dữ liệu hiện tại. Lưu chỉ bật khi hợp lệ và có thay đổi; confirm tên mới rồi mới gọi repository. Hủy/rời dialog có sửa phải xác nhận bỏ thay đổi. Lỗi giữ nội dung, không giả lưu thành công.
- Cài đặt áp dụng ngay: cập nhật state -> ghi JSON local theo thứ tự -> đánh dấu đã lưu. Lần ghi cũ lỗi không được ghi đè lựa chọn mới; lần ghi cuối lỗi khôi phục bộ lựa chọn gần nhất đã lưu thành công. Hàng đợi tiếp tục hoạt động sau lỗi. Bỏ Lưu/Hủy/confirm/rời bản nháp; Back luôn quay lại, việc ghi vẫn tiếp tục ở controller cấp app. Không thay Supabase schema/RLS vì đây là tùy chọn theo thiết bị.
- Đăng xuất luôn confirm đối với session thật, đợi SDK rồi reset route/cache.
- Chưa có thao tác xóa trong các màn này. Component confirm chung hỗ trợ hành động phá hủy cho các màn tiếp theo; không thêm nút xóa tài khoản khi chưa có nghiệp vụ/API.

## 4. Phản hồi

Thông báo hoàn thành xuất hiện góc trên phải trong 3,5 giây; mobile giới hạn theo chiều rộng trừ lề 16, web tối đa 380. Có icon, nút đóng, Semantics liveRegion; thông báo mới thay thông báo cũ. Chỉ báo thành công sau ACK. Lỗi cần sửa được giữ tại form/dialog; không chỉ dùng toast tự biến mất cho lỗi validation, xác minh hoặc hướng dẫn email. Dialog có Hủy và nút hành động cụ thể, cuộn được trên màn nhỏ.

Cài đặt hiển thị “Đang lưu…”/“Đã lưu” cạnh phần giới thiệu. Toast thành công chờ 650ms không có thay đổi tiếp theo, gộp một chuỗi chỉnh nhanh thành một thông báo; timer mới hủy timer cũ. Phản hồi ở cấp app nên vẫn xuất hiện nếu đã rời trang. Nếu ghi lỗi, hoàn nguyên lựa chọn rồi báo lỗi theo ngôn ngữ đã khôi phục; thông báo lỗi trong trang tồn tại đến lần thay đổi tiếp theo.

## 5. Kiểm tra chấp nhận

- Kích thước 360x800, 440x956, 1440x1000; bàn phím mở; chữ 200%; Light/Dark, vi/en.
- Đăng ký không gửi trước confirm; Hủy không gọi API. Sửa profile không lưu khi không đổi; cancel/confirm/save/error giữ đúng tên. Settings áp dụng trước khi ghi hoàn tất, đổi nhanh không mất field, lỗi cuối khôi phục bản lưu gần nhất; giữ sau mở lại; Back không confirm và không ngắt việc lưu.
- Toast tồn tại 3,5 giây, đóng sớm được, không che form bằng một lớp bắt thao tác toàn màn, thay toast không để timer cũ xóa toast mới.
- Analyze, widget suite, web build và xem ảnh chụp giao diện thực tế. Không đẩy artifact/build hoặc dữ liệu tài khoản lên Git.

## 6. Nguồn tham khảo

- Flutter responsive: https://docs.flutter.dev/ui/adaptive-responsive/general
- Flutter accessibility: https://docs.flutter.dev/ui/accessibility
- Flutter AlertDialog, nội dung dài và xác nhận: https://api.flutter.dev/flutter/material/AlertDialog-class.html
- Mẫu mã nguồn mở chính thức Material 3: https://github.com/flutter/samples/tree/main/material_3_demo (tham khảo cấu trúc/theme, không chép asset hoặc thêm dependency).
- Bootstrap web chuẩn Flutter: https://docs.flutter.dev/platform-integration/web/initialization (bổ sung entry HTML để build và duyệt trên Chrome).
- Nhóm ba chế độ: https://api.flutter.dev/flutter/material/SegmentedButton-class.html
- Keyboard inset: https://api.flutter.dev/flutter/widgets/MediaQuery/viewInsetsOf.html
- SS-UIUX của nhóm: `StudyShare_UIUX_MVP_va_HuongDan_TrienKhai.md`, mục 2, SCR-25/26, design tokens. Quy tắc tự lưu Cài đặt và toast góc trên phải theo đặc tả mới đã được Trường đồng ý; chờ nghiệm thu giao diện trước tích hợp.

## 7. Kết quả kiểm tra bản cục bộ trước lần đổi header/tự lưu (24/11/2026)

| Kiểm tra | Kết quả |
| --- | --- |
| `flutter analyze --no-pub` | Không có lỗi/cảnh báo |
| `flutter test --no-pub` | 114 đạt; 1 test Auth local được bỏ qua mặc định (opt-in), không tính là đã chạy trong lượt này |
| `flutter build web --release --no-wasm-dry-run` | Thành công với URL/khóa công khai Supabase local |
| `flutter build apk --debug` | Thành công với URL Android Emulator/Supabase local |
| Widget responsive | 360x800, 440x956, 1440x1000; chữ 200%; vi/en; Light/Dark; dialog Hồ sơ với keyboard inset |
| Trình duyệt thật | Đăng ký + confirm, sửa tên + confirm + toast, cài đặt + confirm, khôi phục lựa chọn sau reload, đăng xuất + confirm; xem Light/Dark và bố cục web rộng |
| Dữ liệu thử | Chỉ Supabase local; tài khoản thử riêng đã đăng xuất và xóa; không sửa tài khoản sẵn có của người dùng |
| Git | Chỉ thư mục nhóm; commit local đúng mẫu, không push hoặc cập nhật PR |

Ảnh chụp và log kiểm tra lưu trong `src/.dart_tool/` (bị Git bỏ qua), không dùng làm asset sản phẩm. Bản Android mới đã build; kiểm tra tương tác trực tiếp của phiên bản giao diện này thực hiện trên Chrome, không thay cho nghiệm thu thao tác Android/email deep link trên thiết bị. Cần Trường duyệt giao diện trước bước push/review tích hợp.

## 8. Nghiệm thu lần đổi header/tự lưu (24/11/2026)

- `flutter analyze --no-pub`: sạch. Toàn bộ `flutter test --no-pub`: **116 đạt, 1 bỏ qua** (test Auth local opt-in). Các test Cài đặt mới thay cho test bản nháp cũ, không còn yêu cầu confirm cho tùy chọn giao diện.
- Kiểm thử controller bằng bộ lưu có thể điều khiển độ trễ/lỗi: state đổi trước khi ghi xong, nhiều thay đổi không mất field, lỗi cũ không ghi đè lựa chọn mới, lỗi cuối khôi phục bản lưu gần nhất, có thể thử lại sau lỗi.
- Widget: đổi ngôn ngữ dịch nhãn màu/toast ngay; chuỗi thay đổi gộp thông báo; Back không có dialog; lưu và báo lỗi vẫn hoạt động sau Back. Header thu gọn khi có keyboard inset, CTA nằm trong viewport 360/440 khi không có bàn phím; chữ 200% và Dark/English không overflow.
- Build web release và APK debug thành công. Trình duyệt thật: đăng ký tài khoản thử qua confirm, đổi Dark + Blue tức thì, chọn English tự lưu, reload giữ cả ba lựa chọn, đăng xuất qua confirm; xem lại login 360x800 và 440x956.
- Chỉ dùng Supabase local; tài khoản QA tạo riêng đã xóa sau đăng xuất. Cài đặt tiếp tục là dữ liệu theo thiết bị, không cần đổi schema/RLS/RPC hoặc cấu hình Supabase Cloud.
- Ảnh/log ở `src/.dart_tool/` bị Git bỏ qua. Bản xem web trên máy ở `http://127.0.0.1:5180`. Commit theo từng nhiệm vụ trên feature hiện tại, chưa push/cập nhật PR; chờ Trường duyệt kết quả hiển thị.

## 9. Ràng buộc đầu vào Auth (24/11/2026)

- Rà soát phát hiện bản trước chỉ yêu cầu mật khẩu dài tối thiểu 6 ký tự; chưa bắt buộc chữ hoa/thường/số/ký tự đặc biệt. Bản bổ sung áp dụng tối thiểu 8 ký tự và đủ bốn nhóm ký tự cho đăng ký/đặt lại mật khẩu, đồng bộ policy Supabase local. Độ dài đếm Unicode code point như server.
- Checklist năm điều kiện đặt ngay dưới ô mật khẩu, cập nhật khi gõ. Khi gửi sai, báo rõ điều kiện còn thiếu, cuộn đến field lỗi đầu tiên và không mở confirm/gọi API. Email phải đúng định dạng, tên không trống và tối đa 100 ký tự, nhập lại mật khẩu phải khớp. Đăng nhập vẫn để server xác thực tài khoản cũ, không áp policy tạo mới để khóa form đăng nhập.
- `flutter analyze --no-pub`: sạch. `flutter test --no-pub`: **120 đạt, 2 bỏ qua** (hai test local opt-in); test đếm Unicode được chạy lại riêng sau điều chỉnh và đạt. Unit kiểm tra từng điều kiện thiếu và tập symbol; widget kiểm tra đăng ký/recovery sai bị chặn trước confirm/API, sửa đúng mới tiếp tục.
- `tool/test_password_policy_local.ps1`: **1 integration test đạt trên Supabase local thật**. Gọi SDK trực tiếp: signup/updateUser thiếu từng điều kiện nhận `weak_password`; đổi sai không thay mật khẩu hiện tại, đổi đúng mới thay mật khẩu và mật khẩu cũ không đăng nhập được. Tài khoản QA do test tạo được xóa theo UUID riêng sau kiểm thử.
- Build web release và APK debug thành công. Duyệt Chrome 360/440 px: mật khẩu chỉ gồm số hiện lỗi thiếu hoa/thường/symbol ngay dưới ô, checklist hiển thị đúng và cuộn được; sửa đủ điều kiện mở dialog xác nhận. Đã hủy dialog, không tạo tài khoản từ lượt duyệt UI này. Preview web local được cập nhật tại `http://127.0.0.1:5180`.
- Chưa cấu hình Supabase Cloud cá nhân. Tài liệu chạy và contracts ghi rõ cần đặt policy Cloud tương ứng trước khi triển khai. Không thay schema/RLS/RPC trong lần bổ sung validation này.
