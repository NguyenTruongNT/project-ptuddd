-- StudyShare - RLS và Storage private mặc định.
-- Chính sách cố ý thận trọng: chưa cho app trực tiếp thay đổi nghiệp vụ.
-- Sau này những luồng approve/confirm giao nhận phải gọi RPC an toàn.

-- 1. Người dùng chỉ đọc/tạo/sửa hồ sơ của chính mình.
grant select, insert on public.profiles to authenticated;
grant update (display_name) on public.profiles to authenticated;

create policy profiles_select_self on public.profiles
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy profiles_insert_self on public.profiles
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- 2. Thông báo: chỉ người nhận thấy; chỉ cho đánh dấu đã đọc.
grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;

create policy notifications_select_self on public.notifications
  for select to authenticated
  using (recipient_id = (select auth.uid()));

create policy notifications_mark_read_self on public.notifications
  for update to authenticated
  using (recipient_id = (select auth.uid()))
  with check (recipient_id = (select auth.uid()));

-- 3. Storage. Cả hai bucket đều PRIVATE.
-- Chỉ sử dụng ảnh JPEG/PNG/WEBP và giới hạn 5 MB mỗi ảnh.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('studyshare-material-images','studyshare-material-images',false,5242880,
    array['image/jpeg','image/png','image/webp']),
  ('studyshare-handover-evidence','studyshare-handover-evidence',false,5242880,
    array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- 4. Ảnh tài liệu: có thể upload theo thư mục riêng của từng user.
-- Quy ước path: <auth.uid()>/<random-uuid>.jpg (hoặc .png/.webp).
-- Không cho sửa/xóa ảnh trực tiếp; việc gắn ảnh vào Material qua RPC sau.
create policy material_images_upload_own_folder
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'studyshare-material-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and lower(storage.extension(name)) in ('jpg','jpeg','png','webp')
  );

create policy material_images_read_own_folder
  on storage.objects for select to authenticated
  using (
    bucket_id = 'studyshare-material-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- 5. Chưa tạo bất kỳ policy client upload/read ảnh minh chứng.
-- Handover Evidence chứa thông tin riêng tư; mở quyền sau khi có
-- RPC cấp signed upload/signed read có kiểm tra đúng chặng và actor.
-- Bucket PRIVATE không đồng nghĩa tự động có quyền upload/download.

-- 6. Các bảng khác đã bật RLS và REVOKE ở migration 01.
-- Quyền đọc công khai phải đi qua read model/RPC lọc trường phù hợp.
-- KHÔNG cấp quyền cho authenticated đọc QR secret, holder history,
-- payment, handover, vấn đề tranh chấp hay dữ liệu private toàn row.
