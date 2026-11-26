-- Material ngày 2. Không thay owner/holder, không thay workflow của đồng đội.
alter table public.materials
  add column description text,
  add column updated_at timestamptz not null default now(),
  add column revision bigint not null default 1 check(revision > 0);
alter table public.materials add constraint material_description_length
  check(description is null or char_length(description) <= 2000);
create index materials_owner_created on public.materials(owner_id,created_at desc,id);
create unique index material_image_order on public.material_images(material_id,display_order);

create table public.material_image_uploads (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references auth.users(id),
  target_material_id uuid references public.materials(id),
  storage_path text not null unique,
  mime_type text not null check(mime_type in ('image/jpeg','image/png','image/webp')),
  byte_size integer not null check(byte_size between 1 and 5242880),
  state text not null default 'PENDING' check(state in
    ('PENDING','VERIFIED','ATTACHED','DISCARDED')),
  expires_at timestamptz not null default now()+interval '24 hours',
  created_at timestamptz not null default now()
);
alter table public.material_image_uploads enable row level security;
revoke all on public.material_image_uploads from anon,authenticated;

-- Helpers live in a non-exposed schema. Definer must check actor explicitly.
create schema if not exists studyshare_private;
revoke all on schema studyshare_private from public,anon;
grant usage on schema studyshare_private to authenticated;

create function studyshare_private.material_block(p_id uuid)
returns text language sql stable security definer set search_path=''
as $$
  select case
    when m.owner_id <> auth.uid() then 'FORBIDDEN'
    when exists(select 1 from public.transactions t where t.material_id=m.id
      and t.status not in ('COMPLETED','CANCELLED')) then 'TRANSACTION_ACTIVE'
    when m.holder_id <> m.owner_id then 'NOT_CURRENT_HOLDER'
    when exists(select 1 from public.listings l where l.material_id=m.id
      and l.status='PUBLISHED') then 'LISTING_PUBLISHED'
    when exists(select 1 from public.exchange_requests r join public.listings l
      on l.id=r.listing_id where l.material_id=m.id and r.status='PENDING')
      then 'REQUEST_PENDING'
    else null end
  from public.materials m where m.id=p_id
$$;

create function studyshare_private.valid_isbn(p_value text)
returns boolean language plpgsql immutable set search_path=''
as $$
declare v text:=upper(regexp_replace(coalesce(p_value,''),'[[:space:]-]','','g'));
  s integer:=0;
begin
  if v='' then return true; end if;
  if v ~ '^[0-9]{9}[0-9X]$' then
    for i in 1..10 loop
      s:=s+(11-i)*case when substr(v,i,1)='X' then 10 else substr(v,i,1)::integer end;
    end loop;
    return s%11=0;
  elsif v ~ '^[0-9]{13}$' then
    for i in 1..13 loop
      s:=s+substr(v,i,1)::integer*case when i%2=1 then 1 else 3 end;
    end loop;
    return s%10=0;
  end if;
  return false;
end $$;

create function studyshare_private.material_json(p_id uuid)
returns jsonb language sql stable security definer set search_path=''
as $$
  select to_jsonb(m)||jsonb_build_object(
    'owner_name',(select display_name from public.profiles where user_id=m.owner_id),
    'holder_name',(select display_name from public.profiles where user_id=m.holder_id),
    'listing_status',(select status from public.listings where material_id=m.id
      and status<>'ARCHIVED' limit 1),
    'has_active_transaction',exists(select 1 from public.transactions
      where material_id=m.id and status not in ('COMPLETED','CANCELLED')),
    'edit_blocked_reason',studyshare_private.material_block(m.id),
    'images',coalesce((select jsonb_agg(jsonb_build_object(
      'id',i.id,'storage_path',i.storage_path,'display_order',i.display_order)
      order by i.display_order) from public.material_images i where i.material_id=m.id),'[]'::jsonb)
  ) from public.materials m where m.id=p_id and m.owner_id=auth.uid()
$$;

