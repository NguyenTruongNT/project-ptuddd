-- Tin PUBLISHED/HIDDEN trước ngày 3 chưa có publication_snapshot.
-- Chụp dữ liệu hiện tại lúc chuyển đổi để không làm mất tin hợp lệ ở Khám phá.
-- KHÔNG tuyên bố đây là dữ liệu lúc giao dịch cũ được duyệt, KHÔNG sửa terms_snapshot.
create function studyshare_private.backfill_legacy_listing_snapshots()
returns integer language plpgsql set search_path='' as $$
declare candidate record; m public.materials; l public.listings;
  image_count integer; affected integer:=0;
begin
  for candidate in select id,material_id from public.listings
    where publication_snapshot is null and status in ('PUBLISHED','HIDDEN')
    order by material_id,id
  loop
    -- Cùng thứ tự khóa Material -> Listing với các RPC; không đổi owner/holder/status.
    select * into m from public.materials where id=candidate.material_id for update;
    select * into l from public.listings where id=candidate.id for update;
    if l.publication_snapshot is not null or l.status not in ('PUBLISHED','HIDDEN')
      or l.created_by is distinct from m.owner_id then continue; end if;
    select count(*) into image_count from public.material_images where material_id=m.id;
    if image_count not between 1 and 5 or exists(
      select 1 from public.material_images i
      left join public.material_image_uploads u on u.id=i.id and u.storage_path=i.storage_path
      left join storage.objects o on o.bucket_id='studyshare-material-images' and o.name=i.storage_path
      where i.material_id=m.id and (u.state is distinct from 'ATTACHED'
        or u.target_material_id is distinct from m.id or o.id is null
        or o.metadata->>'size' is distinct from u.byte_size::text
        or o.metadata->>'mimetype' is distinct from u.mime_type)
    ) or exists(select 1 from public.listing_snapshot_images where listing_id=l.id)
    then continue; end if;
    -- Chỉ tham chiếu ảnh đã được xác minh/gắn thật. Không công khai đường dẫn Storage.
    insert into public.listing_snapshot_images(listing_id,image_id,storage_path,display_order)
      select l.id,id,storage_path,display_order from public.material_images where material_id=m.id;
    update public.listings set publication_snapshot=jsonb_build_object(
      'version',1,'captured_from','legacy_migration','captured_at',clock_timestamp(),
      'material_id',m.id,'material_revision',m.revision,'listing_revision',l.revision+1,
      'title',m.title,'subject',m.subject,'condition',m.condition,'isbn',m.isbn,
      'material_description',m.description,'owner_id',l.created_by,
      'owner_name',coalesce((select display_name from public.profiles where user_id=l.created_by),'Người dùng'),
      'offer_type',l.offer_type,'asking_price_vnd',l.asking_price_vnd,
      'description',l.description,'meeting_area',l.meeting_area,
      'images',(select jsonb_agg(jsonb_build_object('id',i.image_id,'display_order',i.display_order)
        order by i.display_order) from public.listing_snapshot_images i where i.listing_id=l.id))
      where id=l.id;
    affected:=affected+1;
  end loop;
  return affected;
end $$;
-- Hàm chuyển đổi chỉ chạy bởi quản trị migration, không là RPC cho ứng dụng.
revoke all on function studyshare_private.backfill_legacy_listing_snapshots() from public,anon,authenticated;
select studyshare_private.backfill_legacy_listing_snapshots();
