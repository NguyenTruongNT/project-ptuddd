-- S?a validation theo tr?ng th?i th?c l?u; gi? nguy?n migration ?? ?p d?ng cloud.
-- Gi? ch? k?, quy?n, receipt/idempotency v? th? t? kh?a Material -> Listing.
create or replace function public.save_listing(p_action text,p_payload jsonb,p_idempotency_key text,
  p_material_id uuid default null,p_listing_id uuid default null,
  p_expected_revision bigint default null,p_expected_material_revision bigint default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); l public.listings; m public.materials; old_receipt public.command_receipts;
  command text; payload_hash text; result jsonb; offer text; price bigint; description_text text; area text;
  is_active boolean; is_pending boolean;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_action is null or p_action not in ('draft','publish','hide','show')
    or p_idempotency_key is null or char_length(p_idempotency_key) not between 1 and 128
    or p_payload is null or jsonb_typeof(p_payload)<>'object' then raise exception 'INVALID_INPUT'; end if;
  command:='listing_'||p_action;
  payload_hash:=md5(jsonb_build_array(p_payload,p_material_id,p_listing_id,p_expected_revision,p_expected_material_revision)::text);
  perform pg_advisory_xact_lock(hashtextextended(actor::text||command||p_idempotency_key,0));
  select * into old_receipt from public.command_receipts r where r.actor_id=actor
    and r.command_name=command and r.idempotency_key=p_idempotency_key;
  if found then
    if old_receipt.payload_hash<>payload_hash then raise exception 'CONFLICT'; end if;
    if not exists(select 1 from public.listings x join public.materials y on y.id=x.material_id
      where x.id=(old_receipt.result_json->'data'->>'id')::uuid
        and x.created_by=actor and y.owner_id=actor) then raise exception 'FORBIDDEN'; end if;
    return old_receipt.result_json;
  end if;
  if p_listing_id is not null then
    select material_id into p_material_id from public.listings where id=p_listing_id
      and (p_material_id is null or material_id=p_material_id);
  end if;
  select * into m from public.materials where id=p_material_id and owner_id=actor for update;
  if not found then raise exception 'FORBIDDEN'; end if;
  if p_listing_id is not null then
    select * into l from public.listings where id=p_listing_id and material_id=m.id
      and created_by=actor for update;
    if not found then raise exception 'FORBIDDEN'; end if;
    if l.status='ARCHIVED' or p_expected_revision is distinct from l.revision then raise exception 'CONFLICT'; end if;
  elsif exists(select 1 from public.listings where material_id=m.id and status<>'ARCHIVED') then
    raise exception 'CONFLICT';
  end if;
  is_active:=studyshare_private.listing_active(m.id);
  is_pending:=studyshare_private.listing_pending(m.id);
  if p_action in ('hide','show') then
    if l.id is null or p_payload<>'{}'::jsonb then raise exception 'INVALID_INPUT'; end if;
    if p_action='hide' then
      if l.status not in ('PUBLISHED','HIDDEN') then raise exception 'CONFLICT'; end if;
      if l.status='PUBLISHED' then
        update public.listings set status='HIDDEN' where id=l.id;
      end if;
    else
      if l.status not in ('HIDDEN','PUBLISHED') then raise exception 'CONFLICT'; end if;
      if l.status='HIDDEN' then
        if is_active then
          if l.publication_snapshot is null or not exists(select 1 from public.transactions t
            where t.listing_id=l.id and t.material_id=m.id and t.status not in ('COMPLETED','CANCELLED'))
            then raise exception 'CONFLICT'; end if;
          update public.listings set status='PUBLISHED' where id=l.id;
        else
          if m.holder_id<>actor then raise exception 'MATERIAL_UNAVAILABLE'; end if;
          if p_expected_material_revision is distinct from m.revision then raise exception 'CONFLICT'; end if;
          if l.offer_type='SELL' and l.asking_price_vnd is null then raise exception 'INVALID_INPUT'; end if;
          if is_pending then
            if l.publication_snapshot is null
              or (l.publication_snapshot->>'material_revision')::bigint is distinct from m.revision
              or not exists(select 1 from public.listing_snapshot_images where listing_id=l.id)
              then raise exception 'CONFLICT'; end if;
            update public.listings set status='PUBLISHED' where id=l.id;
          else perform studyshare_private.capture_listing(l.id); end if;
        end if;
      end if;
    end if;
  else
    if is_active or is_pending or m.holder_id<>actor then raise exception 'MATERIAL_UNAVAILABLE'; end if;
    if p_expected_material_revision is distinct from m.revision then raise exception 'CONFLICT'; end if;
    if l.id is not null and l.status not in ('DRAFT','HIDDEN') then raise exception 'CONFLICT'; end if;
    if p_action='publish' and l.status='HIDDEN' then raise exception 'CONFLICT'; end if;
    if exists(select 1 from jsonb_object_keys(p_payload) k where k not in
      ('offer_type','asking_price_vnd','description','meeting_area'))
      or jsonb_typeof(p_payload->'offer_type') is distinct from 'string' then raise exception 'INVALID_INPUT'; end if;
    offer:=p_payload->>'offer_type';
    if offer not in ('BORROW','DONATE','SELL') then raise exception 'INVALID_INPUT'; end if;
    if p_payload ? 'asking_price_vnd' and jsonb_typeof(p_payload->'asking_price_vnd')<>'null' then
      if jsonb_typeof(p_payload->'asking_price_vnd')<>'number'
        or (p_payload->>'asking_price_vnd') !~ '^[0-9]+$'
        or (p_payload->>'asking_price_vnd')::numeric>9223372036854775807 then raise exception 'INVALID_INPUT'; end if;
      price:=(p_payload->>'asking_price_vnd')::bigint;
      if price<=0 then raise exception 'INVALID_INPUT'; end if;
    end if;
    -- L?u n?i dung HIDDEN kh?ng ??i v? DRAFT: gi? ph?i h?p l? tr??c UPDATE.
    -- CHECK l? l?p b?o v? cu?i; RPC tr? INVALID_INPUT thay v? ?? r?i xu?ng 23514.
    if (offer<>'SELL' and price is not null) or (offer='SELL' and price is null
      and (p_action='publish' or coalesce(l.status,'DRAFT')<>'DRAFT')) then
      raise exception 'INVALID_INPUT'; end if;
    if (p_payload ? 'description' and jsonb_typeof(p_payload->'description') not in ('null','string'))
      or (p_payload ? 'meeting_area' and jsonb_typeof(p_payload->'meeting_area') not in ('null','string')) then
      raise exception 'INVALID_INPUT'; end if;
    description_text:=nullif(regexp_replace(p_payload->>'description','^[[:space:]]+|[[:space:]]+$','','g'),'');
    area:=nullif(regexp_replace(p_payload->>'meeting_area','^[[:space:]]+|[[:space:]]+$','','g'),'');
    if char_length(description_text)>2000 or char_length(area)>200
      or translate(coalesce(description_text,'')||coalesce(area,''),E'\n\r\t','') ~ '[[:cntrl:]]' then
      raise exception 'INVALID_INPUT'; end if;
    if l.id is null then
      insert into public.listings(material_id,created_by,offer_type,asking_price_vnd,description,meeting_area)
        values(m.id,actor,offer,price,description_text,area) returning * into l;
    else
      update public.listings set offer_type=offer,asking_price_vnd=price,
        description=description_text,meeting_area=area where id=l.id returning * into l;
    end if;
    if p_action='publish' then perform studyshare_private.capture_listing(l.id); end if;
  end if;
  result:=jsonb_build_object('ok',true,'data',studyshare_private.listing_json(l.id),
    'command_id',gen_random_uuid(),'server_revision',(select revision from public.listings where id=l.id));
  insert into public.command_receipts(actor_id,command_name,idempotency_key,payload_hash,result_json)
    values(actor,command,p_idempotency_key,payload_hash,result);
  return result;
