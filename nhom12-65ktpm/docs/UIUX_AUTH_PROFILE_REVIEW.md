# Đặc tả điều chỉnh Auth, Hồ sơ, Cài đặt

Trạng thái: bản triển khai cục bộ để Nguyễn Văn Trường duyệt giao diện. Không push/cập nhật PR trước khi được duyệt. Phạm vi SCR-02, SCR-03, SCR-25, SCR-26 và các bước khôi phục mật khẩu; giữ logo gốc, 26 màn và quy tắc nghiệp vụ.

## 1. Vấn đề và nguyên tắc

- Form cũ căn giữa cả chiều cao, nhiều khoảng trống đầu trang, field chỉ có gạch chân và nút nhỏ; thứ bậc nội dung chưa rõ.
- Hồ sơ trộn đọc và sửa, có thể bấm lưu khi chưa thay đổi; Cài đặt dùng control rời rạc, tên màu chưa dịch và thiếu phản hồi lưu.
- Dùng Material 3 có sẵn trong Flutter: input có nhãn/viền, button cao ít nhất 48 dp, radius 12, card 20, spacing 8/12/16/24/32, nội dung 16 sp. Không khóa text scale, không thêm thư viện UI hoặc vẽ lại logo.
- Canvas trung tính, surface rõ ràng, màu thương hiệu theo tài liệu nhóm; màu lỗi kèm icon/văn bản. Light/Dark và vi/en có cùng cấu trúc.

## 2. Bố cục và vị trí

| Vùng | Mobile (< 900 dp) | Web rộng (>= 900 dp) |
| --- | --- | --- |
| Auth | Logo gốc ở đầu; card form ngay bên dưới, lề 20; tránh căn giữa chiều cao. Back và tên bước nằm trên form. | Khung tối đa 1100; cột giới thiệu thương hiệu bên trái, card form tối đa 460 bên phải. |
| Form | Heading, mô tả ngắn, field theo thứ tự tác vụ; quên mật khẩu sát field mật khẩu; CTA chính toàn chiều ngang; CTA chuyển luồng ở cuối. | Giữ thứ tự và độ rộng đọc; không kéo field đầy màn hình. |
| Hồ sơ | Một heading; card avatar, tên, email và nút sửa; nhóm lối tắt; khối tài khoản/đăng xuất phía dưới. Giữ 5 tab dưới. | Nội dung giới hạn 960, card nhận diện bên trái và nhóm lối tắt bên phải. |
| Cài đặt | AppBar có Back; mô tả; card Giao diện (sáng/tối/hệ thống, màu), Ngôn ngữ, Hiệu ứng; thanh Hủy/Lưu khi có thay đổi. | Nội dung giới hạn 760; control không tràn ngang; cùng thứ tự. |

Tất cả vùng nội dung cuộn được, SafeArea và keyboard inset; field có Next/Done, autofill phù hợp. Logo gốc giữ nguyên tỉ lệ, nằm trên surface trắng để không xuất hiện nền vuông lạc màu.

## 3. Logic tương tác

- Đăng nhập: kiểm tra field rồi gửi một lần; nút loading, giữ thông báo lỗi cạnh form; không thêm confirm cho đăng nhập.
- Đăng ký: validate -> dialog tóm tắt tên/email (không hiển thị mật khẩu) -> xác nhận mới gọi Auth -> chuyển đích/xác minh theo session server.
- Quên mật khẩu: thông báo trung lập và cooldown như hiện tại; không tiết lộ email có tồn tại.
- Đổi mật khẩu: validate -> confirm -> SDK xác thực recovery -> cập nhật và đăng xuất như hiện tại.
- Hồ sơ mặc định chỉ đọc. Nút sửa mở dialog, field có dữ liệu hiện tại. Lưu chỉ bật khi hợp lệ và có thay đổi; confirm tên mới rồi mới gọi repository. Hủy/rời dialog có sửa phải xác nhận bỏ thay đổi. Lỗi giữ nội dung, không giả lưu thành công.
- Cài đặt là bản nháp: chọn control chưa ghi dữ liệu. Lưu -> confirm -> ghi nguyên bộ tùy chọn bằng một lần ghi local -> cập nhật theme/locale -> thông báo. Hủy hoặc Back có thay đổi phải confirm bỏ; không đổi backend hoặc RLS.
- Đăng xuất luôn confirm đối với session thật, đợi SDK rồi reset route/cache.
- Chưa có thao tác xóa trong các màn này. Component confirm chung hỗ trợ hành động phá hủy cho các màn tiếp theo; không thêm nút xóa tài khoản khi chưa có nghiệp vụ/API.

## 4. Phản hồi

Thông báo hoàn thành xuất hiện góc trên phải trong 3,5 giây; mobile giới hạn theo chiều rộng trừ lề 16, web tối đa 380. Có icon, nút đóng, Semantics liveRegion; thông báo mới thay thông báo cũ. Chỉ báo thành công sau ACK. Lỗi cần sửa được giữ tại form/dialog; không chỉ dùng toast tự biến mất cho lỗi validation, xác minh hoặc hướng dẫn email. Dialog có Hủy và nút hành động cụ thể, cuộn được trên màn nhỏ.

## 5. Kiểm tra chấp nhận

- Kích thước 360x800, 440x956, 1440x1000; bàn phím mở; chữ 200%; Light/Dark, vi/en.
- Đăng ký không gửi trước confirm; Hủy không gọi API. Sửa profile không lưu khi không đổi; cancel/confirm/save/error giữ đúng tên. Settings không lưu trước confirm, khởi động lại vẫn giữ sau save. Back có nháp phải confirm.
- Toast tồn tại 3,5 giây, đóng sớm được, không che form bằng một lớp bắt thao tác toàn màn, thay toast không để timer cũ xóa toast mới.
- Analyze, widget suite, web build và xem ảnh chụp giao diện thực tế. Không đẩy artifact/build hoặc dữ liệu tài khoản lên Git.

## 6. Nguồn tham khảo

- Flutter responsive: https://docs.flutter.dev/ui/adaptive-responsive/general
- Flutter accessibility: https://docs.flutter.dev/ui/accessibility
- Flutter AlertDialog, nội dung dài và xác nhận: https://api.flutter.dev/flutter/material/AlertDialog-class.html
- Mẫu mã nguồn mở chính thức Material 3: https://github.com/flutter/samples/tree/main/material_3_demo (tham khảo cấu trúc/theme, không chép asset hoặc thêm dependency).
- SS-UIUX của nhóm: `StudyShare_UIUX_MVP_va_HuongDan_TrienKhai.md`, mục 2, SCR-25/26, design tokens. Quy tắc bản nháp Cài đặt và toast góc trên phải trong tài liệu này là điều chỉnh theo yêu cầu mới của Trường, chờ duyệt trước tích hợp.
