# QUY TRÌNH GIT VÀ PHỐI HỢP NHÓM – STUDYSHARE

> **Mã tài liệu:** SS-GIT  
> **Phiên bản:** 1.1 – Bổ sung quy tắc tái sử dụng nhánh tài liệu và commit theo từng thay đổi; chờ PR review  
> **Nhóm:** 12 – Lớp 65KTPM  
> **Nhóm trưởng:** Nguyễn Văn Trường  
> **Kho Fork:** `NguyenTruongNT/project-ptuddd`  
> **Kho gốc của giảng viên:** `oanhcuongdo/project-ptuddd`  
> **Phạm vi:** Quy trình Git/GitHub; **không thay đổi quy tắc nghiệp vụ của ứng dụng**.

## 1. Nguyên tắc ưu tiên

1. Tuân thủ `README.md` tại **gốc kho giảng viên**: nhánh nhóm chính thức `nhom12-65ktpm`, thư mục nhóm `nhom12-65ktpm/`, không chỉnh sửa tài liệu hoặc mã nguồn nhóm khác.
2. Nhóm **bổ sung** nhánh `integration/nhom12-65ktpm` để ghép module và kiểm thử trước khi đưa vào nhánh nộp chính thức. Đây là **quy ước nội bộ**, không thay thế nhánh nhóm do thầy quy định.
3. Tất cả nhánh, PR nội bộ và code thuộc Fork `NguyenTruongNT/project-ptuddd`. Chỉ PR **nộp cuối kỳ** mới gửi đến `oanhcuongdo/project-ptuddd:main`.
4. `main` trong Fork chỉ là nhánh mặc định/tham chiếu; **không dùng làm nhánh tích hợp bài nhóm**.
5. Không coi một PR đã merge là bằng chứng code đã chạy đúng. Phải kiểm thử và có review.

## 2. Tên nhánh và ý nghĩa

| Nhánh | Mục đích | Được cập nhật bằng |
|---|---|---|
| `main` (Fork) | Nhánh mặc định của Fork; không dùng để tích hợp nhóm | Không PR code nhóm vào đây |
| `nhom12-65ktpm` | Nhánh **chính thức của nhóm**, nguồn PR cuối kỳ | PR từ `integration/nhom12-65ktpm` sau nghiệm thu |
| `integration/nhom12-65ktpm` | Nhánh tích hợp và kiểm thử liên thông | PR từ nhánh tính năng |
| `feature/nhom12/<nguoi>-<tinh-nang>` | Công việc riêng của từng thành viên | Commit/push của người thực hiện |

Ví dụ nhánh tính năng: `feature/nhom12/truong-material`, `feature/nhom12/khanh-borrow-requests`, `feature/nhom12/dang-handover`, `feature/nhom12/son-transaction-workflow`. **Các tài liệu chung của Trường dùng lại nhánh hiện có `feature/nhom12/truong-docs`**, không tạo nhánh mới chỉ vì thêm một file `.md`.

**Nhánh Git không phải thư mục.** Dù đang đứng ở nhánh nào, tất cả file của nhóm vẫn phải nằm trong `nhom12-65ktpm/`.

## 3. Sơ đồ PR bắt buộc theo quy ước nhóm

```text
feature/nhom12/... (Trường / Khanh / Đăng / Sơn)
               │  PR nội bộ #1: review và kiểm tra
               ▼
integration/nhom12-65ktpm
               │  Kiểm thử liên thông; đóng băng thay đổi cho đợt nghiệm thu
               │  PR nội bộ #2: review kết quả kiểm thử
               ▼
nhom12-65ktpm (nhánh chính thức của nhóm)
               │  PR nộp bài cuối kỳ
               ▼
oanhcuongdo/project-ptuddd : main
```

Đích PR phụ thuộc mục đích:

| PR | Base repository | Base branch | Compare (head) |
|---|---|---|---|
| PR tính năng | `NguyenTruongNT/project-ptuddd` | `integration/nhom12-65ktpm` | `feature/nhom12/...` |
| PR phát hành phiên bản nhóm | `NguyenTruongNT/project-ptuddd` | `nhom12-65ktpm` | `integration/nhom12-65ktpm` |
| PR nộp thầy | `oanhcuongdo/project-ptuddd` | `main` | `NguyenTruongNT:nhom12-65ktpm` |

