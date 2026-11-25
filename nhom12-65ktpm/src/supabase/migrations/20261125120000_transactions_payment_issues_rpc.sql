-- StudyShare - RPC cho module của Sơn: Transaction/Timeline, thanh toán SELL,
-- hủy giao dịch hai bên đồng thuận và Issue (SS-BR v2.0, CONTRACTS.md §7-8).
--
-- Nguyên tắc:
-- - Client KHÔNG đọc/ghi trực tiếp bảng; mọi đọc qua read model RPC đã lọc
--   theo auth.uid(), mọi ghi qua command RPC nguyên tử.
-- - Actor luôn lấy từ auth.uid(), không nhận actor/owner/holder/status từ payload.
-- - Mỗi lệnh ghi có idempotency key; retry cùng key + payload trả lại kết quả cũ,
--   cùng key nhưng payload khác trả CONFLICT (bảng command_receipts).
-- - Kiểm tra quyền/trạng thái trên dòng đã khóa (FOR UPDATE) TRƯỚC khi ghi.
-- - Không có quyền và không tồn tại trả cùng một lỗi/null, không lộ dữ liệu.
-- - Lỗi nghiệp vụ trả jsonb {ok:false, code, message}; thành công trả
--   {ok:true, event_id, data} với data là snapshot mới nhất cho người gọi.

-- 1. Bảng bổ sung ------------------------------------------------------------

-- Đề nghị hủy đang chờ bên còn lại phản hồi (BR-45). Tối đa một đề nghị mỗi giao dịch.
create table public.transaction_cancellations (
  transaction_id uuid primary key references public.transactions(id),
  proposed_by uuid not null references auth.users(id),
  reason text not null check (char_length(trim(reason)) between 1 and 500),
  proposed_at timestamptz not null default now()
);

-- Phương án giải quyết hiện hành của Issue (resolution_revision/resolution_text đã có).
alter table public.issues
  add column resolution_proposed_by uuid references auth.users(id),
  add column resolution_proposed_at timestamptz;

-- Timeline append-only riêng của Issue (đã loại PII; mô tả nằm trong payload_safe).
create table public.issue_events (
  id uuid primary key default gen_random_uuid(),
  issue_id uuid not null references public.issues(id),
  actor_id uuid references auth.users(id),
  event_type text not null,
  payload_safe jsonb not null default '{}'::jsonb,
  server_at timestamptz not null default now()
);

create index transaction_events_txn_time_idx
  on public.transaction_events(transaction_id, server_at);

create index issue_events_issue_time_idx
  on public.issue_events(issue_id, server_at);

create index issues_transaction_idx on public.issues(transaction_id);

alter table public.transaction_cancellations enable row level security;

alter table public.issue_events enable row level security;

revoke all on table public.transaction_cancellations from anon, authenticated;

revoke all on table public.issue_events from anon, authenticated;

-- 2. Schema nội bộ: không được PostgREST phơi ra, client không gọi trực tiếp ---
create schema if not exists private;

revoke all on schema private from public, anon, authenticated;

create or replace function private.ss_try_uuid(p_raw text)
returns uuid language plpgsql immutable set search_path = '' as $$
begin
  return p_raw::uuid;
exception when others then
  return null; -- ID lạ được coi như không tồn tại.
end $$;

create or replace function private.ss_display_name(p_user uuid)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select p.display_name from public.profiles p where p.user_id = p_user),
    'Người dùng');
$$;

create or replace function private.ss_err(p_code text, p_message text)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object('ok', false, 'code', p_code, 'message', p_message);
$$;

create or replace function private.ss_ok(p_data jsonb, p_event_id text)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object('ok', true, 'event_id', p_event_id, 'data', p_data);
$$;

create or replace function private.ss_payload_hash(
  p_command text, p_entity text, p_payload text)
returns text language sql immutable set search_path = '' as $$
  select md5(p_command || '|' || p_entity || '|' || coalesce(p_payload, ''));
$$;

-- Ghi TransactionEvent; clock_timestamp() để nhiều sự kiện trong cùng lệnh
-- vẫn có thứ tự ổn định.
create or replace function private.ss_append_txn_event(
  p_transaction_id uuid, p_actor uuid, p_event_type text,
  p_description text, p_source text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  insert into public.transaction_events(
    transaction_id, actor_id, event_type, payload_safe, server_at, source_action_id)
  values (
    p_transaction_id, p_actor, p_event_type,
    jsonb_build_object('safe_description', p_description),
    clock_timestamp(), coalesce(p_source, gen_random_uuid()::text))
  returning id into v_id;
  return v_id;
end $$;

create or replace function private.ss_append_issue_event(
  p_issue_id uuid, p_actor uuid, p_event_type text, p_description text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  insert into public.issue_events(issue_id, actor_id, event_type, payload_safe, server_at)
  values (p_issue_id, p_actor, p_event_type,
    jsonb_build_object('safe_description', p_description), clock_timestamp())
  returning id into v_id;
  return v_id;
end $$;

create or replace function private.ss_save_receipt(
  p_actor uuid, p_command text, p_key text, p_hash text,
  p_event_id uuid, p_entity_id uuid)
returns void language sql security definer set search_path = '' as $$
  insert into public.command_receipts(
    actor_id, command_name, idempotency_key, payload_hash, result_json)
  values (p_actor, p_command, p_key, p_hash,
    jsonb_build_object('event_id', p_event_id, 'entity_id', p_entity_id));
$$;

-- 3. Quy tắc dùng chung ------------------------------------------------------

-- BR-34: CANCELLED không nhận Issue; COMPLETED chỉ trong 7 ngày lịch Việt Nam
-- (hết ngày thứ 7) tính từ lúc hoàn tất; các trạng thái khác luôn mở.
create or replace function private.ss_issue_window_open(p_transaction_id uuid)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare
  t public.transactions;
  v_ref timestamptz;
begin
  select * into t from public.transactions where id = p_transaction_id;
  if not found or t.status = 'CANCELLED' then return false; end if;
  if t.status <> 'COMPLETED' then return true; end if;
  -- Mở Issue không được tự kéo dài hạn: bỏ qua các sự kiện ISSUE_*.
  v_ref := coalesce(t.completed_at, (
    select max(e.server_at) from public.transaction_events e
    where e.transaction_id = t.id and left(e.event_type, 6) <> 'ISSUE_'));
  if v_ref is null then return true; end if;
  return (now() at time zone 'Asia/Ho_Chi_Minh')::date
      <= (v_ref at time zone 'Asia/Ho_Chi_Minh')::date + 7;
end $$;

-- Hai đầu của chặng bàn giao mà Issue gắn vào; rỗng nếu không thuộc giao dịch.
create or replace function private.ss_handover_parties(
  p_transaction_id uuid, p_handover_id uuid)
returns uuid[] language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select array[h.from_user_id, h.to_user_id] from public.handovers h
      where h.id = p_handover_id and h.transaction_id = p_transaction_id),
    '{}'::uuid[]);
