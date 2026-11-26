-- Chạy bằng kết nối quản trị sau khi áp dụng migration 20261126000500.
-- Chỉ đọc số liệu và ID cần xử lý; không reset, không sửa trạng thái hay ảnh.
select transaction_timestamp() as checked_at,status,count(*) as total,
  count(*) filter(where publication_snapshot is not null) as with_snapshot,
  count(*) filter(where publication_snapshot is null) as without_snapshot
from public.listings group by status order by status;

select listing_status,outcome,reason,count(*) as total
from studyshare_private.listing_snapshot_audit()
group by listing_status,outcome,reason order by listing_status,outcome,reason;

-- SKIPPED: chủ tin cần sửa ảnh/quyền trước. ELIGIBLE: quản trị xem xét backfill.
-- Giữ bộ lọc snapshot của Khám phá; không giả snapshot/ảnh để làm đủ số lượng.
select * from studyshare_private.listing_snapshot_audit()
where outcome<>'READY' order by listing_status,reason,listing_id;