**Không PR từ nhánh tính năng vào `main` của Fork. Không PR trực tiếp từ `integration` sang `main` của giảng viên.**

## 4. Chuẩn bị Git lần đầu

Mỗi thành viên đăng nhập tài khoản GitHub **của chính mình**, chấp nhận lời mời Collaborator và cấu hình tên/email tác giả phù hợp với tài khoản GitHub.

```bash
git config --global user.name "Ho va Ten Thanh Vien"
git config --global user.email "email-da-xac-minh-tren-GitHub"
git clone https://github.com/NguyenTruongNT/project-ptuddd.git
cd project-ptuddd
git remote -v
```

Với nhóm trưởng, nếu máy chưa khai báo kho gốc:

```bash
git remote add upstream https://github.com/oanhcuongdo/project-ptuddd.git
```

Chỉ chạy `remote add` khi `upstream` chưa tồn tại. `origin` là Fork; `upstream` là kho thầy. **Không push lên `upstream`**.

## 5. Bắt đầu một nhiệm vụ mới

**Để bám sát README thầy, nhánh tính năng được tạo từ nhánh chính thức `nhom12-65ktpm`.**

```bash
git fetch origin
git switch nhom12-65ktpm
git pull --ff-only origin nhom12-65ktpm
git switch -c feature/nhom12/son-transaction-workflow
```

Nếu máy chưa có nhánh nhóm cục bộ, sau `git fetch origin` chạy:

```bash
git switch --track origin/nhom12-65ktpm
```

**Lưu ý tích hợp:** Khi `integration` đã có công việc mới của đồng đội mà nhánh nhóm chưa có, người làm tính năng nên đồng bộ thêm `integration` vào **nhánh tính năng của mình** để thử tương thích trước khi mở PR:

```bash
git fetch origin
git switch feature/nhom12/son-transaction-workflow
git merge origin/integration/nhom12-65ktpm
```

Nếu có conflict, xử lý trên nhánh tính năng và chạy test rồi mới push. Lệnh `merge` trên chỉ dùng khi đã hiểu những thay đổi được kéo vào; không thực hiện nếu còn thay đổi local chưa commit.

## 6. Commit và push nhiều lần trên cùng nhánh

**Quy tắc đã thống nhất:** commit sau mỗi phần việc có ý nghĩa và có thể kiểm tra riêng (ví dụ cập nhật quy tắc, đồng bộ pipeline, thêm test). Không gom toàn bộ quá trình phát triển thành một commit cuối cùng; cũng không cần commit cho từng phím gõ hoặc từng thay đổi nhỏ không độc lập. Một nhánh và một PR có thể chứa nhiều commit.

**Trường hợp của Trường:** đang có `feature/nhom12/truong-docs`; tiếp tục sử dụng nhánh này cho các thay đổi tài liệu liên quan. Trước khi sửa, chạy `git status` để chắc chắn không có công việc chưa commit, rồi `git fetch origin`, `git switch feature/nhom12/truong-docs`, `git merge origin/integration/nhom12-65ktpm` để đồng bộ với nhánh đích PR khi cần. Không tạo `feature/nhom12/truong-git-workflow` mới chỉ để thêm tài liệu Git.

**Các commit tài liệu minh họa (trên cùng nhánh):**

```bash
git add nhom12-65ktpm/docs/QUY_TAC_NGHIEP_VU.md
git commit -m "docs(nhom12-65ktpm): cap nhat quy tac hien thi va QR"

git add nhom12-65ktpm/docs/QUY_TRINH_HOAT_DONG.md
git commit -m "docs(nhom12-65ktpm): dong bo pipeline va kiem thu"

git add nhom12-65ktpm/docs/QUY_TRINH_GIT_NHOM.md
git commit -m "docs(nhom12-65ktpm): bo sung quy trinh git nhom"

git push origin feature/nhom12/truong-docs
```