$$;

-- Bên bị ảnh hưởng trực tiếp (thứ tự ổn định): hai đầu chặng nếu Issue gắn
-- chặng, ngược lại A và B; luôn gồm người báo.
create or replace function private.ss_issue_parties(p_issue_id uuid)
returns uuid[] language plpgsql stable security definer set search_path = '' as $$
declare
  i public.issues;
  t public.transactions;
  v uuid[];
begin
  select * into i from public.issues where id = p_issue_id;
  if not found then return '{}'::uuid[]; end if;
  select * into t from public.transactions where id = i.transaction_id;
  v := private.ss_handover_parties(t.id, i.handover_id);
  if cardinality(v) = 0 then
    v := array[t.owner_at_acceptance, t.receiver_id];
  end if;
  if not (i.reporter_id = any(v)) then
    v := array_append(v, i.reporter_id);
  end if;
  return v;
end $$;

-- Nghĩa vụ còn mở chặn việc hủy (SS-BR §10); null khi được hủy.
create or replace function private.ss_cancellation_blocker(p_transaction_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  t public.transactions;
  v_holder uuid;
begin
  select * into t from public.transactions where id = p_transaction_id;
  if exists (select 1 from public.issues i
             where i.transaction_id = t.id and i.status = 'OPEN') then
    return private.ss_err('ISSUE_BLOCKING_ACTION',
      'Còn sự cố đang mở. Hãy giải quyết sự cố trước khi hủy.');
  end if;
  if exists (select 1 from public.handovers h
             where h.transaction_id = t.id
               and h.status in ('PENDING', 'AWAITING_RECEIVER_CONFIRMATION'))
     or exists (select 1 from public.delivery_tasks d
             where d.transaction_id = t.id
               and d.status not in ('COMPLETED', 'FAILED', 'CANCELLED')) then
    return private.ss_err('CANCELLATION_OBLIGATION_PENDING',
      'Còn lượt bàn giao hoặc nhiệm vụ giao hộ chưa kết thúc.');
  end if;
  select m.holder_id into v_holder from public.materials m where m.id = t.material_id;
  if v_holder is distinct from t.owner_at_acceptance then
    return private.ss_err('CANCELLATION_OBLIGATION_PENDING',
      'Tài liệu chưa được trả về người đăng.');
  end if;
  if t.type = 'SELL' and exists (
      select 1 from public.payment_confirmations p
      where p.transaction_id = t.id
        and p.seller_confirmed_at is not null
        and p.buyer_refund_confirmed_at is null) then
    return private.ss_err('CANCELLATION_OBLIGATION_PENDING',
      'Người mua chưa xác nhận đã nhận lại tiền.');
  end if;
  return null;
end $$;

-- 4. Read model --------------------------------------------------------------

-- TransactionDetails cho người xem; null khi người xem không phải A hoặc B.
-- allowedActions chỉ là GỢI Ý cho UI; command RPC luôn kiểm tra lại.
create or replace function private.ss_transaction_json(
  p_transaction_id uuid, p_viewer uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  t public.transactions;
  m public.materials;
  p public.payment_confirmations;
  b public.borrowing_records;
  c public.transaction_cancellations;
  v_is_owner boolean;
  v_seller_confirmed boolean;
  v_actions text[] := '{}'::text[];
begin
  select * into t from public.transactions where id = p_transaction_id;
  if not found or p_viewer is null
     or p_viewer not in (t.owner_at_acceptance, t.receiver_id) then
    return null; -- C không xem toàn bộ Transaction chỉ vì là courier.
  end if;
  select * into m from public.materials where id = t.material_id;
  select * into p from public.payment_confirmations where transaction_id = t.id;
  select * into b from public.borrowing_records where transaction_id = t.id;
  select * into c from public.transaction_cancellations where transaction_id = t.id;
  v_is_owner := t.owner_at_acceptance = p_viewer;
  v_seller_confirmed := p.seller_confirmed_at is not null;

  if t.status in ('COMPLETED', 'CANCELLED') then
    -- BR-34: sau COMPLETED vẫn được báo sự cố trong hạn 7 ngày lịch VN.
    if t.status = 'COMPLETED' and private.ss_issue_window_open(t.id) then
      v_actions := array['CAN_REPORT_ISSUE'];
    end if;
  else
    v_actions := array['CAN_REPORT_ISSUE'];
    if c.transaction_id is null then
      v_actions := array_append(v_actions, 'CAN_PROPOSE_CANCELLATION');
    elsif c.proposed_by = p_viewer then
      v_actions := array_append(v_actions, 'CAN_WITHDRAW_CANCELLATION');
    else
      v_actions := array_append(v_actions, 'CAN_RESPOND_CANCELLATION');
    end if;

    if t.type = 'SELL' then
      if t.status = 'AWAITING_PAYMENT' then
        -- Chỉ A xác nhận tiền; B chỉ được báo đã chuyển khoản.
        if v_is_owner then
          v_actions := array_append(v_actions, 'CAN_CONFIRM_SELLER_PAYMENT');
        elsif p.buyer_reported_at is null then
          v_actions := array_append(v_actions, 'CAN_REPORT_BUYER_TRANSFER');
        end if;
      end if;
      -- BR-29: không có Handover SELL nào trước khi A xác nhận tiền.
      if v_seller_confirmed and t.status = 'AWAITING_HANDOVER' and v_is_owner then
        v_actions := array_append(v_actions, 'CAN_START_HANDOVER');
      end if;
      -- Hoàn tiền chỉ phát sinh khi đang đề nghị hủy SELL đã nhận tiền.
      if c.transaction_id is not null and v_seller_confirmed then
        if v_is_owner and p.refund_proposed_at is null then
          v_actions := array_append(v_actions, 'CAN_REPORT_SELLER_REFUND');
        end if;
        if not v_is_owner and p.refund_proposed_at is not null
           and p.buyer_refund_confirmed_at is null then
          v_actions := array_append(v_actions, 'CAN_CONFIRM_REFUND_RECEIVED');
        end if;
      end if;
    elsif t.type = 'DONATE' then
      if t.status = 'AWAITING_HANDOVER' and v_is_owner then
        v_actions := array_append(v_actions, 'CAN_START_HANDOVER');
      end if;
    else -- BORROW
      if t.status = 'AWAITING_HANDOVER' and v_is_owner then
        v_actions := array_append(v_actions, 'CAN_START_HANDOVER');
      end if;
      if t.status = 'BORROWING' and not v_is_owner then
        v_actions := array_append(v_actions, 'CAN_REQUEST_RETURN');
      end if;
      -- Chiều trả: B đang giữ sách nên B mở chặng trả.
      if t.status = 'RETURN_PENDING' and not v_is_owner then
        v_actions := array_append(v_actions, 'CAN_START_HANDOVER');
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'transaction', jsonb_build_object(
      'id', t.id,
      'listingId', t.listing_id,
      'requestId', t.request_id,
      'materialId', t.material_id,
      'type', t.type,
      'ownerAtAcceptance', t.owner_at_acceptance,
      'receiverId', t.receiver_id,
      'status', t.status,
      'agreedBorrowDays', t.agreed_borrow_days,
      'agreedPriceVnd', t.agreed_price_vnd),
    'materialTitle', coalesce(m.title, 'Tài liệu'),
    'materialSubject', coalesce(m.subject, ''),
    'ownerDisplayName', private.ss_display_name(t.owner_at_acceptance),
    'receiverDisplayName', private.ss_display_name(t.receiver_id),
    'viewerRole', case when v_is_owner then 'OWNER' else 'RECEIVER' end,
    'createdAt', t.created_at,
    'borrowing', case when t.type = 'BORROW' and b.transaction_id is not null then
      jsonb_build_object(
        'transactionId', b.transaction_id,
        'startedAt', b.started_at,
        'dueDateVn', to_char(b.due_date, 'YYYY-MM-DD'),
        'returnToCourierAt', b.return_to_courier_at,
        'reHandoverDueDateVn', to_char(b.re_handover_due_date, 'YYYY-MM-DD'))
      end,
    'payment', case when t.type = 'SELL' and p.transaction_id is not null then
      jsonb_build_object(
        'transactionId', p.transaction_id,
        'buyerReportedAt', p.buyer_reported_at,
        'sellerConfirmedAt', p.seller_confirmed_at,
        'refundReportedAt', p.refund_proposed_at,
        'buyerRefundConfirmedAt', p.buyer_refund_confirmed_at)
      end,
    'openIssueCount', (select count(*) from public.issues i
                       where i.transaction_id = t.id and i.status = 'OPEN'),
    'cancellationProposal', case when c.transaction_id is not null then
      jsonb_build_object(
        'proposedBy', case when c.proposed_by = t.owner_at_acceptance
                           then 'OWNER' else 'RECEIVER' end,
        'reason', c.reason,
        'proposedAt', c.proposed_at)
      end,
    'allowedActions', to_jsonb(v_actions));
end $$;

-- IssueDetails cho người xem; null khi không có quyền đọc.
-- Đọc: A/B của giao dịch + bên bị ảnh hưởng trực tiếp (vd. C ở đúng chặng).
-- Thao tác: chỉ bên bị ảnh hưởng trực tiếp.
create or replace function private.ss_issue_json(p_issue_id uuid, p_viewer uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  i public.issues;
  t public.transactions;
  v_parties uuid[];
  v_is_txn_party boolean;
  v_counterparty uuid;
  v_proposal jsonb;
  v_actions text[] := '{}'::text[];
begin
  select * into i from public.issues where id = p_issue_id;
  if not found or p_viewer is null then return null; end if;
  select * into t from public.transactions where id = i.transaction_id;
  v_parties := private.ss_issue_parties(i.id);
  v_is_txn_party := p_viewer in (t.owner_at_acceptance, t.receiver_id);
  if not (v_is_txn_party or p_viewer = any(v_parties)) then
    return null; -- Không lộ dữ liệu, không phân biệt với "không tồn tại".
  end if;

  select x.u into v_counterparty
    from unnest(v_parties) with ordinality as x(u, ord)
    where x.u <> i.reporter_id order by x.ord limit 1;

  if i.resolution_revision > 0 then
    v_proposal := jsonb_build_object(
      'revision', i.resolution_revision,
      'summary', i.resolution_text,
      'proposedByDisplayName', private.ss_display_name(i.resolution_proposed_by),
      'proposedAt', i.resolution_proposed_at,
      'consents', (
        select coalesce(jsonb_agg(jsonb_build_object(
            'participantDisplayName', private.ss_display_name(x.u),
            'approvedAt', ic.approved_at) order by x.ord), '[]'::jsonb)
        from unnest(v_parties) with ordinality as x(u, ord)
        left join public.issue_consents ic
          on ic.issue_id = i.id and ic.participant_id = x.u
         and ic.resolution_revision = i.resolution_revision));
  end if;

  if i.status = 'OPEN' and p_viewer = any(v_parties) then
    v_actions := array['CAN_PROPOSE_ISSUE_RESOLUTION'];
    if i.resolution_revision > 0 and not exists (
        select 1 from public.issue_consents ic
        where ic.issue_id = i.id and ic.participant_id = p_viewer
          and ic.resolution_revision = i.resolution_revision) then
      v_actions := array_append(v_actions, 'CAN_CONFIRM_ISSUE_RESOLUTION');
    end if;
  end if;

  return jsonb_build_object(
    'issue', jsonb_build_object(
      'id', i.id,
      'transactionId', i.transaction_id,
      'reporterId', i.reporter_id,
      'type', i.issue_type,
      'reason', i.reason,
      'handoverId', i.handover_id,
      'status', i.status,
      'openedAt', i.opened_at,
      'resolvedAt', i.resolved_at),
    'materialTitle', coalesce(
      (select m.title from public.materials m where m.id = t.material_id), 'Tài liệu'),
    'reporterDisplayName', private.ss_display_name(i.reporter_id),
    'counterpartyDisplayName',
      private.ss_display_name(coalesce(v_counterparty, i.reporter_id)),
    'relation', case when i.reporter_id = p_viewer then 'REPORTER' else 'COUNTERPARTY' end,
    'proposal', v_proposal,
    -- Ảnh bằng chứng thuộc module Handover (signed URL); chưa mở ở đây.
    'evidenceCount', 0,
    'canViewEvidence', false,
    'canViewTransaction', v_is_txn_party,
    'allowedActions', to_jsonb(v_actions));
end $$;

create or replace function private.ss_event_json(
  p_id uuid, p_owner_key text, p_owner_id uuid, p_actor uuid,
  p_event_type text, p_payload jsonb, p_server_at timestamptz)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', p_id,
    p_owner_key, p_owner_id,
    'eventType', p_event_type,
    'serverAt', p_server_at,
    'safeDescription', coalesce(p_payload->>'safe_description', p_event_type),
    'actorDisplay', case when p_actor is null then null
                         else private.ss_display_name(p_actor) end);
$$;

-- 5. RPC đọc (public, chỉ authenticated) -------------------------------------

create or replace function public.get_my_transactions()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(
      private.ss_transaction_json(t.id, auth.uid()) order by t.created_at desc),
    '[]'::jsonb)
  from public.transactions t
  where auth.uid() is not null
    and auth.uid() in (t.owner_at_acceptance, t.receiver_id);
