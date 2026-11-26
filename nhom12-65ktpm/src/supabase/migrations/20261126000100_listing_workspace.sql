-- Ngày 3: Listing commands/read models theo SS-BR phụ lục B đã được Trường duyệt.
-- Không sửa migration cũ, không cấp quyền ghi bảng trực tiếp cho mobile.
alter table public.listings
  add column revision bigint not null default 1 check (revision > 0),
  add column updated_at timestamptz not null default now(),
  add column created_by uuid references auth.users(id),
  add column meeting_area text,
  add column publication_snapshot jsonb;
update public.listings l set created_by=coalesce(
  (select t.owner_at_acceptance from public.transactions t where t.listing_id=l.id limit 1),
  (select m.owner_id from public.materials m where m.id=l.material_id));
alter table public.listings alter column created_by set not null;
-- CHECK (>0) cũ nhận UNKNOWN khi SELL null. Nháp được thiếu giá có chủ đích.
do $$ declare c record; begin
  for c in select conname from pg_constraint where conrelid='public.listings'::regclass
    and contype='c' and pg_get_constraintdef(oid) like '%asking_price_vnd%'
  loop execute format('alter table public.listings drop constraint %I',c.conname); end loop;
end $$;
alter table public.listings add constraint listing_price_by_status check (
  (offer_type='SELL' and ((status='DRAFT' and asking_price_vnd is null)
    or (asking_price_vnd is not null and asking_price_vnd>0)))
  or (offer_type in ('BORROW','DONATE') and asking_price_vnd is null));
alter table public.listings add constraint listing_text_lengths check (
  (description is null or char_length(description)<=2000)
  and (meeting_area is null or char_length(meeting_area)<=200));
create index listings_creator_updated on public.listings(created_by,updated_at desc,id);

-- Tham chiếu media bất biến độc lập gallery; save_material có thể gỡ dòng gallery.
create table public.listing_snapshot_images (
  listing_id uuid not null references public.listings(id),
  image_id uuid not null,
  storage_path text not null,
  display_order integer not null check(display_order>=0),
  primary key(listing_id,image_id), unique(listing_id,display_order)
);
alter table public.listing_snapshot_images enable row level security;
revoke all on public.listing_snapshot_images from public,anon,authenticated;
grant select,insert,update,delete on public.listing_snapshot_images to service_role;

create function studyshare_private.listing_stamp()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='INSERT' then
    new.created_by:=coalesce(new.created_by,(select owner_id from public.materials where id=new.material_id));
  else
    if new.material_id<>old.material_id or new.created_by<>old.created_by then
      raise exception 'INVALID_INPUT';
    end if;
    new.revision:=old.revision+1;
    new.updated_at:=clock_timestamp();
  end if;
  return new;
end $$;
create trigger listing_stamp before insert or update on public.listings
  for each row execute function studyshare_private.listing_stamp();

create function studyshare_private.listing_pending(p_material uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.exchange_requests r join public.listings l on l.id=r.listing_id
    where l.material_id=p_material and r.status='PENDING')
$$;
create function studyshare_private.listing_active(p_material uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.transactions where material_id=p_material
    and status not in ('COMPLETED','CANCELLED'))