Các lệnh trên chạy tại gốc `project-ptuddd/`, sau khi ba file đã được đặt đúng vị trí; chỉ commit những file đã thực sự thay đổi.

```bash
git status
git add nhom12-65ktpm/
git diff --cached --name-only
git commit -m "feat(nhom12-65ktpm): xay dung man hinh chi tiet giao dich"
git push -u origin feature/nhom12/son-transaction-workflow
```

Những lần push tiếp theo trên cùng nhánh có thể dùng `git push`.

**Quy ước commit theo README giảng viên:**

- `feat(nhom12-65ktpm): mo ta ngan` – thêm chức năng/mã nguồn.
- `fix(nhom12-65ktpm): mo ta ngan` – sửa lỗi.
- `docs(nhom12-65ktpm): mo ta ngan` – cập nhật tài liệu.

Giữ định dạng của thầy; không tự đổi scope thành `integration` hoặc tên thành viên. Không sử dụng `git add .` tại gốc repo; không commit `.env`, signing keys, `build/`, `.dart_tool/`, `.gradle/`, APK/AAB hoặc ảnh riêng tư.

## 7. PR tính năng vào integration

1. Mở Pull Requests trong Fork → **New pull request**.
2. **Base repository:** `NguyenTruongNT/project-ptuddd`.
3. **Base:** `integration/nhom12-65ktpm`.
4. **Compare:** nhánh tính năng đang thực hiện.
5. Mô tả Issue liên quan, các file thay đổi, chức năng, test đã chạy và các thay đổi Shared Contracts nếu có.
6. Nhờ **ít nhất một người khác tác giả** review. PR của Trường cần được Khanh/Đăng/Sơn review.
7. Nếu có lỗi hoặc nhận xét, **tiếp tục commit/push trên cùng nhánh**; không tạo nhánh mới chỉ để sửa review.
8. Chỉ merge khi conflict đã xử lý, review đã đạt và các bài kiểm thử liên quan thành công.
9. **Để giữ lịch sử commit chi tiết**, tại nút merge của PR chọn **Create a merge commit** thay vì **Squash and merge**; sau khi merge, từng commit vẫn xem được trên nhánh đích. Nếu dùng Squash, các commit trên nhánh đích sẽ được gộp thành một commit mới (dù PR cũ vẫn có lịch sử thay đổi).

Mẫu mô tả PR:

```markdown
## Issue và mục tiêu
- Issue: #...
- Chức năng:

## Phạm vi thay đổi
- UI:
- Business logic:
- Repository / Mock:
- Test:

## Kiểm thử đã chạy
- [ ] flutter analyze
- [ ] flutter test
- [ ] Chạy trên Android/emulator (nếu có UI hoặc plugin thiết bị)

## Điểm cần reviewer lưu ý
- ...
```

*Không đánh dấu đã chạy các test khi chưa chạy thực tế.*

## 8. Tích hợp, kiểm thử và chuyển lên nhánh chính thức

- Khi các PR tính năng được merge vào `integration`, kiểm tra toàn bộ luồng nghiệp vụ theo tài liệu `QUY_TAC_NGHIEP_VU.md` và `QUY_TRINH_HOAT_DONG.md`.
- Khi dự án Flutter đã tồn tại, chạy trong `nhom12-65ktpm/src/`:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

- Chạy thực tế các hành trình mượn → bàn giao → trả; giao hộ; chuyển nhượng; ảnh/QR; lỗi mạng và quyền truy cập.
- **Đóng băng** việc merge thêm tính năng mới vào integration trong lúc nghiệm thu một đợt.
- Chỉ khi đạt kiểm thử, Trường tạo PR **từ `integration/nhom12-65ktpm` vào `nhom12-65ktpm`**, gắn kết quả kiểm thử và nhờ người khác approve.
- Nhánh `nhom12-65ktpm` có Ruleset yêu cầu PR, review và chặn force-push/xóa nhánh (tùy điều kiện thực thi trên GitHub).
- Sau khi merge PR phát hành, bảo đảm hai nhánh được đồng bộ lịch sử trước vòng phát triển tiếp theo; có thể dùng PR đồng bộ từ nhánh nhóm vào integration nếu lịch sử mới khác biệt.

