# STUDYSHARE — SHARED TECHNICAL FOUNDATION

> **Mã:** SS-TECH-01 · **Phiên bản:** 0.2 — nhóm trưởng đã duyệt định hướng, điều chỉnh tuân thủ README giảng viên (chưa triển khai)  
> **Dự án:** StudyShare — nhóm 12, lớp 65KTPM · **Nền tảng:** Android / Flutter  
> **Đường dẫn dự kiến:** `nhom12-65ktpm/docs/TECHNICAL_FOUNDATION.md`

## 1. Vị trí tài liệu và mức ưu tiên

1. **Nguồn quy tắc nghiệp vụ cao nhất:** `docs/QUY_TAC_NGHIEP_VU.md` **SS-BR v2.0** trên `integration/nhom12-65ktpm`.
2. `docs/QUY_TRINH_HOAT_DONG.md`: quy trình tham chiếu, chỉ sử dụng khi không mâu thuẫn SS-BR v2.0.
3. `docs/StudyShare_UIUX_MVP_va_HuongDan_TrienKhai.md`: 26 màn hình/5 tab, logo, Design System.
4. **Tài liệu mới:** `CONTRACTS.md` và `STATE_MACHINES.md` là đề xuất triển khai kỹ thuật cho các bất biến trên; không thay thế SS-BR.

**Tình trạng kiểm tra repo (22/11/2026):** PR #14 (`feature/nhom12/truong-docs` → `integration/nhom12-65ktpm`) đã **MERGED**. Thư mục nhóm trên integration hiện có `danhsachnhom.md` và `docs/`, chưa có dự án Flutter trong `src/` tại lần kiểm tra này. **README gốc của giảng viên yêu cầu đặt toàn bộ mã nguồn tại `nhom12-65ktpm/src/`; đề xuất cũ `nhom12-65ktpm/app/` đã được thay thế.** Chưa chạy lệnh Flutter/SQL hoặc thay đổi mã nguồn trong repository.

**Đồng bộ UI spec:** bản Markdown thiết kế ban đầu còn dẫn “SS-BR 1.3-REVIEW” và đề xuất đường dẫn `app/`; thay bằng **SS-BR v2.0** và `src/` trong bản hiệu chỉnh cùng đợt tài liệu kỹ thuật. Không tạo tệp nghiệp vụ thay thế `QUY_TAC_NGHIEP_VU.md`.

## 2. Phạm vi triển khai và kiến trúc đã định hướng

| Tầng | Lựa chọn đề xuất | Trách nhiệm |
|---|---|---|
| UI | Flutter Material 3, Inter, Material Symbols | 26 màn hình đã chốt; theme và trạng thái UI |
| State | Riverpod | Trạng thái tải/dữ liệu/validation, gọi repository |
| Routing | go_router | 5 tab, guard Auth, deep link notification |
| Auth | Supabase Auth (email/password MVP) | Phiên đăng nhập; reset/verify email theo cấu hình |
| Dữ liệu | Supabase PostgreSQL | Nguồn sự thật owner/holder/status/timeline |
| Ghi nghiệp vụ | RPC/transaction PostgreSQL có kiểm tra quyền | Atomic approval, confirm Handover, SELL payment, v.v. |
| Security | RLS + private Supabase Storage | Bảo vệ dữ liệu và chứng cứ theo quan hệ A/B/C |
| Offline | Drift/SQLite | Bản nháp form/ảnh đang chờ upload; không ACK giả |
| Localization | Flutter gen-l10n ARB | `vi` mặc định, `en` bổ sung |
| Tests | Dart unit/widget + Supabase integration / pgTAP | Kiểm chứng tính đúng và chống race |

Chỉ Android trong MVP. Không đưa thanh toán tự động, ví điện tử, realtime chat, tracking GPS liên tục, BOOT/PRIV nhiều cấp vào gate hoàn thành bản demo.

## 3. Cấu trúc thư mục Flutter — theo README giảng viên

**Quy định phải tuân thủ:** phần 3, 4 và 6 của `README.md` ở gốc kho giảng viên yêu cầu mọi tài liệu/mã nguồn của nhóm chỉ nằm trong `nhom12-65ktpm/`. **`src/` là thư mục chứa gốc dự án Flutter** (có `pubspec.yaml`, `android/`, `lib/`, `assets/`); **không tạo `nhom12-65ktpm/app/`**. Thư mục `src/lib/app/` phía dưới là **thư mục mã Dart nội bộ**, không phải dự án Flutter thứ hai.