create function public.get_my_material(p_material_id uuid)
returns jsonb language sql stable security definer set search_path=''
as $$ select studyshare_private.material_json(p_material_id)
  where auth.uid() is not null $$;

create function public.search_my_materials(p_query text default '',
  p_filter text default 'all',p_offset integer default 0,p_limit integer default 20)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare rows jsonb;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_filter not in ('all','ready','active') or p_offset<0
    or p_limit not between 1 and 1000 or char_length(p_query)>200 then
    raise exception 'INVALID_INPUT';
  end if;
  select coalesce(jsonb_agg(d order by created_at desc,id),'[]'::jsonb) into rows from (
    select m.created_at,m.id,studyshare_private.material_json(m.id) d
    from public.materials m
    where m.owner_id=auth.uid() and (
      p_query='' or strpos(lower(m.title),lower(trim(p_query)))>0
      or strpos(lower(coalesce(m.isbn,'')),lower(trim(p_query)))>0)
    and (p_filter='all' or (p_filter='active' and exists(
      select 1 from public.transactions t where t.material_id=m.id
      and t.status not in ('COMPLETED','CANCELLED')))
      or (p_filter='ready' and studyshare_private.material_block(m.id) is null
        and not exists(select 1 from public.listings where material_id=m.id
          and status<>'ARCHIVED')
        and exists(select 1 from public.material_images where material_id=m.id)))
    order by m.created_at desc,m.id offset p_offset limit p_limit+1
  ) q;
  return jsonb_build_object('items',(select coalesce(jsonb_agg(value),'[]'::jsonb)
    from jsonb_array_elements(rows) with ordinality e(value,n) where n<=p_limit),
    'has_more',jsonb_array_length(rows)>p_limit);
end $$;

create function public.prepare_material_image(p_mime_type text,p_byte_size integer,
  p_material_id uuid default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare image_id uuid:=gen_random_uuid(); image_path text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_mime_type not in ('image/jpeg','image/png','image/webp')
    or p_byte_size not between 1 and 5242880 or p_mime_type is null
    or p_byte_size is null then raise exception 'INVALID_INPUT'; end if;
  if p_material_id is not null then
    perform 1 from public.materials where id=p_material_id and owner_id=auth.uid() for update;
    if not found then raise exception 'FORBIDDEN'; end if;
    if studyshare_private.material_block(p_material_id) is not null then
      raise exception 'MATERIAL_UNAVAILABLE';
    end if;
  end if;
  -- Limit abandoned upload reservations per actor.
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':uploads',0));
  if (select count(*) from public.material_image_uploads where actor_id=auth.uid()
    and state in ('PENDING','VERIFIED') and expires_at>now())>=30 then
    raise exception 'CONFLICT';
  end if;
  image_path:=auth.uid()::text||'/'||image_id::text||
    case p_mime_type when 'image/jpeg' then '.jpg'
      when 'image/png' then '.png' else '.webp' end;
  insert into public.material_image_uploads(id,actor_id,target_material_id,
    storage_path,mime_type,byte_size)
  values(image_id,auth.uid(),p_material_id,image_path,p_mime_type,p_byte_size);
  return jsonb_build_object('id',image_id,'storage_path',image_path);
end $$;

-- Only the trusted image verifier can attest actual bytes after download.
create function public.verify_material_image_upload(p_image_id uuid,p_actor_id uuid)
returns void language plpgsql security definer set search_path=''
as $$
declare u public.material_image_uploads;
begin
  select * into u from public.material_image_uploads where id=p_image_id
    and actor_id=p_actor_id for update;
  if not found or u.state not in ('PENDING','VERIFIED') or u.expires_at<=now() then
    raise exception 'FORBIDDEN';
  end if;
  if not exists(select 1 from storage.objects o
    where o.bucket_id='studyshare-material-images' and o.name=u.storage_path
    and (o.metadata->>'size')::bigint=u.byte_size
    and o.metadata->>'mimetype'=u.mime_type) then
    raise exception 'INVALID_INPUT';
  end if;
  update public.material_image_uploads set state='VERIFIED' where id=u.id;