exception when unique_violation then raise exception 'CONFLICT';
end $$;

-- Báo cáo chỉ đọc cho quản trị migration. Không sửa tin, không tự backfill,
-- không trả metadata riêng tư/Storage path và không mở RPC cho mobile.
create function studyshare_private.listing_snapshot_audit()
returns table(listing_id uuid,listing_status text,outcome text,reason text,image_count integer)
language sql stable set search_path='' as $$
  with inspected as (
    select l.id,l.status,l.publication_snapshot,i.image_count,
      case
        -- Snapshot lịch sử vẫn hợp lệ khi ảnh đã gỡ khỏi gallery hiện tại.
        when l.publication_snapshot is not null then 'SNAPSHOT_READY'
        when l.created_by is distinct from m.owner_id then 'OWNER_CHANGED'
        when i.image_count=0 then 'MISSING_IMAGES'
        when i.image_count>5 then 'TOO_MANY_IMAGES'
        when i.bad_registry then 'IMAGE_NOT_ATTACHED'
        when i.missing_object then 'STORAGE_OBJECT_MISSING'
        when i.bad_metadata then 'STORAGE_METADATA_MISMATCH'
        when exists(select 1 from public.listing_snapshot_images s where s.listing_id=l.id)
          then 'REFERENCES_WITHOUT_SNAPSHOT'
        else 'BACKFILL_ELIGIBLE'
      end reason
    from public.listings l join public.materials m on m.id=l.material_id
    cross join lateral (
      select count(*)::integer image_count,
        bool_or(u.state is distinct from 'ATTACHED' or u.target_material_id is distinct from m.id) bad_registry,
        bool_or(o.id is null) missing_object,
        bool_or(o.metadata->>'size' is distinct from u.byte_size::text
          or o.metadata->>'mimetype' is distinct from u.mime_type) bad_metadata
      from public.material_images g
      left join public.material_image_uploads u on u.id=g.id and u.storage_path=g.storage_path
      left join storage.objects o on o.bucket_id='studyshare-material-images' and o.name=g.storage_path
      where g.material_id=m.id
    ) i where l.status in ('PUBLISHED','HIDDEN')
  ) select id,status,
      case reason when 'SNAPSHOT_READY' then 'READY'
        when 'BACKFILL_ELIGIBLE' then 'ELIGIBLE' else 'SKIPPED' end,
      reason,image_count from inspected
$$;
revoke all on function studyshare_private.listing_snapshot_audit() from public,anon,authenticated;