```text
project-ptuddd/
├── README.md                  # README giảng viên; KHÔNG sửa
├── .gitignore                 # file gốc; KHÔNG sửa
└── nhom12-65ktpm/
    ├── danhsachnhom.md        # bắt buộc, gồm thành viên + hướng dẫn chạy
    ├── README.md              # tùy chọn, hướng dẫn riêng nhóm
    ├── docs/
    │   ├── QUY_TAC_NGHIEP_VU.md
    │   ├── QUY_TRINH_HOAT_DONG.md
    │   ├── StudyShare_UIUX_MVP_va_HuongDan_TrienKhai.md
    │   ├── TECHNICAL_FOUNDATION.md
    │   ├── CONTRACTS.md
    │   └── STATE_MACHINES.md
    └── src/                   # GỐC dự án Flutter, đúng README thầy
        ├── android/
        ├── assets/
        │   └── branding/      # dùng đúng 2 phiên bản logo đã duyệt
        ├── lib/
        │   ├── main.dart
        │   ├── app/           # mã Dart nội bộ (không phải thư mục app ở root)
        │   │   ├── bootstrap.dart
        │   │   ├── studyshare_app.dart
        │   │   ├── app_router.dart
        │   │   └── auth_guard.dart
        │   ├── core/
        │   │   ├── config/    # Supabase URL + publishable key; không chứa secret
        │   │   ├── errors/
        │   │   ├── network/
        │   │   ├── security/
        │   │   ├── time/
        │   │   └── contracts/
        │   ├── design_system/
        │   │   ├── theme/
        │   │   ├── tokens/
        │   │   ├── widgets/
        │   │   └── decorations/
        │   ├── l10n/
        │   │   ├── app_vi.arb
        │   │   └── app_en.arb
        │   ├── shared/
        │   │   ├── providers/
        │   │   ├── models/
        │   │   └── widgets/
        │   └── features/
        │       ├── auth/
        │       ├── home/
        │       ├── materials/
        │       ├── listings/
        │       ├── explore/
        │       ├── requests/
        │       ├── borrowing/
        │       ├── transactions/
        │       ├── deliveries/
        │       ├── handovers/
        │       ├── issues/
        │       ├── notifications/
        │       └── profile_settings/
        ├── supabase/
        │   ├── migrations/     # SQL schema/RLS/RPC đặt trong phạm vi src/
        │   └── seed.sql       # dữ liệu test giả lập, không chứa PII thật
        ├── test/
        │   ├── unit/
        │   ├── widget/
        │   └── contract/
        ├── integration_test/
        ├── pubspec.yaml
        └── pubspec.lock
```

**Tạo Flutter sau khi đã merge các tài liệu kỹ thuật, trên máy đã cài Flutter/Android SDK:** chạy từ thư mục `nhom12-65ktpm/`:

```bash
flutter create --platforms=android --project-name studyshare src
cd src
flutter pub get
flutter run
```

Lệnh trên **chỉ là hướng dẫn**, chưa được chạy. README của thầy minh họa thêm `ios/` trong cấu trúc Flutter; nhóm đang triển khai **Android-only** nên chưa phát triển iOS, cần giữ nhất quán với yêu cầu sản phẩm và hỏi giảng viên nếu họ yêu cầu kiểm tra sự hiện diện của `ios/` theo mẫu. `assets/branding/` và `supabase/migrations/` được tạo trong `src/` khi bắt đầu triển khai.

**Nhắc lại quy trình nộp:** nhánh `nhom12-65ktpm` là nhánh nhóm theo README; `integration/nhom12-65ktpm` chỉ là nhánh ghép nội bộ. Sau kiểm thử, đưa kết quả từ integration vào nhánh nhóm bằng PR, rồi mới mở PR từ fork nhánh nhóm sang `oanhcuongdo/project-ptuddd:main` để thầy duyệt. Không push thẳng `main` hoặc `upstream`.

Bên trong mỗi `feature`: `domain/`, `data/`, `presentation/` nếu feature đủ lớn. **Không** cho feature này import screen/controller nội bộ của feature kia; giao tiếp qua `core/contracts`, repository và route.

### Quy ước dependency

- `presentation` → controller/provider → `domain` repository interface → `data` implementation → Supabase/Drift.
- `core/contracts` **không import** `features/`; `design_system` **không đọc database**.
- UI chỉ hiển thị trạng thái server trả về; **không** gọi `update('owner_id')`, `update('holder_id')` hoặc `update('status')` trực tiếp.
- Một lệnh nghiệp vụ xuyên nhiều đối tượng phải được thực hiện **trong một transaction của server**, không tách thành nhiều cập nhật client.

## 4. Bootstrap và điều hướng

**Boot:** load lựa chọn theme/locale cục bộ → khởi tạo Supabase client → lấy Auth session → xác định route công khai/riêng tư → mở Home hoặc Login. Không yêu cầu camera/GPS ở Splash.