end $$;

create function public.get_my_material_upload(p_image_id uuid)
returns jsonb language sql stable security definer set search_path=''
as $$ select jsonb_build_object('id',id,'storage_path',storage_path,
    'mime_type',mime_type,'byte_size',byte_size) from public.material_image_uploads
  where id=p_image_id and actor_id=auth.uid() and state in ('PENDING','VERIFIED')
    and expires_at>now() $$;

-- Claim discarded uploads before deleting via Storage API. Never SQL-delete objects.
create function public.discard_material_upload(p_image_id uuid)
returns text language plpgsql security definer set search_path=''
as $$
declare u public.material_image_uploads;
begin
  select * into u from public.material_image_uploads where id=p_image_id
    and actor_id=auth.uid() for update;
  if not found or u.state='ATTACHED' then return null; end if;
  update public.material_image_uploads set state='DISCARDED' where id=u.id;
  return u.storage_path;
end $$;

create function public.claim_expired_material_uploads()
returns jsonb language sql security definer set search_path=''
as $$
  with claimed as (
    update public.material_image_uploads set state='DISCARDED'
    where actor_id=auth.uid() and state in ('PENDING','VERIFIED','DISCARDED')
      and expires_at<=now()
    returning storage_path
  ) select coalesce(jsonb_agg(storage_path),'[]'::jsonb) from claimed
$$;

create function public.finish_material_upload_cleanup(p_paths text[])
returns void language sql security definer set search_path=''
as $$ delete from public.material_image_uploads u
  where u.actor_id=auth.uid() and u.state='DISCARDED' and u.storage_path=any(p_paths)
    and not exists(select 1 from storage.objects o
      where o.bucket_id='studyshare-material-images' and o.name=u.storage_path) $$;

