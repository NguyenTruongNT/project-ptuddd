-- Ngày 4: QR Material riêng tư, ổn định và số liệu Home đếm trên server.
-- Migration bổ sung; không viết lại lịch sử migration của các thành viên.
create extension if not exists pgcrypto with schema extensions;

-- Khóa được sinh trong database, không có giá trị bí mật nào nằm trong Git.
-- Cần sao lưu bảng private này cùng dữ liệu: thay khóa sẽ làm mã đã in đổi khác.
create table studyshare_private.material_qr_signing_keys (
  version integer primary key check (version > 0),
  secret bytea not null check (octet_length(secret) = 32),
  created_at timestamptz not null default now()
);
alter table studyshare_private.material_qr_signing_keys enable row level security;
revoke all on studyshare_private.material_qr_signing_keys from public, anon, authenticated;
insert into studyshare_private.material_qr_signing_keys(version, secret)
values (1, extensions.gen_random_bytes(32));

-- Version 0 nhận diện credential cũ chưa có định dạng; tuyệt đối không âm thầm
-- ghi đè token_hash cũ hoặc tự xoay mã khi người dùng tải lại trang.
alter table public.material_qr_credentials add column format_version integer not null default 0;
alter table public.material_qr_credentials add constraint material_qr_version_nonnegative
  check (format_version >= 0);
alter table public.handovers add column qr_mismatch_at timestamptz;

create function studyshare_private.material_qr_payload(p_id uuid, p_version integer)
returns text language sql stable security definer set search_path = '' as $$
  select 'studyshare:material:' || p_version::text || ':' || p_id::text || ':' ||
    encode(extensions.hmac(
      convert_to('studyshare:material:' || p_version::text || ':' || p_id::text, 'UTF8'),
      k.secret, 'sha256'), 'hex')
  from studyshare_private.material_qr_signing_keys k where k.version = p_version;
$$;
revoke all on function studyshare_private.material_qr_payload(uuid, integer)
  from public, anon, authenticated;

