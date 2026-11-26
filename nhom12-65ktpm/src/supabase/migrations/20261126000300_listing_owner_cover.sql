-- Bổ sung ảnh bìa cho danh sách quản lý; không sửa migration đã chạy local.
-- DTO này chỉ trả cho chủ hiện tại đồng thời là người tạo Listing.
-- Khám phá tiếp tục dùng published_listing_json, không nhận private storage_path.
create or replace function studyshare_private.listing_json(p_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select to_jsonb(l)||jsonb_build_object(
    'title',m.title,
    'cover_storage_path',(select i.storage_path from public.material_images i
      where i.material_id=m.id order by i.display_order limit 1),
    'has_active_transaction',studyshare_private.listing_active(m.id),
    'has_pending_requests',studyshare_private.listing_pending(m.id),
    'material_revision',m.revision,
    'can_edit',l.status in ('DRAFT','HIDDEN') and m.owner_id=m.holder_id
      and not studyshare_private.listing_active(m.id) and not studyshare_private.listing_pending(m.id),
    'can_hide',l.status='PUBLISHED',
    'can_show',l.status='HIDDEN' and (studyshare_private.listing_active(m.id) or m.owner_id=m.holder_id))
  from public.listings l join public.materials m on m.id=l.material_id
  where l.id=p_id and m.owner_id=auth.uid() and l.created_by=auth.uid()
$$;
