# Danh Sách Thành Viên - Nhóm 12

- **Lớp học phần:** 65KTPM
- **Tên đề tài / Ứng dụng:** StudyShare – Ứng dụng di động hỗ trợ cho mượn, chuyển nhượng tài liệu học tập và xác thực giao nhận giữa sinh viên
- **Giảng viên hướng dẫn:** TS. Đỗ Oanh Cường
- **Nền tảng:** Android; Flutter/Dart

## Bảng Thông Tin Thành Viên

| STT | Họ và Tên | Mã Sinh Viên | Lớp Sinh Hoạt | Vai Trò | Nhiệm Vụ Phân Công | Đóng Góp (%) | Email |
| :-: | --------- | :----------: | :-----------: | :-----: | ------------------ | :----------: | ----- |
| 1 | Nguyễn Văn Trường | 2351170625 | 65KTPM | Nhóm trưởng | Xác thực, quản lý tài liệu và ảnh, sinh QR, quản lý trạng thái khả dụng; xây dựng Shared Models, Repository Interfaces, Mock Data chung; tích hợp và review mã nguồn. | [Đánh giá sau] | nguyentruong100105@gmail.com |
| 2 | Vũ Tuấn Khanh | 2251172386 | 64KTPM4 | Thành viên | Tìm kiếm, lọc và xem chi tiết tài liệu; gửi/duyệt yêu cầu mượn, tặng, mua; quản lý hạn mượn và yêu cầu trả sách. | [Đánh giá sau] | Tuankhanh594@gmail.com |
| 3 | Vũ Hải Đăng | 2351170580 | 65KTPM | Thành viên | Giao trực tiếp/giao hộ; quét QR/Barcode; chụp và tải ảnh minh chứng bắt buộc; xác nhận bàn giao và xử lý ảnh chờ gửi. | [Đánh giá sau] | vuhaidang3566577@gmail.com |
| 4 | Lý Đình Sơn | 2351170615 | 65KTPM | Thành viên | Quản lý vòng đời và trạng thái giao dịch; theo dõi lịch sử; xác nhận thanh toán ngoài ứng dụng; xử lý sự cố và thông báo. | [Đánh giá sau] | lydinhson.it@gmail.com |

> **Cần hoàn thiện trước khi nộp:** Điền lớp sinh hoạt, email và tỷ lệ đóng góp thực tế của từng sinh viên. Lớp học phần 65KTPM không mặc định là lớp sinh hoạt. Các tỷ lệ đóng góp cần do nhóm thống nhất theo kết quả thực hiện, không phải số liệu đã được xác nhận.

---

## Hướng Dẫn Thiết Lập Môi Trường Và Chạy Ứng Dụng

### 1. Yêu cầu môi trường
- Cài đặt Git, Flutter SDK (kèm Dart) và Android SDK.
- Sử dụng VS Code hoặc Android Studio; có máy ảo Android hoặc điện thoại Android để chạy thử.
- Kiểm tra môi trường:
  ```bash
  flutter doctor
  ```

### 2. Lấy mã nguồn dự án
```bash
git clone https://github.com/NguyenTruongNT/project-ptuddd.git
cd project-ptuddd
git fetch origin
git switch --track origin/nhom12-65ktpm
```
*Lưu ý:* Lệnh chuyển nhánh trên áp dụng sau khi nhóm đã tạo nhánh chính thức `nhom12-65ktpm` theo quy định giảng viên. Nếu nhánh đã có ở máy, dùng `git switch nhom12-65ktpm`.

### 3. Cài thư viện và chạy Flutter Android
```bash
cd nhom12-65ktpm/src
flutter pub get
flutter devices
flutter run
```

### 4. Kiểm tra mã nguồn
```bash
flutter analyze
flutter test
```
*Trạng thái:* Các lệnh trong phần 3–4 dùng sau khi dự án Flutter và các bài kiểm thử đã được tạo trong `src/`. Nếu ứng dụng sử dụng Supabase, cấu hình kết nối theo hướng dẫn riêng của nhóm; không đưa khóa bí mật hoặc `.env` lên GitHub.