$$;
create function studyshare_private.listing_json(p_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select to_jsonb(l)||jsonb_build_object('has_active_transaction',studyshare_private.listing_active(m.id),
    'has_pending_requests',studyshare_private.listing_pending(m.id),
    'material_revision',m.revision,
    'can_edit',l.status in ('DRAFT','HIDDEN') and m.owner_id=m.holder_id
      and not studyshare_private.listing_active(m.id) and not studyshare_private.listing_pending(m.id),
    'can_hide',l.status='PUBLISHED',
    'can_show',l.status='HIDDEN' and (studyshare_private.listing_active(m.id) or m.owner_id=m.holder_id))
  from public.listings l join public.materials m on m.id=l.material_id
  where l.id=p_id and m.owner_id=auth.uid() and l.created_by=auth.uid()
$$;
create function public.get_my_listing(p_listing_id uuid default null,p_material_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_listing_id is null and p_material_id is null then raise exception 'INVALID_INPUT'; end if;
  return (select studyshare_private.listing_json(l.id) from public.listings l
    where (p_listing_id is null or l.id=p_listing_id)
    and (p_material_id is null or l.material_id=p_material_id)
    and (p_listing_id is not null or l.status<>'ARCHIVED') limit 1);
end $$;
create function public.search_my_listings(p_status text default 'all',p_query text default '',
  p_offset integer default 0,p_limit integer default 20)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare rows jsonb;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_status is null or p_status not in ('all','DRAFT','PUBLISHED','HIDDEN','ARCHIVED')
    or p_query is null or char_length(p_query)>200 or p_offset is null or p_offset<0
    or p_limit is null or p_limit not between 1 and 100 then raise exception 'INVALID_INPUT'; end if;
  select coalesce(jsonb_agg(d order by updated_at desc,id),'[]'::jsonb) into rows from (
    select l.id,l.updated_at,studyshare_private.listing_json(l.id)||jsonb_build_object('title',m.title) d
    from public.listings l join public.materials m on m.id=l.material_id
    where m.owner_id=auth.uid() and l.created_by=auth.uid()
      and (p_status='all' or l.status=p_status)
      and (p_query='' or strpos(lower(m.title),lower(trim(p_query)))>0)
    order by l.updated_at desc,l.id offset p_offset limit p_limit+1) q;
  return jsonb_build_object('items',(select coalesce(jsonb_agg(value),'[]'::jsonb)
    from jsonb_array_elements(rows) with ordinality e(value,n) where n<=p_limit),
    'has_more',jsonb_array_length(rows)>p_limit);
end $$;

create function studyshare_private.capture_listing(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare l public.listings; m public.materials; image_count integer;
begin
  select * into l from public.listings where id=p_id;
  select * into m from public.materials where id=l.material_id;
  select count(*) into image_count from public.material_images where material_id=m.id;
  if image_count not between 1 and 5 or exists(
    select 1 from public.material_images i
    left join public.material_image_uploads u on u.id=i.id and u.storage_path=i.storage_path
    left join storage.objects o on o.bucket_id='studyshare-material-images' and o.name=i.storage_path
    where i.material_id=m.id and (u.state is distinct from 'ATTACHED'
      or u.target_material_id is distinct from m.id or o.id is null
      or (o.metadata->>'size')::bigint is distinct from u.byte_size::bigint
      or o.metadata->>'mimetype' is distinct from u.mime_type)) then
    raise exception 'INVALID_INPUT';
  end if;
  -- Tin chưa có transaction/pending mới được chụp snapshot mới; file cũ vẫn giữ private.
  delete from public.listing_snapshot_images where listing_id=l.id;
  insert into public.listing_snapshot_images(listing_id,image_id,storage_path,display_order)
    select l.id,id,storage_path,display_order from public.material_images where material_id=m.id;
  update public.listings set publication_snapshot=jsonb_build_object(
    'version',1,'material_id',m.id,'material_revision',m.revision,'listing_revision',l.revision+1,
    'title',m.title,'subject',m.subject,'condition',m.condition,'isbn',m.isbn,
    'material_description',m.description,'owner_id',l.created_by,
    'owner_name',coalesce((select display_name from public.profiles where user_id=l.created_by),'Người dùng'),
    'offer_type',l.offer_type,'asking_price_vnd',l.asking_price_vnd,
    'description',l.description,'meeting_area',l.meeting_area,
    'images',(select jsonb_agg(jsonb_build_object('id',i.image_id,'display_order',i.display_order)
      order by i.display_order) from public.listing_snapshot_images i where i.listing_id=l.id)),
    status='PUBLISHED',published_at=coalesce(published_at,clock_timestamp()) where id=l.id;
end $$;

-- Một command envelope cho save/publish/hide/show, không có setStatus tổng quát.
create function public.save_listing(p_action text,p_payload jsonb,p_idempotency_key text,
  p_material_id uuid default null,p_listing_id uuid default null,
  p_expected_revision bigint default null,p_expected_material_revision bigint default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); l public.listings; m public.materials; old_receipt public.command_receipts;
  command text; payload_hash text; result jsonb; offer text; price bigint; description_text text; area text;
  is_active boolean; is_pending boolean; changed boolean:=false;
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
        update public.listings set status='HIDDEN' where id=l.id; changed:=true;
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
        changed:=true;
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
    if (offer<>'SELL' and price is not null) or (offer='SELL' and price is null and p_action='publish') then
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
    changed:=true;
  end if;
  result:=jsonb_build_object('ok',true,'data',studyshare_private.listing_json(l.id),
    'command_id',gen_random_uuid(),'server_revision',(select revision from public.listings where id=l.id));
  insert into public.command_receipts(actor_id,command_name,idempotency_key,payload_hash,result_json)
    values(actor,command,p_idempotency_key,payload_hash,result);
  return result;
exception when unique_violation then raise exception 'CONFLICT';
end $$;
create function public.get_listing_command_result(p_command text,p_key text)
returns jsonb language sql stable security definer set search_path='' as $$
  select r.result_json from public.command_receipts r join public.listings l
    on l.id=(r.result_json->'data'->>'id')::uuid join public.materials m on m.id=l.material_id
  where r.actor_id=auth.uid() and m.owner_id=auth.uid() and l.created_by=auth.uid()
    and r.command_name=p_command and r.idempotency_key=p_key
    and p_command in ('listing_draft','listing_publish','listing_hide','listing_show')
$$;

-- Public DTO không dùng raw row Material/QR/holder. URL chỉ được ký sau RPC scoped.
create function studyshare_private.published_listing_json(p_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select l.publication_snapshot||jsonb_build_object('id',l.id,'material_id',l.material_id,
    'published_at',l.published_at,'status','PUBLISHED','revision',l.revision,
    'is_reserved',studyshare_private.listing_active(m.id),
    'is_owner',m.owner_id=auth.uid(),
    'has_pending_request',exists(select 1 from public.exchange_requests r
      where r.listing_id=l.id and r.requester_id=auth.uid() and r.status='PENDING'),
    'is_requestable',m.owner_id<>auth.uid() and m.owner_id=m.holder_id
      and not studyshare_private.listing_active(m.id)
      and not exists(select 1 from public.exchange_requests r where r.listing_id=l.id
        and r.requester_id=auth.uid() and r.status='PENDING'),
    'images',coalesce((select jsonb_agg(jsonb_build_object('id',i.image_id,'display_order',i.display_order)
      order by i.display_order) from public.listing_snapshot_images i where i.listing_id=l.id),'[]'::jsonb))
  from public.listings l join public.materials m on m.id=l.material_id
  where l.id=p_id and l.status='PUBLISHED' and l.publication_snapshot is not null and auth.uid() is not null
$$;
create function public.get_published_listing(p_listing_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  return studyshare_private.published_listing_json(p_listing_id);
end $$;
create function public.search_published_listings(p_keyword text default '',p_offset integer default 0,p_limit integer default 20)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare rows jsonb;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_keyword is null or char_length(p_keyword)>200 or p_offset is null or p_offset<0
    or p_limit is null or p_limit not between 1 and 100 then raise exception 'INVALID_INPUT'; end if;
  select coalesce(jsonb_agg(d order by published_at desc,id),'[]'::jsonb) into rows from (
    select l.id,l.published_at,studyshare_private.published_listing_json(l.id) d from public.listings l
    where l.status='PUBLISHED' and l.publication_snapshot is not null and (trim(p_keyword)=''
      or strpos(lower(l.publication_snapshot->>'title'),lower(trim(p_keyword)))>0
      or strpos(lower(l.publication_snapshot->>'subject'),lower(trim(p_keyword)))>0)
    order by l.published_at desc,l.id offset p_offset limit p_limit+1) q;
  return jsonb_build_object('items',(select coalesce(jsonb_agg(value),'[]'::jsonb)
    from jsonb_array_elements(rows) with ordinality e(value,n) where n<=p_limit),
    'has_more',jsonb_array_length(rows)>p_limit);
end $$;
create function public.get_listing_image_path(p_listing_id uuid,p_image_id uuid)
returns text language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  return (select i.storage_path from public.listing_snapshot_images i join public.listings l on l.id=i.listing_id
    where i.listing_id=p_listing_id and i.image_id=p_image_id and l.status='PUBLISHED');
end $$;
-- B chỉ ký được ảnh thực sự thuộc một snapshot đang PUBLISHED; không mở cả bucket.
create function studyshare_private.can_read_listing_object(p_path text)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(select 1 from public.listing_snapshot_images i
    join public.listings l on l.id=i.listing_id where i.storage_path=p_path and l.status='PUBLISHED')
$$;
create policy material_images_read_published_listing on storage.objects for select to authenticated
  using(bucket_id='studyshare-material-images' and studyshare_private.can_read_listing_object(name));

-- Request/approve tương lai cùng khóa Material với Listing. Không triển khai module Khanh.
create function studyshare_private.guard_listing_request()
returns trigger language plpgsql security definer set search_path='' as $$
declare m public.materials; l public.listings;
begin
  select material_id into m.id from public.listings where id=new.listing_id;
  perform 1 from public.materials where id=m.id for update;
  select * into l from public.listings where id=new.listing_id;
  select * into m from public.materials where id=l.material_id;
  -- Fixture/backend bảo trì vẫn được tạo lịch sử. Mọi RPC gọi dưới JWT mobile đều bị guard.
  if current_setting('role',true)='authenticated' and
    ((tg_op='INSERT' and new.status='PENDING') or
      (tg_op='UPDATE' and new.status='ACCEPTED' and old.status='PENDING')) then
    if l.status<>'PUBLISHED' or m.owner_id<>m.holder_id
      or studyshare_private.listing_active(m.id) then raise exception 'MATERIAL_UNAVAILABLE'; end if;
    if new.requester_id=m.owner_id then raise exception 'FORBIDDEN'; end if;
  end if;
  return new;
end $$;
create trigger listing_request_guard before insert or update of status on public.exchange_requests
  for each row execute function studyshare_private.guard_listing_request();
-- Snapshot thỏa thuận không phụ thuộc metadata hiện tại; giữ terms bổ sung của module Transaction.
create function studyshare_private.snapshot_listing_transaction()
returns trigger language plpgsql security definer set search_path='' as $$
declare snap jsonb;
begin
  perform 1 from public.materials where id=new.material_id for update;
  select publication_snapshot into snap from public.listings where id=new.listing_id;
  if snap is not null then new.terms_snapshot:=new.terms_snapshot||jsonb_build_object('listing',snap);
  end if;
  return new;
end $$;
create trigger listing_transaction_snapshot before insert on public.transactions
  for each row execute function studyshare_private.snapshot_listing_transaction();

revoke all on function studyshare_private.listing_stamp(),studyshare_private.listing_pending(uuid),
  studyshare_private.listing_active(uuid),studyshare_private.listing_json(uuid),
  studyshare_private.capture_listing(uuid),studyshare_private.published_listing_json(uuid),
  studyshare_private.can_read_listing_object(text),studyshare_private.guard_listing_request(),
  studyshare_private.snapshot_listing_transaction() from public,anon,authenticated;
grant execute on function studyshare_private.can_read_listing_object(text) to authenticated;
revoke all on function public.get_my_listing(uuid,uuid),public.search_my_listings(text,text,integer,integer),
  public.save_listing(text,jsonb,text,uuid,uuid,bigint,bigint),public.get_listing_command_result(text,text),
  public.get_published_listing(uuid),public.search_published_listings(text,integer,integer),
  public.get_listing_image_path(uuid,uuid) from public,anon,authenticated;
grant execute on function public.get_my_listing(uuid,uuid),public.search_my_listings(text,text,integer,integer),
  public.save_listing(text,jsonb,text,uuid,uuid,bigint,bigint),public.get_listing_command_result(text,text),
  public.get_published_listing(uuid),public.search_published_listings(text,integer,integer),
  public.get_listing_image_path(uuid,uuid) to authenticated;