create function public.save_material(p_payload jsonb,p_idempotency_key text,
  p_material_id uuid default null,p_expected_revision bigint default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
<<material_command>>
declare actor uuid:=auth.uid(); command text; payload_hash text;
  receipt public.command_receipts; old public.materials; saved public.materials;
  image_id uuid; image_ids uuid[]; u public.material_image_uploads;
  position integer:=0; result jsonb; title text; subject text; condition_text text;
  description_text text; isbn_text text; block text;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_idempotency_key is null or char_length(p_idempotency_key) not between 1 and 128
    or jsonb_typeof(p_payload)<>'object' or p_payload is null then
    raise exception 'INVALID_INPUT';
  end if;
  command:=case when p_material_id is null then 'create_material' else 'update_material' end;
  payload_hash:=md5(jsonb_build_array(p_payload,p_material_id,p_expected_revision)::text);
  perform pg_advisory_xact_lock(hashtextextended(actor::text||command||p_idempotency_key,0));
  select * into receipt from public.command_receipts where actor_id=actor
    and command_name=command and idempotency_key=p_idempotency_key;
  if found then
    if receipt.payload_hash<>payload_hash then raise exception 'CONFLICT'; end if;
    if not exists(select 1 from public.materials
      where id=(receipt.result_json->>'id')::uuid and owner_id=actor) then
      raise exception 'FORBIDDEN';
    end if;
    return receipt.result_json;
  end if;
  -- Reject actor/status and unknown fields; no silent mass assignment.
  if exists(select 1 from jsonb_object_keys(p_payload) k where k not in
    ('title','subject','condition','description','isbn','image_ids')) then
    raise exception 'INVALID_INPUT';
  end if;
  if jsonb_typeof(p_payload->'title') is distinct from 'string'
    or jsonb_typeof(p_payload->'subject') is distinct from 'string'
    or jsonb_typeof(p_payload->'condition') is distinct from 'string'
    or (p_payload ? 'description' and jsonb_typeof(p_payload->'description')
      not in ('null','string'))
    or (p_payload ? 'isbn' and jsonb_typeof(p_payload->'isbn')
      not in ('null','string')) then raise exception 'INVALID_INPUT'; end if;
  title:=trim(p_payload->>'title'); subject:=trim(p_payload->>'subject');
  condition_text:=trim(p_payload->>'condition');
  description_text:=nullif(trim(p_payload->>'description'),'');
  isbn_text:=nullif(upper(regexp_replace(coalesce(p_payload->>'isbn',''),
    '[[:space:]-]','','g')),'');
  if title is null or char_length(title) not between 1 and 200
    or subject is null or char_length(subject) not between 1 and 100
    or condition_text is null or char_length(condition_text) not between 1 and 100
    or char_length(description_text)>2000
    or translate(title||subject||condition_text||coalesce(description_text,''),
      E'\n\r\t','') ~ '[[:cntrl:]]'
    or not studyshare_private.valid_isbn(isbn_text)
    or jsonb_typeof(p_payload->'image_ids') is distinct from 'array' then
    raise exception 'INVALID_INPUT';
  end if;
  begin
    select coalesce(array_agg(value::uuid),'{}'::uuid[]) into image_ids
      from jsonb_array_elements_text(p_payload->'image_ids');
  exception when invalid_text_representation then raise exception 'INVALID_INPUT';
  end;
  if cardinality(image_ids)>5 or array_position(image_ids,null) is not null
    or cardinality(image_ids)<>(select count(distinct x) from unnest(image_ids) x) then
    raise exception 'INVALID_INPUT';
  end if;
  if p_material_id is not null then
    select * into old from public.materials where id=p_material_id and owner_id=actor for update;
    if not found then raise exception 'FORBIDDEN'; end if;
    block:=studyshare_private.material_block(p_material_id);
    if block is not null then raise exception 'MATERIAL_UNAVAILABLE'; end if;
    if p_expected_revision is distinct from old.revision then raise exception 'CONFLICT'; end if;
  end if;
  -- Lock all upload rows in a deterministic order before consuming them.
  perform 1 from public.material_image_uploads where id=any(image_ids) order by id for update;
  foreach image_id in array image_ids loop
    if exists(select 1 from public.material_images where id=image_id
      and material_id=p_material_id) then continue; end if;
    select * into u from public.material_image_uploads where id=image_id;
    if not found or u.actor_id<>actor or u.state<>'VERIFIED' or u.expires_at<=now()
      or (u.target_material_id is not null and
        u.target_material_id is distinct from p_material_id) then raise exception 'FORBIDDEN'; end if;
    if not exists(select 1 from storage.objects where bucket_id='studyshare-material-images'
      and name=u.storage_path and (metadata->>'size')::bigint=u.byte_size
      and metadata->>'mimetype'=u.mime_type) then raise exception 'INVALID_INPUT'; end if;
  end loop;
  if p_material_id is null then
    insert into public.materials(owner_id,holder_id,title,subject,condition,description,isbn)
    values(actor,actor,title,subject,condition_text,description_text,isbn_text)
    returning * into saved;
  else
    update public.materials set title=material_command.title,subject=material_command.subject,
      condition=condition_text,description=description_text,isbn=isbn_text,
      revision=revision+1,updated_at=clock_timestamp()
      where id=p_material_id returning * into saved;
  end if;
  -- Removed objects remain private for immutable historical snapshots.
  -- Retain upload records; garbage collection must verify snapshot references.
  delete from public.material_images where material_id=saved.id and not(id=any(image_ids));
  update public.material_images set display_order=display_order+100
    where material_id=saved.id;
  foreach image_id in array image_ids loop
    if exists(select 1 from public.material_images where id=image_id and material_id=saved.id) then
      update public.material_images set display_order=position where id=image_id;
    else
      select * into u from public.material_image_uploads where id=image_id;
      insert into public.material_images(id,material_id,storage_path,display_order,uploaded_by)
        values(u.id,saved.id,u.storage_path,position,actor);
      update public.material_image_uploads set state='ATTACHED',
        target_material_id=saved.id where id=u.id;
    end if;
    position:=position+1;
  end loop;
  result:=to_jsonb(saved)||jsonb_build_object('command_id',gen_random_uuid(),
    'server_revision',saved.revision);
  insert into public.command_receipts(actor_id,command_name,idempotency_key,payload_hash,result_json)
    values(actor,command,p_idempotency_key,payload_hash,result);
  return result;
end $$;

create function public.get_material_command_result(p_command text,p_key text)
returns jsonb language sql stable security definer set search_path=''
as $$ select r.result_json from public.command_receipts r
  join public.materials m on m.id=(r.result_json->>'id')::uuid
  where r.actor_id=auth.uid() and m.owner_id=auth.uid()
    and r.command_name=p_command and r.idempotency_key=p_key
    and p_command in ('create_material','update_material') $$;

grant select on public.materials,public.material_images to authenticated;
create policy materials_read_owner on public.materials for select to authenticated
  using(owner_id=(select auth.uid()));
create policy material_images_read_owner on public.material_images for select to authenticated
  using(exists(select 1 from public.materials m where m.id=material_id
    and m.owner_id=(select auth.uid())));

create function studyshare_private.can_read_material_object(p_path text)
returns boolean language sql stable security definer set search_path=''
as $$
  select auth.uid() is not null and (
    exists(select 1 from public.material_images i join public.materials m on m.id=i.material_id
      where i.storage_path=p_path and m.owner_id=auth.uid())
    or exists(select 1 from public.material_image_uploads u
      where u.storage_path=p_path and u.actor_id=auth.uid()
      and u.state in ('PENDING','VERIFIED') and u.expires_at>now()))
$$;
create function studyshare_private.can_upload_material_object(p_path text)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.material_image_uploads u
    where u.storage_path=p_path and u.actor_id=auth.uid()
    and u.state='PENDING' and u.expires_at>now()) $$;