**NavigationShell (5 tab):** Trang chủ, Khám phá, Đăng tin, Giao dịch, Cá nhân. Tab Đăng tin mở luồng chọn/tạo Material, không thực hiện mutation tự động. Deep link từ thông báo kiểm tra lại Auth và quyền server trước khi mở chi tiết.

**Session:** nếu hết hạn/đăng xuất, vô hiệu các private providers, không hiển thị bằng chứng hoặc timeline từ tài khoản cũ khi đổi account. Có thể giữ bản nháp tại chỗ chỉ khi được ràng buộc với user ID và bảo vệ phù hợp; tuyệt đối không tự đồng bộ nháp sang tài khoản khác.

## 5. Design System và assets

| Hạng mục | Đặc tả |
|---|---|
| Logo | Dùng **nguyên hai ảnh gốc** đã được duyệt, bản trên nền trắng và bản trên nền xanh; không vẽ lại |
| Green | `#0FA241` · dark `#17411B` · accent `#ECF665` |
| Theme | Light, Dark, theo hệ thống; 4 bảng màu tùy chọn, không đổi logo |
| Grid-paper | 20–28dp, đường mảnh nhạt; không có tại QR/camera/form nhạy cảm |
| Leaf effect | 2–4 lá nhẹ ở Splash/Home/empty state, tắt khi reduce motion/low power |
| Localization | Text UI từ ARB, không tự dịch dữ liệu người dùng |
| Feedback | Snackbar 3–4 giây; lỗi nhạy cảm dùng banner/dialog cố định; success sau server ACK |
| Accessibility | Tương phản đủ, target chạm >=48dp, text scale, screen-reader, không animation chặn thao tác |

Theme/locale/effect là **preferences**, không nằm trong Domain Transaction. View có loading/empty/error/offline/forbidden; dùng `AppFailure` chung để dịch lỗi, không hiển thị stack trace cho người dùng.

## 6. Database/Storage/RLS: triển khai theo mức ưu tiên

**Nguồn sự thật:** các bảng quan hệ trong `CONTRACTS.md`, trạng thái trong `STATE_MACHINES.md`. `Material.status` kiểu `RESERVED/AVAILABLE` **không** được lưu như trạng thái độc lập nếu có thể suy ra; không có 2 active Transaction trên cùng Material.

**Nhóm table MVP:** `profiles`, `materials`, `material_images`, `listings`, `exchange_requests`, `transactions`, `borrowing_records`, `delivery_tasks`, `delivery_applications`, `handovers`, `handover_evidence`, `payment_confirmations`, `issues`, `issue_consents`, `transaction_events`, `notifications`, `courier_ratings`, `command_receipts` (idempotency), tài nguyên QR bí mật tách riêng.

**Storage:** bucket private cho ảnh Handover/Issue; ảnh công khai của Listing có thể có đường đọc public *được chủ ý* và đã loại thông tin nhạy cảm. Không dùng public bucket cho ảnh giao nhận. Link ảnh chứng cứ cấp quyền từng lần, TTL ngắn.

**RLS:** riêng từng bảng, kiểm tra `auth.uid()` theo quan hệ A/B/C và chặng; không dùng `user_metadata` do user tự sửa làm quyền. SQL function nâng quyền nếu cần phải kiểm tra actor/args và giới hạn `search_path`, quyền EXECUTE. Không có `service_role`/secret key trong APK/repo.

## 7. Hợp đồng đọc/ghi giữa các module

- **Read models chung:** `MaterialSummary`, `ListingDetails`, `RequestSummary`, `TransactionDetails`, `TransactionEventItem`, `DeliveryTaskDetails`, `HandoverDetails`, `IssueDetails`, `NotificationItem`.
- **Commands có nghĩa nghiệp vụ:** create/publish Material/Listing, tạo/duyệt/từ chối Request, xác nhận tiền, tạo/ứng tuyển/chọn courier, QR+ảnh+receiver ACK, bắt đầu trả, Issue, hủy có đồng thuận.
- **Không** cung cấp các API như `setHolder`, `forceCompleteTransaction`, `approveAsAdmin` hoặc `setMaterialAvailable`.
- **Lỗi chung:** machine code + message an toàn + dữ liệu trạng thái mới (khi conflict), đồng bộ UI lại từ server.
- **Idempotency:** mọi command ghi nhận `(actor, command, key)` và trả cùng kết quả nếu cùng key/payload được retry; key cũ với payload khác trả lỗi conflict.

Chi tiết field, quyền và tương tác nằm trong `CONTRACTS.md`; trạng thái và điều kiện trong `STATE_MACHINES.md`.

## 8. Phân công và điểm tích hợp

