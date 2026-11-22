# SS-HANDOFF – Bàn giao khung chung StudyShare cho 4 thành viên

> Mục tiêu: chốt **phần dùng chung**, tuyệt đối không làm thay nội dung nghiệp vụ thuộc module cá nhân.
> Nguồn quy tắc: `QUY_TAC_NGHIEP_VU.md` (SS-BR v2.0), `CONTRACTS.md`, `STATE_MACHINES.md`, `QUY_TRINH_GIT_NHOM.md`.

## 1. Những phần đã có trong integration (kiểm tra tại thời điểm soạn)

- PR #16: Flutter Android Foundation, 5 tab, theme, localization.
- PR #17: Shared Core (domain/read models, enums, repository interfaces, mock chỉ đọc, unit tests).
- PR #18: Supabase Foundation (schema, RLS, private Storage, Auth Session Service, tests).
- PR #19: Shared App Integration (26 route, placeholder, widget Loading/Empty/Error, provider mock, tests).

**Đây là nền móng cho phát triển.** 26 route không có nghĩa đã có 26 màn hình chức năng; các placeholder phải được chủ module thay thế. Auth Session Service không phải giao diện đăng nhập; mock không phải backend thực.

## 2. Ranh giới trách nhiệm: không lập trình thay thành viên

| Người phụ trách | Phần việc cá nhân sau bàn giao | Không thuộc commit khung chung |
|---|---|---|
| **Nguyễn Văn Trường** | Auth/UI đăng nhập; Material/Listing, ảnh tài liệu, QR Material; tích hợp và review | Triển khai tính năng cá nhân Trường phải có PR riêng, không đưa vào PR bàn giao |
| **Vũ Tuấn Khanh** | Explore, tìm kiếm/lọc, ExchangeRequest, mượn và trả | Không xây màn/logic Request, Borrow thay Khanh |
| **Vũ Hải Đăng** | DeliveryTask, courier, QR scan, ảnh minh chứng, Handover, nháp offline | Không xây scan/ACK/giao hộ thay Đăng |
| **Lý Đình Sơn** | Transaction/Timeline, SELL payment confirmation, Issue, Notifications | Không xây giao dịch/thanh toán/xử lý sự cố thay Sơn |

Thành viên có thể phối hợp review và hỗ trợ nhưng mọi thay đổi phải rõ tác giả, Issue, commit và PR; không mặc nhiên gộp công việc cá nhân vào khung chung.

## 3. Hợp đồng và file dùng chung – cần phối hợp review

| Phạm vi | Vị trí | Quy tắc |
|---|---|---|
| Routing | `src/lib/app/app_routes.dart`, `app_router.dart` | Sử dụng route có sẵn; không tự đổi URL hoặc xóa nhánh điều hướng của người khác |
| UI | `src/lib/design_system/`, `src/lib/l10n/` | Dùng theme và component chung; nếu đổi theme/l10n thì review tác động mọi module |
| Domain | `src/lib/core/contracts/` | Không tự tạo enum/status/model trùng; thay đổi contract cần PR và tests |
| Mock | `src/lib/core/mock/`, `src/lib/core/providers/` | Mock chỉ đọc; giữ fixture IDs và kiểm tra quyền theo user mô phỏng |
| Supabase | `src/supabase/migrations/`, `src/lib/core/auth/` | Thay đổi quyền/RPC cần kiểm tra server và đồng thuận các module liên quan |
| Feature | `src/lib/features/` | Mỗi thành viên quản lý các màn hình thuộc phần việc của mình |

**Bất biến bắt buộc:** client không tự chuyển `ownerId`, `holderId` hoặc trạng thái `COMPLETED`. Receiver ACK, seller payment, approve Request, Issue resolution phải được server xác thực; QR đọc được sai là hard block, không fallback manual.

## 4. Cách bắt đầu code riêng của từng thành viên

1. `git fetch origin` rồi `git switch integration/nhom12-65ktpm` (hoặc `git switch --track origin/integration/nhom12-65ktpm` nếu nhánh chưa có trên máy).
2. `git pull --ff-only origin integration/nhom12-65ktpm`.
3. Tạo `feature/nhom12/<nguoi>-<module>`; không dùng cùng nhánh của thành viên khác.
4. Chạy `flutter pub get`, `flutter analyze`, `flutter test` theo hướng dẫn môi trường.
5. Chỉ sửa file thuộc module mình và những file chung thực sự cần; có comment tiếng Việt.
6. Một nhiệm vụ có ý nghĩa = một commit; commit riêng tests/fix; PR vào `integration/nhom12-65ktpm`.
7. Cập nhật placeholder thành màn hình thật theo SCR tương ứng **khi làm module cá nhân**, không làm trong PR bàn giao.

## 5. Tiêu chí bàn giao Shared Foundation

- [ ] Trên integration, `flutter pub get`, `flutter analyze`, `flutter test` đều đạt trên máy thành viên nhận bàn giao.
- [ ] Ứng dụng mở được trên Android; 5 tab, Settings, danh mục routes và mock preview hoạt động.
- [ ] SQL schema/RLS tests đạt ở môi trường Supabase local được cấu hình; không có secret key trong repository.
- [ ] Mỗi thành viên hiểu cách chạy ở chế độ mock và hiểu Supabase local/cloud chỉ cấu hình theo quyền.
- [ ] Mỗi thành viên xác nhận ranh giới module, Shared Contracts và quy trình PR.
- [ ] Nhánh chính thức `nhom12-65ktpm` chỉ nhận bản integration đã review/nghiệm thu.

**Không tự đánh dấu [x] nếu chưa kiểm tra thực tế trên máy của nhóm.**

## 6. CI GitHub Actions và hạn chế theo README giảng viên

GitHub Actions workflow phải nằm ở **`.github/workflows/` tại gốc repository** để được GitHub tự chạy. README giảng viên chỉ cho nhóm thay đổi bên trong `nhom12-65ktpm/` và không cho sửa file gốc. Vì vậy **không tự thêm workflow ở root** bằng PR nhóm.

Trong phạm vi được phép, nhóm dùng `src/tool/check_shared.ps1` để kiểm tra nhất quán trước PR. Nếu giảng viên cấp phép sửa `.github/workflows/`, mở một đề xuất riêng và review trước; không gắn nhãn CI tự động khi thực tế chưa có workflow.

## 7. Những phần CHƯA phải mục tiêu của khung chung

- Auth UI/đăng nhập/đăng ký/reset, Material/Listing/QR nguồn: do Trường làm ở PR cá nhân.
- Explore/Request/Borrow: Khanh.
- Handover/DeliveryTask/QR scan/camera: Đăng.
- Transaction/Payment/Issue/Notification: Sơn.
- RPC nguyên tử cho các hành động nghiệp vụ phát triển cùng chủ module và cần review xuyên module; **không** đưa logic nhạy cảm vào mock chỉ để demo.

Sau khi thống nhất bàn giao, nhóm có thể phát triển các module riêng song song; không cần chờ khung chung có màn hình nghiệp vụ thật.