$$;

create or replace function public.get_transaction_details(p_transaction_id text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select private.ss_transaction_json(private.ss_try_uuid(p_transaction_id), auth.uid());
$$;

create or replace function public.get_transaction_timeline(p_transaction_id text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_id uuid := private.ss_try_uuid(p_transaction_id);
begin
  if private.ss_transaction_json(v_id, auth.uid()) is null then
    return '[]'::jsonb; -- Không có quyền -> không trả gì.
  end if;
  return (
    select coalesce(jsonb_agg(private.ss_event_json(
        e.id, 'transactionId', e.transaction_id, e.actor_id,
        e.event_type, e.payload_safe, e.server_at)
      order by e.server_at, e.id), '[]'::jsonb)
    from public.transaction_events e where e.transaction_id = v_id);
end $$;

create or replace function public.get_my_issues()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x.details order by x.opened_at desc), '[]'::jsonb)
  from (
    select private.ss_issue_json(i.id, auth.uid()) as details, i.opened_at
    from public.issues i
  ) x
  where x.details is not null;
$$;

create or replace function public.get_issue_details(p_issue_id text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select private.ss_issue_json(private.ss_try_uuid(p_issue_id), auth.uid());
$$;

create or replace function public.get_issue_timeline(p_issue_id text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_id uuid := private.ss_try_uuid(p_issue_id);
begin
  if private.ss_issue_json(v_id, auth.uid()) is null then
    return '[]'::jsonb;
  end if;
  return (
    select coalesce(jsonb_agg(private.ss_event_json(
        e.id, 'issueId', e.issue_id, e.actor_id,
        e.event_type, e.payload_safe, e.server_at)
      order by e.server_at, e.id), '[]'::jsonb)
    from public.issue_events e where e.issue_id = v_id);
end $$;

-- 6. Khung lệnh Transaction --------------------------------------------------

-- Chuẩn bị lệnh trên một Transaction: kiểm tra session, key, quyền A/B,
-- khóa dòng giao dịch và kiểm tra idempotency. Trả jsonb khi phải dừng sớm
-- (lỗi hoặc retry đã có kết quả), null khi được chạy tiếp.
create or replace function private.ss_begin_txn_command(
  p_command text, p_transaction_id text, p_key text, p_payload text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_id uuid := private.ss_try_uuid(p_transaction_id);
  t public.transactions;
  r public.command_receipts;
begin
  if v_actor is null then
    return private.ss_err('AUTH_REQUIRED', 'Phiên đăng nhập đã hết hạn.');
  end if;
  if p_key is null or trim(p_key) = '' then
    return private.ss_err('INVALID_INPUT', 'Thiếu mã thao tác, vui lòng thử lại.');
  end if;
  select * into t from public.transactions where id = v_id for update;
  if not found or v_actor not in (t.owner_at_acceptance, t.receiver_id) then
    return private.ss_err('FORBIDDEN', 'Bạn không có quyền thực hiện thao tác này.');
  end if;
  select * into r from public.command_receipts
   where actor_id = v_actor and command_name = p_command and idempotency_key = p_key;
  if found then
    if r.payload_hash <> private.ss_payload_hash(p_command, v_id::text, p_payload) then
      return private.ss_err('CONFLICT', 'Mã thao tác đã được dùng cho nội dung khác.');
    end if;
    -- Retry sau timeout: trả snapshot hiện tại + event cũ, không ghi lần hai.
    return private.ss_ok(private.ss_transaction_json(v_id, v_actor),
                         r.result_json->>'event_id');
  end if;
  return null;
end $$;

-- Ghi receipt + trả snapshot sau lệnh Transaction thành công.
create or replace function private.ss_finish_txn_command(
  p_command text, p_transaction_id uuid, p_key text, p_payload text, p_event_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  perform private.ss_save_receipt(auth.uid(), p_command, p_key,
    private.ss_payload_hash(p_command, p_transaction_id::text, p_payload),
    p_event_id, p_transaction_id);
  return private.ss_ok(private.ss_transaction_json(p_transaction_id, auth.uid()),
                       p_event_id::text);
end $$;

create or replace function private.ss_source(p_command text, p_key text)
returns text language sql stable set search_path = '' as $$
  select auth.uid()::text || ':' || p_command || ':' || p_key;
$$;

-- 7. Thanh toán SELL (BR-25..29). Tiền chuyển NGOÀI ứng dụng. ----------------

create or replace function public.report_buyer_transfer(
  p_transaction_id text, p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'report_buyer_transfer';
  v_early jsonb;
  t public.transactions;
  p public.payment_confirmations;
  v_event uuid;
begin
  v_early := private.ss_begin_txn_command(c_cmd, p_transaction_id, p_idempotency_key, '');
  if v_early is not null then return v_early; end if;
  select * into t from public.transactions where id = p_transaction_id::uuid;
  if t.type <> 'SELL' then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Giao dịch này không có thanh toán.');
  end if;
  if t.receiver_id <> auth.uid() then
    return private.ss_err('FORBIDDEN', 'Chỉ người mua được báo đã chuyển khoản.');
  end if;
  if t.status <> 'AWAITING_PAYMENT' then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION',
      'Giao dịch không còn ở bước chờ thanh toán.');
  end if;
  select * into p from public.payment_confirmations where transaction_id = t.id for update;
  if p.buyer_reported_at is not null then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Bạn đã báo chuyển khoản trước đó.');
  end if;

  -- Chỉ ghi buyer_reported_at; Transaction vẫn AWAITING_PAYMENT.
  insert into public.payment_confirmations(transaction_id, amount_vnd, buyer_reported_at)
  values (t.id, t.agreed_price_vnd, now())
  on conflict (transaction_id) do update set buyer_reported_at = excluded.buyer_reported_at;
  v_event := private.ss_append_txn_event(t.id, auth.uid(), 'PAYMENT_REPORTED',
    'Người mua báo đã chuyển khoản. Chờ người bán kiểm tra và xác nhận.',
    private.ss_source(c_cmd, p_idempotency_key));
  return private.ss_finish_txn_command(c_cmd, t.id, p_idempotency_key, '', v_event);
end $$;

create or replace function public.confirm_seller_payment(
  p_transaction_id text, p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'confirm_seller_payment';
  v_early jsonb;
  t public.transactions;
  p public.payment_confirmations;
  v_event uuid;
begin
  v_early := private.ss_begin_txn_command(c_cmd, p_transaction_id, p_idempotency_key, '');
  if v_early is not null then return v_early; end if;
  select * into t from public.transactions where id = p_transaction_id::uuid;
  if t.type <> 'SELL' then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Giao dịch này không có thanh toán.');
  end if;
  if t.owner_at_acceptance <> auth.uid() then
    return private.ss_err('FORBIDDEN', 'Chỉ người bán được xác nhận đã nhận tiền.');
  end if;
  select * into p from public.payment_confirmations where transaction_id = t.id for update;
  if p.seller_confirmed_at is not null then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION',
      'Người bán đã xác nhận nhận tiền trước đó.');
  end if;
  if t.status <> 'AWAITING_PAYMENT' then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION',
      'Giao dịch không còn ở bước chờ thanh toán.');
  end if;

  -- Một lần duy nhất, nguyên tử: seller_confirmed_at + AWAITING_HANDOVER + Event.
  insert into public.payment_confirmations(transaction_id, amount_vnd, seller_confirmed_at)
  values (t.id, t.agreed_price_vnd, now())
  on conflict (transaction_id) do update set seller_confirmed_at = excluded.seller_confirmed_at;
  update public.transactions set status = 'AWAITING_HANDOVER' where id = t.id;
  v_event := private.ss_append_txn_event(t.id, auth.uid(), 'SELLER_PAYMENT_CONFIRMED',
    'Người bán xác nhận đã nhận đủ tiền. Có thể bắt đầu bàn giao.',
    private.ss_source(c_cmd, p_idempotency_key));
  return private.ss_finish_txn_command(c_cmd, t.id, p_idempotency_key, '', v_event);
end $$;

create or replace function public.report_seller_refund(
  p_transaction_id text, p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'report_seller_refund';
  v_early jsonb;
  t public.transactions;
  p public.payment_confirmations;
  v_event uuid;
begin
  v_early := private.ss_begin_txn_command(c_cmd, p_transaction_id, p_idempotency_key, '');
  if v_early is not null then return v_early; end if;
  select * into t from public.transactions where id = p_transaction_id::uuid;
  if t.type <> 'SELL' then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Giao dịch này không có thanh toán.');
  end if;
  if t.owner_at_acceptance <> auth.uid() then
    return private.ss_err('FORBIDDEN', 'Chỉ người bán được báo đã hoàn tiền.');
  end if;
  if t.status in ('COMPLETED', 'CANCELLED') or not exists (
      select 1 from public.transaction_cancellations c where c.transaction_id = t.id) then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION',
      'Chỉ hoàn tiền khi đang có đề nghị hủy giao dịch.');
  end if;
  select * into p from public.payment_confirmations where transaction_id = t.id for update;
  if p.seller_confirmed_at is null then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION',
      'Chưa có khoản tiền nào được người bán xác nhận.');
  end if;
  if p.refund_proposed_at is not null then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Bạn đã báo hoàn tiền trước đó.');
  end if;

  update public.payment_confirmations set refund_proposed_at = now()
   where transaction_id = t.id;
  v_event := private.ss_append_txn_event(t.id, auth.uid(), 'REFUND_REPORTED',
    'Người bán báo đã hoàn tiền ngoài ứng dụng. Chờ người mua xác nhận.',
    private.ss_source(c_cmd, p_idempotency_key));
  return private.ss_finish_txn_command(c_cmd, t.id, p_idempotency_key, '', v_event);
end $$;

create or replace function public.confirm_refund_received(
  p_transaction_id text, p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'confirm_refund_received';
  v_early jsonb;
  t public.transactions;
  p public.payment_confirmations;
  v_event uuid;
begin
  v_early := private.ss_begin_txn_command(c_cmd, p_transaction_id, p_idempotency_key, '');
  if v_early is not null then return v_early; end if;
  select * into t from public.transactions where id = p_transaction_id::uuid;
  if t.type <> 'SELL' then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Giao dịch này không có thanh toán.');
  end if;
  if t.receiver_id <> auth.uid() then
    return private.ss_err('FORBIDDEN', 'Chỉ người mua được xác nhận đã nhận lại tiền.');
  end if;
  select * into p from public.payment_confirmations where transaction_id = t.id for update;
  if p.refund_proposed_at is null then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Người bán chưa báo hoàn tiền.');
  end if;
  if p.buyer_refund_confirmed_at is not null then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION',
      'Bạn đã xác nhận nhận lại tiền trước đó.');
  end if;

  update public.payment_confirmations set buyer_refund_confirmed_at = now()
   where transaction_id = t.id;
  v_event := private.ss_append_txn_event(t.id, auth.uid(), 'REFUND_CONFIRMED',
    'Người mua xác nhận đã nhận lại đủ tiền.',
    private.ss_source(c_cmd, p_idempotency_key));
  return private.ss_finish_txn_command(c_cmd, t.id, p_idempotency_key, '', v_event);
end $$;

-- 8. Hủy Transaction hai bên đồng thuận (BR-45, STATE_MACHINES §9) ------------
-- Không có "Force Cancel"; chỉ CANCELLED khi hết nghĩa vụ sách/tiền/Issue.

create or replace function public.propose_transaction_cancellation(
  p_transaction_id text, p_reason text, p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'propose_transaction_cancellation';
  v_reason text := trim(coalesce(p_reason, ''));
  v_early jsonb;
  t public.transactions;
  v_event uuid;
begin
  v_early := private.ss_begin_txn_command(c_cmd, p_transaction_id, p_idempotency_key, v_reason);
  if v_early is not null then return v_early; end if;
  select * into t from public.transactions where id = p_transaction_id::uuid;
  if v_reason = '' then
    return private.ss_err('INVALID_INPUT', 'Vui lòng nhập lý do hủy.');
  end if;
  if char_length(v_reason) > 500 then
    return private.ss_err('INVALID_INPUT', 'Lý do hủy tối đa 500 ký tự.');
  end if;
  if t.status in ('COMPLETED', 'CANCELLED') then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Giao dịch đã kết thúc.');
  end if;
  if exists (select 1 from public.transaction_cancellations c where c.transaction_id = t.id) then
    return private.ss_err('CONFLICT', 'Đã có đề nghị hủy đang chờ phản hồi.');
  end if;

  insert into public.transaction_cancellations(transaction_id, proposed_by, reason)
  values (t.id, auth.uid(), v_reason);
  v_event := private.ss_append_txn_event(t.id, auth.uid(), 'CANCELLATION_PROPOSED',
    'Có đề nghị hủy giao dịch, chờ bên còn lại phản hồi.',
    private.ss_source(c_cmd, p_idempotency_key));
  return private.ss_finish_txn_command(c_cmd, t.id, p_idempotency_key, v_reason, v_event);
end $$;

create or replace function public.withdraw_transaction_cancellation(
  p_transaction_id text, p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'withdraw_transaction_cancellation';
  v_early jsonb;
  t public.transactions;
  c public.transaction_cancellations;
  v_event uuid;
begin
  v_early := private.ss_begin_txn_command(c_cmd, p_transaction_id, p_idempotency_key, '');
  if v_early is not null then return v_early; end if;
  select * into t from public.transactions where id = p_transaction_id::uuid;
  select * into c from public.transaction_cancellations where transaction_id = t.id;
  if not found then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Không có đề nghị hủy nào đang chờ.');
  end if;
  if c.proposed_by <> auth.uid() then
    return private.ss_err('FORBIDDEN', 'Chỉ người đề nghị được rút lại đề nghị hủy.');
  end if;

  delete from public.transaction_cancellations where transaction_id = t.id;
  v_event := private.ss_append_txn_event(t.id, auth.uid(), 'CANCELLATION_WITHDRAWN',
    'Đề nghị hủy đã được rút lại.', private.ss_source(c_cmd, p_idempotency_key));
  return private.ss_finish_txn_command(c_cmd, t.id, p_idempotency_key, '', v_event);
end $$;

create or replace function public.decline_transaction_cancellation(
  p_transaction_id text, p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'decline_transaction_cancellation';
  v_early jsonb;
  t public.transactions;
  c public.transaction_cancellations;
  v_event uuid;
begin
  v_early := private.ss_begin_txn_command(c_cmd, p_transaction_id, p_idempotency_key, '');
  if v_early is not null then return v_early; end if;
  select * into t from public.transactions where id = p_transaction_id::uuid;
  select * into c from public.transaction_cancellations where transaction_id = t.id;
  if not found then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Không có đề nghị hủy nào đang chờ.');
  end if;
  if c.proposed_by = auth.uid() then
    return private.ss_err('FORBIDDEN', 'Bên còn lại mới được phản hồi đề nghị hủy.');
  end if;

  delete from public.transaction_cancellations where transaction_id = t.id;
  v_event := private.ss_append_txn_event(t.id, auth.uid(), 'CANCELLATION_DECLINED',
    'Đề nghị hủy bị từ chối, giao dịch tiếp tục.',
    private.ss_source(c_cmd, p_idempotency_key));
  return private.ss_finish_txn_command(c_cmd, t.id, p_idempotency_key, '', v_event);
end $$;

create or replace function public.accept_transaction_cancellation(
  p_transaction_id text, p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'accept_transaction_cancellation';
  v_early jsonb;
  t public.transactions;
  c public.transaction_cancellations;
  v_blocker jsonb;
  v_event uuid;
begin
  v_early := private.ss_begin_txn_command(c_cmd, p_transaction_id, p_idempotency_key, '');
  if v_early is not null then return v_early; end if;
  select * into t from public.transactions where id = p_transaction_id::uuid;
  if t.status in ('COMPLETED', 'CANCELLED') then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Giao dịch đã kết thúc.');
  end if;
  select * into c from public.transaction_cancellations where transaction_id = t.id;
  if not found then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Không có đề nghị hủy nào đang chờ.');
  end if;
  if c.proposed_by = auth.uid() then
    return private.ss_err('FORBIDDEN', 'Cần bên còn lại đồng ý mới được hủy.');
  end if;
  v_blocker := private.ss_cancellation_blocker(t.id);
  if v_blocker is not null then return v_blocker; end if;

  -- Nguyên tử: CANCELLED + đóng đề nghị + lưu trữ Listing + Event.
  -- owner_id/holder_id giữ nguyên.
  update public.transactions set status = 'CANCELLED' where id = t.id;
  delete from public.transaction_cancellations where transaction_id = t.id;
  update public.listings set status = 'ARCHIVED'
   where id = t.listing_id and status <> 'ARCHIVED';
  v_event := private.ss_append_txn_event(t.id, auth.uid(), 'TRANSACTION_CANCELLED',
    'Hai bên đồng ý hủy giao dịch. Tin đăng cũ được lưu trữ.',
    private.ss_source(c_cmd, p_idempotency_key));
  return private.ss_finish_txn_command(c_cmd, t.id, p_idempotency_key, '', v_event);
end $$;

-- 9. Issue (BR-34, BR-47, SS-BR §9) -----------------------------------------
-- Issue KHÔNG đổi owner/holder/due_date/payment hay Transaction.status (INV-10).

create or replace function public.report_issue(
  p_transaction_id text, p_issue_type text, p_reason text,
  p_handover_id text, p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'report_issue';
  v_actor uuid := auth.uid();
  v_txn_id uuid := private.ss_try_uuid(p_transaction_id);
  v_handover_id uuid := private.ss_try_uuid(p_handover_id);
  v_reason text := trim(coalesce(p_reason, ''));
  v_payload text := coalesce(p_issue_type, '') || '|' || coalesce(p_reason, '')
                    || '|' || coalesce(p_handover_id, '');
  v_hash text;
  t public.transactions;
  r public.command_receipts;
  v_issue_id uuid;
  v_event uuid;
begin
  if v_actor is null then
    return private.ss_err('AUTH_REQUIRED', 'Phiên đăng nhập đã hết hạn.');
  end if;
  if p_idempotency_key is null or trim(p_idempotency_key) = '' then
    return private.ss_err('INVALID_INPUT', 'Thiếu mã thao tác, vui lòng thử lại.');
  end if;
  select * into t from public.transactions where id = v_txn_id for update;
  -- Được mở: A/B, hoặc một đầu của chặng được gắn vào.
  if not found or not (
      v_actor in (t.owner_at_acceptance, t.receiver_id)
      or v_actor = any(private.ss_handover_parties(t.id, v_handover_id))) then
    return private.ss_err('FORBIDDEN', 'Bạn không có quyền thực hiện thao tác này.');
  end if;

  v_hash := private.ss_payload_hash(c_cmd, t.id::text, v_payload);
  select * into r from public.command_receipts
   where actor_id = v_actor and command_name = c_cmd and idempotency_key = p_idempotency_key;
  if found then
    if r.payload_hash <> v_hash then
      return private.ss_err('CONFLICT', 'Mã thao tác đã được dùng cho nội dung khác.');
    end if;
    return private.ss_ok(
      private.ss_issue_json((r.result_json->>'entity_id')::uuid, v_actor),
      r.result_json->>'event_id');
  end if;

  if v_reason = '' or char_length(v_reason) > 1000 then
    return private.ss_err('INVALID_INPUT', 'Hãy mô tả sự cố (tối đa 1000 ký tự).');
  end if;
  if p_issue_type is null or p_issue_type not in (
      'WRONG_MATERIAL', 'WRONG_CONDITION', 'NOT_RECEIVED',
      'DELIVERY_FAILED', 'UNCOOPERATIVE', 'OTHER') then
    return private.ss_err('INVALID_INPUT', 'Loại sự cố không hợp lệ.');
  end if;
  if p_handover_id is not null and trim(p_handover_id) <> ''
     and cardinality(private.ss_handover_parties(t.id, v_handover_id)) = 0 then
    return private.ss_err('INVALID_INPUT', 'Lượt bàn giao không thuộc giao dịch này.');
  end if;
  if not private.ss_issue_window_open(t.id) then
    if t.status = 'CANCELLED' then
      return private.ss_err('INVALID_TRANSACTION_TRANSITION',
        'Giao dịch đã hủy, không thể mở sự cố.');
    end if;
    return private.ss_err('INVALID_TRANSACTION_TRANSITION',
      'Đã quá hạn 7 ngày để mở sự cố cho giao dịch này.');
  end if;

  -- Nguyên tử: Issue OPEN + Event Issue + Event giao dịch.
  insert into public.issues(transaction_id, handover_id, reporter_id, issue_type, reason)
  values (t.id, v_handover_id, v_actor, p_issue_type, v_reason)
  returning id into v_issue_id;
  perform private.ss_append_issue_event(v_issue_id, v_actor, 'ISSUE_OPENED', 'Sự cố được mở.');
  v_event := private.ss_append_txn_event(t.id, v_actor, 'ISSUE_OPENED',
    'Có sự cố được mở. Lịch sử bàn giao và thanh toán không thay đổi.',
    private.ss_source(c_cmd, p_idempotency_key));
  perform private.ss_save_receipt(v_actor, c_cmd, p_idempotency_key, v_hash, v_event, v_issue_id);
  return private.ss_ok(private.ss_issue_json(v_issue_id, v_actor), v_event::text);
end $$;

-- Chuẩn bị lệnh trên Issue có sẵn: chỉ bên bị ảnh hưởng trực tiếp; khóa Issue.
create or replace function private.ss_begin_issue_command(
  p_command text, p_issue_id text, p_key text, p_payload text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_id uuid := private.ss_try_uuid(p_issue_id);
  i public.issues;
  r public.command_receipts;
begin
  if v_actor is null then
    return private.ss_err('AUTH_REQUIRED', 'Phiên đăng nhập đã hết hạn.');
  end if;
  if p_key is null or trim(p_key) = '' then
    return private.ss_err('INVALID_INPUT', 'Thiếu mã thao tác, vui lòng thử lại.');
  end if;
  select * into i from public.issues where id = v_id for update;
  if not found or not (v_actor = any(private.ss_issue_parties(i.id))) then
    return private.ss_err('FORBIDDEN', 'Bạn không có quyền thực hiện thao tác này.');
  end if;
  select * into r from public.command_receipts
   where actor_id = v_actor and command_name = p_command and idempotency_key = p_key;
  if found then
    if r.payload_hash <> private.ss_payload_hash(p_command, v_id::text, p_payload) then
      return private.ss_err('CONFLICT', 'Mã thao tác đã được dùng cho nội dung khác.');
    end if;
    return private.ss_ok(private.ss_issue_json(v_id, v_actor), r.result_json->>'event_id');
  end if;
  return null;
end $$;

create or replace function public.propose_issue_resolution(
  p_issue_id text, p_summary text, p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'propose_issue_resolution';
  v_payload text := coalesce(p_summary, '');
  v_text text := trim(coalesce(p_summary, ''));
  v_early jsonb;
  i public.issues;
  v_event uuid;
begin
  v_early := private.ss_begin_issue_command(c_cmd, p_issue_id, p_idempotency_key, v_payload);
  if v_early is not null then return v_early; end if;
  select * into i from public.issues where id = p_issue_id::uuid;
  if i.status <> 'OPEN' then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Sự cố này đã được giải quyết.');
  end if;
  if v_text = '' or char_length(v_text) > 1000 then
    return private.ss_err('INVALID_INPUT',
      'Hãy nhập phương án giải quyết (tối đa 1000 ký tự).');
  end if;

  -- Revision tăng dần; xác nhận của bản cũ mất hiệu lực (gắn theo revision).
  -- Đề xuất KHÔNG tự tính là xác nhận của người đề xuất.
  update public.issues
     set resolution_revision = resolution_revision + 1,
         resolution_text = v_text,
         resolution_proposed_by = auth.uid(),
         resolution_proposed_at = now()
   where id = i.id;
  v_event := private.ss_append_issue_event(i.id, auth.uid(), 'RESOLUTION_PROPOSED',
    'Đề xuất phương án giải quyết (bản ' || (i.resolution_revision + 1) || ').');
  perform private.ss_save_receipt(auth.uid(), c_cmd, p_idempotency_key,
    private.ss_payload_hash(c_cmd, i.id::text, v_payload), v_event, i.id);
  return private.ss_ok(private.ss_issue_json(i.id, auth.uid()), v_event::text);
end $$;

create or replace function public.confirm_issue_resolution(
  p_issue_id text, p_resolution_revision integer, p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'confirm_issue_resolution';
  v_payload text := coalesce(p_resolution_revision::text, '');
  v_early jsonb;
  i public.issues;
  v_parties uuid[];
  v_event uuid;
begin
  v_early := private.ss_begin_issue_command(c_cmd, p_issue_id, p_idempotency_key, v_payload);
  if v_early is not null then return v_early; end if;
  select * into i from public.issues where id = p_issue_id::uuid;
  if i.status <> 'OPEN' then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Sự cố này đã được giải quyết.');
  end if;
  if i.resolution_revision = 0 then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION',
      'Chưa có phương án giải quyết để xác nhận.');
  end if;
  if p_resolution_revision is distinct from i.resolution_revision then
    return private.ss_err('CONFLICT', 'Phương án đã thay đổi. Hãy xem lại bản mới nhất.');
  end if;
  if exists (select 1 from public.issue_consents ic
             where ic.issue_id = i.id and ic.participant_id = auth.uid()
               and ic.resolution_revision = i.resolution_revision) then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Bạn đã xác nhận phương án này.');
  end if;

  insert into public.issue_consents(issue_id, participant_id, resolution_revision)
  values (i.id, auth.uid(), i.resolution_revision);
  v_event := private.ss_append_issue_event(i.id, auth.uid(), 'RESOLUTION_CONFIRMED',
    'Xác nhận phương án giải quyết (bản ' || i.resolution_revision || ').');

  -- Chỉ khi MỌI bên bị ảnh hưởng trực tiếp xác nhận mới RESOLVED; không ai đóng thay.
  v_parties := private.ss_issue_parties(i.id);
  if not exists (
      select 1 from unnest(v_parties) as x(u)
      where not exists (
        select 1 from public.issue_consents ic
        where ic.issue_id = i.id and ic.participant_id = x.u
          and ic.resolution_revision = i.resolution_revision)) then
    update public.issues set status = 'RESOLVED', resolved_at = now() where id = i.id;
    perform private.ss_append_issue_event(i.id, null, 'ISSUE_RESOLVED',
      'Các bên đã thống nhất. Sự cố được giải quyết.');
    perform private.ss_append_txn_event(i.transaction_id, null, 'ISSUE_RESOLVED',
      'Một sự cố đã được các bên thống nhất giải quyết.');
  end if;

  perform private.ss_save_receipt(auth.uid(), c_cmd, p_idempotency_key,
    private.ss_payload_hash(c_cmd, i.id::text, v_payload), v_event, i.id);
  return private.ss_ok(private.ss_issue_json(i.id, auth.uid()), v_event::text);
end $$;

-- 10. Quyền gọi hàm ----------------------------------------------------------
-- Hàm nội bộ: không ai ngoài owner (postgres) gọi được.
revoke all on all functions in schema private from public, anon, authenticated;

-- RPC công khai: chỉ người đã đăng nhập.
do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'get_my_transactions()',
    'get_transaction_details(text)',
    'get_transaction_timeline(text)',
    'get_my_issues()',
    'get_issue_details(text)',
    'get_issue_timeline(text)',
    'report_buyer_transfer(text, text)',
    'confirm_seller_payment(text, text)',
    'report_seller_refund(text, text)',
    'confirm_refund_received(text, text)',
    'propose_transaction_cancellation(text, text, text)',
    'withdraw_transaction_cancellation(text, text)',
    'decline_transaction_cancellation(text, text)',
    'accept_transaction_cancellation(text, text)',
    'report_issue(text, text, text, text, text)',
    'propose_issue_resolution(text, text, text)',
    'confirm_issue_resolution(text, integer, text)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', v_fn);
    execute format('grant execute on function public.%s to authenticated', v_fn);
  end loop;
end $$;
