-- Chỉ đọc bằng kết nối quản trị sau migration ngày 4; không in secret/hash/payload.
-- Credential legacy cần đối chiếu trước triển khai; báo cáo không tự xoay mã.
select format_version, count(*) as credential_count
from public.material_qr_credentials group by format_version order by format_version;

select q.material_id, q.format_version, q.created_at,
  exists(select 1 from studyshare_private.material_qr_signing_keys k
    where k.version=q.format_version) as signing_key_available
from public.material_qr_credentials q
where q.format_version<>1 or not exists(
  select 1 from studyshare_private.material_qr_signing_keys k where k.version=q.format_version);

select count(*) as unresolved_qr_mismatch_count
from public.handovers where qr_mismatch_at is not null;
