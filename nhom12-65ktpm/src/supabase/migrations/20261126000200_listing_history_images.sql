-- Quyền ảnh snapshot lịch sử tách khỏi Discovery; chỉ A/B của đúng Transaction.
create or replace function studyshare_private.can_read_listing_object(p_path text)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(select 1 from public.listing_snapshot_images i
    join public.listings l on l.id=i.listing_id where i.storage_path=p_path and (
      l.status='PUBLISHED' or exists(select 1 from public.transactions t
        where t.listing_id=l.id and auth.uid() in (t.owner_at_acceptance,t.receiver_id)
          and exists(select 1 from jsonb_array_elements(coalesce(t.terms_snapshot->'listing'->'images','[]'::jsonb)) img
            where img->>'id'=i.image_id::text))))
$$;
create function public.get_transaction_listing_image_path(p_transaction_id uuid,p_image_id uuid)
returns text language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  return (select i.storage_path from public.transactions t
    join public.listing_snapshot_images i on i.listing_id=t.listing_id
    where t.id=p_transaction_id and i.image_id=p_image_id
      and auth.uid() in (t.owner_at_acceptance,t.receiver_id)
      and exists(select 1 from jsonb_array_elements(coalesce(t.terms_snapshot->'listing'->'images','[]'::jsonb)) img
        where img->>'id'=i.image_id::text));
end $$;
revoke all on function public.get_transaction_listing_image_path(uuid,uuid) from public,anon,authenticated;
grant execute on function public.get_transaction_listing_image_path(uuid,uuid) to authenticated;