| Người | Chủ trì | Interface cần được Trường chuẩn bị | Test giao trước khi merge |
|---|---|---|---|
| **Trường** | Shared Foundation, Auth, Material, Listing, UI shell, tích hợp | DTO/enums, `MaterialRepository`, `ListingRepository`, shared failures, theme/router | Login/signup, Material ID riêng, Listing, theme/locale |
| **Khanh** | Explore, Request, BORROW | `ListingQueryRepository`, `RequestRepository`, `BorrowRepository` | PUBLISHED+RESERVED, approve race, hạn 1–30 ngày, trả |
| **Đăng** | DeliveryTask, QR, Handover, GPS hẹn, Drift drafts | `DeliveryRepository`, `HandoverRepository`, `EvidenceRepository` | QR mismatch, giver photo, receiver ACK, offline retry |
| **Sơn** | Transaction, payment manual, Issue, events, notifications | `TransactionRepository`, `IssueRepository`, `NotificationRepository` | SELL trước tiền bị chặn, timeline, Issue no rollback, cancel consensus |

**Quyền chốt business/UI thuộc nhóm trưởng.** Review code có thể phân công người khác để kiểm tra kỹ thuật, không làm lại quy trình biểu quyết nghiệp vụ.

## 9. Các gate thực hiện theo thứ tự

| Gate | Đầu ra phải có | Điều kiện qua gate |
|---|---|---|
| G0 — Docs | PR #14 đã merge vào integration | Xác nhận README yêu cầu `src/`; cập nhật tham chiếu UI spec, tài liệu kỹ thuật |
| G1 — Contracts | `CONTRACTS.md` và `STATE_MACHINES.md` được duyệt | Hợp đồng, enum, quyền và lỗi không mâu thuẫn SS-BR |
| G2 — Flutter shell | App Android khởi chạy | Auth route guard, 5 tab, vi/en, Light/Dark, theme/grid/leaf toggles |
| G3 — Supabase nền | SQL migrations + RLS + bucket private + seed | RLS deny người lạ, không lộ QR/evidence, repository mock và real cùng interface |
| G4 — Demo chiều đi | A Material → Listing → Request → A approve → Handover → B ACK | Contract tests + emulator kiểm thử |
| G5 — BORROW chiều trả | B trả trực tiếp/qua C → A ACK | Due date đúng, không complete sớm |
| G6 — SELL/DONATE/Courier/Issue | Các nhánh phụ và lỗi QR/offline | Không vi phạm bất biến/server atomicity |
| G7 — QA | 26 SCR, kiểm thử cả bốn vai trò ngữ cảnh | Không lỗi quyền, state, locale, dark mode, keyboard, offline |

**Lộ trình PR:** `feature/nhom12/<nguoi>-<module>` → `integration/nhom12-65ktpm` → kiểm thử nhóm → `nhom12-65ktpm` → PR đến nhánh giáo viên theo `QUY_TRINH_GIT_NHOM.md`. Không push thẳng `main`.

## 10. Checklist trước khi tạo code

- [x] PR #14 đã merge. Vẫn cần kiểm tra link ảnh Markdown trên GitHub sau đồng bộ.
- [x] Có bản Markdown UI/UX hiệu chỉnh SS-BR v2.0 và `src/` để thay thế bản cũ trong PR tiếp theo.
- [ ] Bốn repository interface và các dependency xuyên module đã được xác định, không có trùng ownership.
- [ ] Khóa tất cả enum/status theo SS-BR v2.0, không tự thêm `RESERVED` vào Listing.
- [ ] Khóa cách tính ngày `Asia/Ho_Chi_Minh` ở server; frontend không tự đặt due_date.
- [ ] Khóa ma trận RLS, cách lưu QR secret và Storage private.
- [ ] Khóa RPC atomic/idempotency; client không ghi status trực tiếp.
- [ ] Test mock 25 tình huống nghiệm thu nghiệp vụ cơ bản đã có nguồn từ SS-BR.
- [ ] Chỉ sau khi khóa interface/schema tạo `nhom12-65ktpm/src/` đúng README và PR Flutter shell.

## 11. Tài liệu tham khảo kỹ thuật

- Supabase RLS: <https://supabase.com/docs/guides/database/postgres/row-level-security>
- Supabase Flutter: <https://supabase.com/docs/guides/getting-started/quickstarts/flutter>
- Supabase Android/Flutter deep linking: <https://supabase.com/docs/guides/auth/native-mobile-deep-linking>
- Flutter i18n: <https://docs.flutter.dev/ui/internationalization>

> **Trạng thái:** Nhóm trưởng đã duyệt định hướng; bản v0.2 sửa cấu trúc để đúng README giảng viên. **Chưa có migration, Flutter shell hoặc tests thực thi.** Tên bảng/cột/RPC cụ thể vẫn cần khóa khi triển khai.