## 9. Khi có conflict hoặc lỗi tích hợp

- **PR báo conflict:** không nhấn merge; người làm tính năng cập nhật nhánh bằng `git fetch origin` và `git merge origin/integration/nhom12-65ktpm`, giải quyết từng file, `git status`, kiểm thử, commit và push.
- **Code chưa biên dịch / test thất bại:** sửa trên feature hoặc tạo feature fix từ integration; không đẩy thẳng bản lỗi lên nhánh nộp.
- **Đã merge vào integration mới phát hiện lỗi:** mở Issue, sửa bằng PR mới vào integration.
- **Lỗi đã lên `nhom12-65ktpm`:** dùng PR sửa lỗi hoặc revert được review; không `push --force`, không xóa nhánh nhóm, không làm mất lịch sử.
- Khi một thành viên muốn đổi model/enum/fixture ID chung: phải thống nhất và được review trước, cập nhật tài liệu và tests liên quan.

## 10. Quyền hạn và trách nhiệm

| Thành viên | Tài khoản | Phân hệ chính |
|---|---|---|
| Nguyễn Văn Trường | `NguyenTruongNT` | Auth, Material/Listing, Shared Foundation, tích hợp |
| Vũ Tuấn Khanh | `tuankhanh594` | Discovery, Exchange Requests, mượn/trả |
| Vũ Hải Đăng | `vdng05` | Delivery, Handover, QR/camera, GPS |
| Lý Đình Sơn | `lydinhson` | Transaction, QR chuyển khoản, timeline, Issue |

Mỗi người có Issue, nhánh, commit cá nhân, PR, review, UI, nghiệp vụ, repository/mocks và tests. **Tên nhánh không thay thế chứng cứ tác giả commit hoặc công việc thực tế.**

## 11. Tài liệu cần đọc trước khi sử dụng AI hỗ trợ lập trình

1. `QUY_TAC_NGHIEP_VU.md` – quy tắc và nhãn **ĐÃ CHỐT / ĐỀ XUẤT / CHƯA QUYẾT ĐỊNH**.
2. `QUY_TRINH_HOAT_DONG.md` – pipeline, UI, dữ liệu cập nhật và ngoại lệ.
3. `QUY_TRINH_GIT_NHOM.md` – nhánh, commit, PR và quy trình cộng tác.
4. `TRANG_THAI_NGHIEP_VU.md`, `MO_HINH_DU_LIEU.md`, `HOP_DONG_LAP_TRINH.md` – **chỉ khi các tài liệu này đã được tạo, review và khóa**.

AI không được tự coi đề xuất nghiệp vụ là quy tắc đã chốt, tự tạo model trùng, tự đổi ID fixture dùng chung hoặc tự gọi `updateStatus('COMPLETED')` để bỏ qua các điều kiện bàn giao.

## 12. Nộp bài cuối kỳ

1. Xác nhận `nhom12-65ktpm` có toàn bộ code/tài liệu và bản chạy đã được nghiệm thu.
2. Tạo PR từ `NguyenTruongNT:nhom12-65ktpm` vào `oanhcuongdo/project-ptuddd:main`.
3. Tiêu đề đúng mẫu: **`[Nộp bài] nhom12-65ktpm - StudyShare`**.
4. Kiểm tra **Files changed**: chỉ có đường dẫn bắt đầu bằng `nhom12-65ktpm/`.
5. Ghi nội dung chức năng, danh sách 4 thành viên, bằng chứng test/commit/PR và hướng dẫn chạy.
6. Giảng viên kiểm tra và quyết định merge; nhóm **không tự push trực tiếp vào main kho gốc**.

---

> **Ghi chú quản trị:** Quy trình `integration` là chính sách riêng được nhóm chấp thuận để giảm rủi ro. Nếu giảng viên yêu cầu mô hình rút gọn, vẫn giữ nguyên nhánh nộp bắt buộc và điều chỉnh luồng PR nội bộ bằng một thay đổi tài liệu có review.