create function studyshare_private.can_delete_material_object(p_path text)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.material_image_uploads u
    where u.storage_path=p_path and u.actor_id=auth.uid() and u.state='DISCARDED'
    and not exists(select 1 from public.material_images i where i.storage_path=p_path)) $$;

drop policy material_images_upload_own_folder on storage.objects;
drop policy material_images_read_own_folder on storage.objects;
create policy material_images_upload_registered on storage.objects for insert to authenticated
  with check(bucket_id='studyshare-material-images'
    and studyshare_private.can_upload_material_object(name));
create policy material_images_read_scoped on storage.objects for select to authenticated
  using(bucket_id='studyshare-material-images' and (
    studyshare_private.can_read_material_object(name)
    or studyshare_private.can_delete_material_object(name)));
create policy material_images_delete_discarded on storage.objects for delete to authenticated
  using(bucket_id='studyshare-material-images'
    and studyshare_private.can_delete_material_object(name));

revoke all on all functions in schema studyshare_private from public,anon,authenticated;
grant execute on function studyshare_private.can_read_material_object(text),
  studyshare_private.can_upload_material_object(text),
  studyshare_private.can_delete_material_object(text) to authenticated;
revoke all on function public.get_my_material(uuid),
  public.search_my_materials(text,text,integer,integer),
  public.prepare_material_image(text,integer,uuid),
  public.get_my_material_upload(uuid),public.discard_material_upload(uuid),
  public.save_material(jsonb,text,uuid,bigint),
  public.verify_material_image_upload(uuid,uuid) from public,anon,authenticated;
grant execute on function public.get_my_material(uuid),
  public.search_my_materials(text,text,integer,integer),
  public.prepare_material_image(text,integer,uuid),
  public.get_my_material_upload(uuid),public.discard_material_upload(uuid),
  public.save_material(jsonb,text,uuid,bigint) to authenticated;
grant execute on function public.verify_material_image_upload(uuid,uuid) to service_role;
revoke all on function public.claim_expired_material_uploads(),
  public.finish_material_upload_cleanup(text[]),
  public.get_material_command_result(text,text) from public,anon,authenticated;
grant execute on function public.claim_expired_material_uploads(),
  public.finish_material_upload_cleanup(text[]),
  public.get_material_command_result(text,text) to authenticated;