create function public.ensure_material_qr(p_material_id text, p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  v_material_id uuid := private.ss_try_uuid(p_material_id);
  credential public.material_qr_credentials%rowtype;
  receipt public.command_receipts%rowtype;
  fingerprint text;
  payload text;
  acknowledgement jsonb;
begin
  if actor is null then raise exception using errcode='P0001', message='AUTH_REQUIRED'; end if;
  if v_material_id is null or p_material_id !~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
     or p_idempotency_key is null or length(p_idempotency_key) not between 1 and 128
     or p_idempotency_key <> btrim(p_idempotency_key) or p_idempotency_key ~ '[[:cntrl:]]' then
    raise exception using errcode='P0001', message='INVALID_INPUT';
  end if;
  -- Khóa cùng ý định trước; khóa Material bảo vệ cả phát hành đồng thời và đổi chủ.
  perform pg_advisory_xact_lock(hashtextextended(actor::text || ':ensure_material_qr:' || p_idempotency_key, 0));
  perform 1 from public.materials m where m.id=v_material_id and m.owner_id=actor for update;
  if not found then raise exception using errcode='P0001', message='FORBIDDEN'; end if;
  -- Luôn kiểm tra owner hiện tại TRƯỚC receipt: chủ cũ không được replay lấy mã.
  fingerprint := md5(v_material_id::text);
  select * into receipt from public.command_receipts r
    where r.actor_id=actor and r.command_name='ensure_material_qr' and r.idempotency_key=p_idempotency_key;
  if found and receipt.payload_hash <> fingerprint then
    raise exception using errcode='P0001', message='CONFLICT';
  end if;
  select * into credential from public.material_qr_credentials q where q.material_id=v_material_id;
  if not found then
    payload := studyshare_private.material_qr_payload(v_material_id, 1);
    insert into public.material_qr_credentials(material_id, token_hash, format_version)
      values (v_material_id, encode(extensions.digest(payload, 'sha256'), 'hex'), 1)
      returning * into credential;
  end if;
  payload := studyshare_private.material_qr_payload(v_material_id, credential.format_version);
  if payload is null or credential.token_hash <> encode(extensions.digest(payload, 'sha256'), 'hex') then
    -- Credential cũ/khóa bị mất phải được phục hồi có kiểm soát, không tự đổi QR.
    raise exception using errcode='P0001', message='BACKEND_UNAVAILABLE';
  end if;
  if receipt.actor_id is null then
    acknowledgement := jsonb_build_object('command_id', gen_random_uuid(),
      'server_revision', credential.format_version, 'material_id', v_material_id);
    insert into public.command_receipts(actor_id, command_name, idempotency_key, payload_hash, result_json)
      values (actor, 'ensure_material_qr', p_idempotency_key, fingerprint, acknowledgement);
  else
    acknowledgement := receipt.result_json;
  end if;
  -- Receipt chỉ giữ tham chiếu, không lưu payload QR hay khóa ký trong result_json.
  return acknowledgement || jsonb_build_object('ok', true, 'data', jsonb_build_object(
    'material_id', v_material_id, 'kind', 'MATERIAL', 'version', credential.format_version,
    'title', (select m.title from public.materials m where m.id=v_material_id), 'payload', payload, 'issued_at', credential.created_at));
end $$;
revoke all on function public.ensure_material_qr(text, text) from public, anon;
grant execute on function public.ensure_material_qr(text, text) to authenticated;

create function public.get_home_overview()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if actor is null then raise exception using errcode='P0001', message='AUTH_REQUIRED'; end if;
  -- Đếm toàn bộ phạm vi được phép; không suy tổng từ trang Material/Listing đầu.
  return jsonb_build_object(
    'material_count', (select count(*) from public.materials where owner_id=actor),
    'published_count', (select count(*) from public.listings l join public.materials m on m.id=l.material_id
      where m.owner_id=actor and l.created_by=actor and l.status='PUBLISHED'),
    'draft_count', (select count(*) from public.listings l join public.materials m on m.id=l.material_id
      where m.owner_id=actor and l.created_by=actor and l.status='DRAFT'),
    'hidden_count', (select count(*) from public.listings l join public.materials m on m.id=l.material_id
      where m.owner_id=actor and l.created_by=actor and l.status='HIDDEN'),
    'active_transaction_count', (select count(*) from public.transactions t
      where actor in (t.owner_at_acceptance,t.receiver_id) and t.status not in ('COMPLETED','CANCELLED')),
    'server_at', now());
end $$;
revoke all on function public.get_home_overview() from public, anon;
grant execute on function public.get_home_overview() to authenticated;

-- Policy Storage được đánh giá cùng các bucket khác. Không SELECT bảng nghiệp
-- vụ bằng quyền app (các bảng này đã bị khóa); chỉ trả boolean trong phạm vi JWT.
create function studyshare_private.can_read_handover_object(p_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and (
    split_part(p_path,'/',1)=auth.uid()::text or exists (
      select 1 from public.handover_evidence e
      join public.handovers h on h.id=e.handover_id
      join public.transactions t on t.id=h.transaction_id
      where e.private_path=p_path
        and auth.uid() in (h.from_user_id,h.to_user_id,t.owner_at_acceptance,t.receiver_id)
    ));
$$;
revoke all on function studyshare_private.can_read_handover_object(text) from public, anon;
grant execute on function studyshare_private.can_read_handover_object(text) to authenticated;
drop policy handover_evidence_read_authorized on storage.objects;
create policy handover_evidence_read_authorized on storage.objects for select to authenticated
  using (bucket_id='studyshare-handover-evidence'
    and studyshare_private.can_read_handover_object(name));

-- Cờ mismatch nằm ở server để mở lại màn hình hay đổi idempotency key cũng
-- không cho dùng fallback vượt qua một lần đọc được mã sai.
create function studyshare_private.guard_qr_mismatch()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.qr_mismatch_at is not null and
     (new.verification_method is not null or new.status in ('AWAITING_RECEIVER_CONFIRMATION','CONFIRMED')) then
    raise exception using errcode='P0001', message='QR_MISMATCH';
  end if;
  return new;
end $$;
revoke all on function studyshare_private.guard_qr_mismatch() from public, anon, authenticated;
create trigger handover_qr_mismatch_guard before insert or update on public.handovers
  for each row execute function studyshare_private.guard_qr_mismatch();

create or replace function private.ss_handover_json(p_handover_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id',h.id,'transaction_id',h.transaction_id,
    'delivery_task_id',h.delivery_task_id,'from_user_id',h.from_user_id,'to_user_id',h.to_user_id,
    'status',h.status,'verification_method',h.verification_method,
    'qr_mismatch_blocked',h.qr_mismatch_at is not null,
    'evidence_photo_count',(select count(*) from public.handover_evidence e where e.handover_id=h.id),
    'created_at',h.created_at,'confirmed_at',h.confirmed_at)
  from public.handovers h where h.id=p_handover_id;
$$;

create or replace function public.verify_material_code(
  p_handover_id text, p_scanned_code text, p_verification_method text,
  p_fallback_reason text, p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  handover_id uuid := private.ss_try_uuid(p_handover_id);
  method text := upper(btrim(coalesce(p_verification_method,'')));
  code text := coalesce(p_scanned_code,'');
  reason text := btrim(coalesce(p_fallback_reason,''));
  h public.handovers%rowtype;
  t public.transactions%rowtype;
  credential public.material_qr_credentials%rowtype;
  receipt public.command_receipts%rowtype;
  fingerprint text;
  event_id uuid;
begin
  if actor is null then return private.ss_err('AUTH_REQUIRED','Vui lòng đăng nhập.'); end if;
  if handover_id is null or p_idempotency_key is null or length(p_idempotency_key) not between 1 and 128
    or p_idempotency_key <> btrim(p_idempotency_key) or p_idempotency_key ~ '[[:cntrl:]]'
    or method not in ('QR','FALLBACK') or length(code)>512 or length(reason)>1000
    or reason ~ '[[:cntrl:]]' then
    return private.ss_err('INVALID_INPUT','Thông tin đối chiếu không hợp lệ.');
  end if;
  -- Giữ thứ tự khóa Handover như RPC giao nhận hiện có; lệnh này không đổi
  -- holder/owner/trạng thái Transaction, các lệnh ACK vẫn tự kiểm tra lại.
  perform pg_advisory_xact_lock(hashtextextended(actor::text || ':verify_material_code:' || p_idempotency_key,0));
  select * into h from public.handovers where id=handover_id for update;
  if not found or h.from_user_id<>actor then
    return private.ss_err('INVALID_HANDOVER_PARTICIPANT','Chỉ người giao của chặng được đối chiếu.');
  end if;
  select * into t from public.transactions where id=h.transaction_id;
  if t.status in ('COMPLETED','CANCELLED') then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION','Giao dịch đã kết thúc.');
  end if;
  if t.type='SELL' and not exists(select 1 from public.payment_confirmations p
      where p.transaction_id=t.id and p.seller_confirmed_at is not null) then
    return private.ss_err('PAYMENT_NOT_CONFIRMED','Người bán chưa xác nhận tiền.');
  end if;
  fingerprint := private.ss_payload_hash('verify_material_code',handover_id::text,method||'|'||code||'|'||reason);
  select * into receipt from public.command_receipts r where r.actor_id=actor
    and r.command_name='verify_material_code' and r.idempotency_key=p_idempotency_key;
  if found then
    if receipt.payload_hash<>fingerprint then return private.ss_err('CONFLICT','Ý định thao tác đã thay đổi.'); end if;
    -- Mismatch phát sinh sau một lần verify cũ phải thắng kết quả replay cũ.
    if h.qr_mismatch_at is not null then return private.ss_err('QR_MISMATCH','Hãy đối chiếu lại đúng mã tài liệu.'); end if;
    return private.ss_ok(private.ss_handover_json(h.id),receipt.result_json->>'event_id');
  end if;
  if h.status<>'PENDING' then return private.ss_err('INVALID_TRANSACTION_TRANSITION','Lượt bàn giao không còn chờ đối chiếu.'); end if;
  if method='QR' then
    if code='' then return private.ss_err('INVALID_INPUT','Chưa có mã đã đọc.'); end if;
    select * into credential from public.material_qr_credentials q where q.material_id=t.material_id;
    if credential.material_id is null then
      return private.ss_err('BACKEND_UNAVAILABLE','Chủ sở hữu cần phát hành QR tài liệu trước.');
    end if;
    if credential.format_version<>1 then
      return private.ss_err('BACKEND_UNAVAILABLE','QR cũ cần được phục hồi trước khi đối chiếu.');
    end if;
    if code !~ '^studyshare:material:1:[0-9a-f-]{36}:[0-9a-f]{64}$'
       or split_part(code,':',4)<>t.material_id::text
       or credential.token_hash<>encode(extensions.digest(code,'sha256'),'hex') then
      update public.handovers set qr_mismatch_at=coalesce(qr_mismatch_at,clock_timestamp()),
        verification_method=null,fallback_reason=null where id=h.id;
      return private.ss_err('QR_MISMATCH','Mã đã đọc không khớp; không được chuyển sang thủ công.');
    end if;
    -- Chỉ quét lại đúng credential mới gỡ mismatch; fallback không được gỡ cờ.
    update public.handovers set verification_method='QR',fallback_reason=null,qr_mismatch_at=null where id=h.id;
  else
    if h.qr_mismatch_at is not null then return private.ss_err('QR_MISMATCH','Không thể dùng thủ công sau khi đọc sai mã.'); end if;
    if reason='' or code<>'' then return private.ss_err('INVALID_INPUT','Đối chiếu thủ công cần lý do và không nhận mã đã quét.'); end if;
    update public.handovers set verification_method='FALLBACK',fallback_reason=reason where id=h.id;
  end if;
  event_id:=private.ss_append_txn_event(t.id,actor,'HANDOVER_VERIFIED','Đã đối chiếu tài liệu cho lượt bàn giao.');
  perform private.ss_save_receipt(actor,'verify_material_code',p_idempotency_key,fingerprint,event_id,h.id);
  return private.ss_ok(private.ss_handover_json(h.id),event_id::text);
end $$;

notify pgrst, 'reload schema';
