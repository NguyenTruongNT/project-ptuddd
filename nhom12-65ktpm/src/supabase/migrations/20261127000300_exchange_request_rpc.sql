-- StudyShare: ExchangeRequest read model và commands.
--
-- Mobile không được ghi trực tiếp exchange_requests hoặc transactions.
-- Mọi mutation lấy actor từ auth.uid() và kiểm tra lại tại server.

alter table public.exchange_requests
  add column if not exists revision bigint not null default 1
  check (revision > 0);

create or replace function private.ss_request_json(
  p_request_id uuid,
  p_viewer uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r public.exchange_requests;
  l public.listings;
  m public.materials;
  v_is_owner boolean;
  v_is_requester boolean;
begin
  select *
  into r
  from public.exchange_requests
  where id = p_request_id;

  if not found or p_viewer is null then
    return null;
  end if;

  select *
  into l
  from public.listings
  where id = r.listing_id;

  select *
  into m
  from public.materials
  where id = l.material_id;

  v_is_owner := m.owner_id = p_viewer;
  v_is_requester := r.requester_id = p_viewer;

  if not (v_is_owner or v_is_requester) then
    return null;
  end if;

  return jsonb_build_object(
    'id', r.id,
    'listingId', r.listing_id,
    'requesterId', r.requester_id,
    'requestedBorrowDays', r.requested_borrow_days,
    'status', r.status,
    'createdAt', r.created_at,
    'decidedAt', r.decided_at,
    'rejectReason', r.reject_reason,
    'revision', r.revision,
    'materialTitle', coalesce(m.title, 'Tài liệu'),
    'materialSubject', coalesce(m.subject, ''),
    'offerType', l.offer_type,
    'ownerId', m.owner_id,
    'ownerDisplayName', private.ss_display_name(m.owner_id),
    'requesterDisplayName', private.ss_display_name(r.requester_id),
    'viewerRole', case
      when v_is_owner then 'OWNER'
      else 'REQUESTER'
    end,
    'allowedActions', to_jsonb(
      case
        when r.status <> 'PENDING' then array[]::text[]
        when v_is_owner then array[
          'CAN_APPROVE_REQUEST',
          'CAN_REJECT_REQUEST'
        ]::text[]
        when v_is_requester then array[
          'CAN_CANCEL_REQUEST'
        ]::text[]
        else array[]::text[]
      end
    )
  );
end;
$$;

create or replace function public.get_my_exchange_requests()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  return (
    select coalesce(
      jsonb_agg(
        private.ss_request_json(r.id, v_actor)
        order by r.created_at desc, r.id
      ),
      '[]'::jsonb
    )
    from public.exchange_requests r
    join public.listings l on l.id = r.listing_id
    join public.materials m on m.id = l.material_id
    where r.requester_id = v_actor
       or m.owner_id = v_actor
  );
end;
$$;
-- Tạo envelope receipt cho command Request không tạo TransactionEvent.
create or replace function private.ss_request_receipt(
  p_request_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_data jsonb;
  v_revision bigint;
begin
  select
    private.ss_request_json(r.id, auth.uid()),
    r.revision
  into v_data, v_revision
  from public.exchange_requests r
  where r.id = p_request_id;

  if v_data is null then
    return private.ss_err(
      'FORBIDDEN',
      'Bạn không có quyền xem yêu cầu này.'
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'data', v_data,
    'command_id', gen_random_uuid(),
    'server_revision', v_revision
  );
end;
$$;

-- Gửi yêu cầu trao đổi.
create or replace function public.create_exchange_request(
  p_listing_id text,
  p_requested_borrow_days integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_cmd constant text := 'create_exchange_request';
  v_actor uuid := auth.uid();
  v_listing_id uuid := private.ss_try_uuid(p_listing_id);
  v_listing public.listings;
  v_material public.materials;
  v_request public.exchange_requests;
  v_old_receipt public.command_receipts;
  v_payload text;
  v_payload_hash text;
  v_result jsonb;
begin
  if v_actor is null then
    return private.ss_err(
      'AUTH_REQUIRED',
      'Phiên đăng nhập đã hết hạn.'
    );
  end if;

  if p_idempotency_key is null
     or trim(p_idempotency_key) = ''
     or char_length(p_idempotency_key) > 128
     or v_listing_id is null then
    return private.ss_err(
      'INVALID_INPUT',
      'Thiếu tin đăng hoặc mã thao tác.'
    );
  end if;

  v_payload := coalesce(
    p_requested_borrow_days::text,
    ''
  );

  v_payload_hash := private.ss_payload_hash(
    c_cmd,
    v_listing_id::text,
    v_payload
  );

  -- Tuần tự hóa retry cùng actor, command và key.
  perform pg_advisory_xact_lock(
    hashtextextended(
      v_actor::text || c_cmd || p_idempotency_key,
      0
    )
  );

  select *
  into v_old_receipt
  from public.command_receipts
  where actor_id = v_actor
    and command_name = c_cmd
    and idempotency_key = p_idempotency_key;

  if found then
    if v_old_receipt.payload_hash <> v_payload_hash then
      return private.ss_err(
        'CONFLICT',
        'Mã thao tác đã được dùng cho nội dung khác.'
      );
    end if;

    return v_old_receipt.result_json;
  end if;

  -- Khóa Listing và Material để request không chạy đua với publish/approve.
  select *
  into v_listing
  from public.listings
  where id = v_listing_id
  for update;

  if not found then
    return private.ss_err(
      'MATERIAL_UNAVAILABLE',
      'Tin đăng không còn khả dụng.'
    );
  end if;

  select *
  into v_material
  from public.materials
  where id = v_listing.material_id
  for update;

  if v_listing.status <> 'PUBLISHED'
     or v_listing.publication_snapshot is null
     or v_material.owner_id <> v_material.holder_id
     or studyshare_private.listing_active(v_material.id) then
    return private.ss_err(
      'MATERIAL_UNAVAILABLE',
      'Tài liệu hiện không thể nhận yêu cầu.'
    );
  end if;

  if v_material.owner_id = v_actor then
    return private.ss_err(
      'FORBIDDEN',
      'Bạn không thể gửi yêu cầu cho tài liệu của mình.'
    );
  end if;

  if v_listing.offer_type = 'BORROW' then
    if p_requested_borrow_days is null
       or p_requested_borrow_days not between 1 and 30 then
      return private.ss_err(
        'INVALID_INPUT',
        'Số ngày mượn phải từ 1 đến 30.'
      );
    end if;
  elsif p_requested_borrow_days is not null then
    return private.ss_err(
      'INVALID_INPUT',
      'Yêu cầu mua hoặc nhận tặng không có số ngày mượn.'
    );
  end if;

  if exists (
    select 1
    from public.exchange_requests r
    where r.listing_id = v_listing.id
      and r.requester_id = v_actor
      and r.status = 'PENDING'
  ) then
    return private.ss_err(
      'DUPLICATE_REQUEST',
      'Bạn đã có một yêu cầu đang chờ cho tin đăng này.'
    );
  end if;

  insert into public.exchange_requests(
    listing_id,
    requester_id,
    requested_borrow_days,
    status
  )
  values (
    v_listing.id,
    v_actor,
    p_requested_borrow_days,
    'PENDING'
  )
  returning * into v_request;

  v_result := private.ss_request_receipt(v_request.id);

  insert into public.command_receipts(
    actor_id,
    command_name,
    idempotency_key,
    payload_hash,
    result_json
  )
  values (
    v_actor,
    c_cmd,
    p_idempotency_key,
    v_payload_hash,
    v_result
  );

  return v_result;

exception
  when unique_violation then
    return private.ss_err(
      'DUPLICATE_REQUEST',
      'Bạn đã có một yêu cầu đang chờ cho tin đăng này.'
    );
end;
$$;

-- Chủ tài liệu từ chối Request đang PENDING.
create or replace function public.reject_exchange_request(
  p_request_id text,
  p_reason text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_cmd constant text := 'reject_exchange_request';
  v_actor uuid := auth.uid();
  v_request_id uuid := private.ss_try_uuid(p_request_id);
  v_request public.exchange_requests;
  v_listing public.listings;
  v_material public.materials;
  v_old_receipt public.command_receipts;
  v_reason text;
  v_payload_hash text;
  v_result jsonb;
begin
  if v_actor is null then
    return private.ss_err(
      'AUTH_REQUIRED',
      'Phiên đăng nhập đã hết hạn.'
    );
  end if;

  v_reason := nullif(
    regexp_replace(
      coalesce(p_reason, ''),
      '^[[:space:]]+|[[:space:]]+$',
      '',
      'g'
    ),
    ''
  );

  if v_request_id is null
     or p_idempotency_key is null
     or trim(p_idempotency_key) = ''
     or char_length(p_idempotency_key) > 128
     or v_reason is null then
    return private.ss_err(
      'INVALID_INPUT',
      'Thiếu yêu cầu, lý do từ chối hoặc mã thao tác.'
    );
  end if;

  v_payload_hash := private.ss_payload_hash(
    c_cmd,
    v_request_id::text,
    v_reason
  );

  perform pg_advisory_xact_lock(
    hashtextextended(
      v_actor::text || c_cmd || p_idempotency_key,
      0
    )
  );

  select *
  into v_old_receipt
  from public.command_receipts
  where actor_id = v_actor
    and command_name = c_cmd
    and idempotency_key = p_idempotency_key;

  if found then
    if v_old_receipt.payload_hash <> v_payload_hash then
      return private.ss_err(
        'CONFLICT',
        'Mã thao tác đã được dùng cho nội dung khác.'
      );
    end if;

    return v_old_receipt.result_json;
  end if;

  select *
  into v_request
  from public.exchange_requests
  where id = v_request_id
  for update;

  if not found then
    return private.ss_err(
      'FORBIDDEN',
      'Bạn không có quyền thực hiện thao tác này.'
    );
  end if;

  select *
  into v_listing
  from public.listings
  where id = v_request.listing_id;

  select *
  into v_material
  from public.materials
  where id = v_listing.material_id;

  if v_material.owner_id <> v_actor then
    return private.ss_err(
      'FORBIDDEN',
      'Chỉ chủ tài liệu được từ chối yêu cầu.'
    );
  end if;

  if v_request.status <> 'PENDING' then
    return private.ss_err(
      'REQUEST_NOT_PENDING',
      'Yêu cầu không còn ở trạng thái chờ.'
    );
  end if;

  update public.exchange_requests
  set status = 'REJECTED',
      reject_reason = v_reason,
      decided_at = clock_timestamp(),
      revision = revision + 1
  where id = v_request.id;

  v_result := private.ss_request_receipt(v_request.id);

  insert into public.command_receipts(
    actor_id,
    command_name,
    idempotency_key,
    payload_hash,
    result_json
  )
  values (
    v_actor,
    c_cmd,
    p_idempotency_key,
    v_payload_hash,
    v_result
  );

  return v_result;
end;
$$;

-- Người gửi tự rút Request đang PENDING.
create or replace function public.cancel_pending_request(
  p_request_id text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_cmd constant text := 'cancel_pending_request';
  v_actor uuid := auth.uid();
  v_request_id uuid := private.ss_try_uuid(p_request_id);
  v_request public.exchange_requests;
  v_old_receipt public.command_receipts;
  v_payload_hash text;
  v_result jsonb;
begin
  if v_actor is null then
    return private.ss_err(
      'AUTH_REQUIRED',
      'Phiên đăng nhập đã hết hạn.'
    );
  end if;

  if v_request_id is null
     or p_idempotency_key is null
     or trim(p_idempotency_key) = ''
     or char_length(p_idempotency_key) > 128 then
    return private.ss_err(
      'INVALID_INPUT',
      'Thiếu yêu cầu hoặc mã thao tác.'
    );
  end if;

  v_payload_hash := private.ss_payload_hash(
    c_cmd,
    v_request_id::text,
    ''
  );

  perform pg_advisory_xact_lock(
    hashtextextended(
      v_actor::text || c_cmd || p_idempotency_key,
      0
    )
  );

  select *
  into v_old_receipt
  from public.command_receipts
  where actor_id = v_actor
    and command_name = c_cmd
    and idempotency_key = p_idempotency_key;

  if found then
    if v_old_receipt.payload_hash <> v_payload_hash then
      return private.ss_err(
        'CONFLICT',
        'Mã thao tác đã được dùng cho nội dung khác.'
      );
    end if;

    return v_old_receipt.result_json;
  end if;

  select *
  into v_request
  from public.exchange_requests
  where id = v_request_id
  for update;

  if not found or v_request.requester_id <> v_actor then
    return private.ss_err(
      'FORBIDDEN',
      'Bạn không có quyền thực hiện thao tác này.'
    );
  end if;

  if v_request.status <> 'PENDING' then
    return private.ss_err(
      'REQUEST_NOT_PENDING',
      'Yêu cầu không còn ở trạng thái chờ.'
    );
  end if;

  update public.exchange_requests
  set status = 'CANCELLED',
      decided_at = clock_timestamp(),
      revision = revision + 1
  where id = v_request.id;

  v_result := private.ss_request_receipt(v_request.id);

  insert into public.command_receipts(
    actor_id,
    command_name,
    idempotency_key,
    payload_hash,
    result_json
  )
  values (
    v_actor,
    c_cmd,
    p_idempotency_key,
    v_payload_hash,
    v_result
  );

  return v_result;
end;
$$;
-- Chủ tài liệu duyệt Request đang PENDING.
--
-- Một lần gọi thực hiện nguyên tử:
-- 1. Request được chọn -> ACCEPTED.
-- 2. Các Request PENDING cạnh tranh -> REJECTED.
-- 3. Tạo đúng một Transaction.
-- 4. Trigger listing_transaction_snapshot gắn snapshot Listing.
-- 5. Ghi một TransactionEvent REQUEST_ACCEPTED.
-- 6. Lưu idempotency receipt và trả TransactionDetails.
create or replace function public.approve_exchange_request(
  p_request_id text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_cmd constant text := 'approve_exchange_request';
  v_actor uuid := auth.uid();
  v_request_id uuid := private.ss_try_uuid(p_request_id);

  v_request public.exchange_requests;
  v_listing public.listings;
  v_material public.materials;
  v_transaction public.transactions;
  v_old_receipt public.command_receipts;

  v_payload_hash text;
  v_initial_status text;
  v_event_id uuid;
  v_result jsonb;
begin
  if v_actor is null then
    return private.ss_err(
      'AUTH_REQUIRED',
      'Phiên đăng nhập đã hết hạn.'
    );
  end if;

  if v_request_id is null
     or p_idempotency_key is null
     or trim(p_idempotency_key) = ''
     or char_length(p_idempotency_key) > 128 then
    return private.ss_err(
      'INVALID_INPUT',
      'Thiếu yêu cầu hoặc mã thao tác.'
    );
  end if;

  v_payload_hash := private.ss_payload_hash(
    c_cmd,
    v_request_id::text,
    ''
  );

  -- Tuần tự hóa retry cùng actor, command và key.
  perform pg_advisory_xact_lock(
    hashtextextended(
      v_actor::text || c_cmd || p_idempotency_key,
      0
    )
  );

  select *
  into v_old_receipt
  from public.command_receipts
  where actor_id = v_actor
    and command_name = c_cmd
    and idempotency_key = p_idempotency_key;

  if found then
    if v_old_receipt.payload_hash <> v_payload_hash then
      return private.ss_err(
        'CONFLICT',
        'Mã thao tác đã được dùng cho nội dung khác.'
      );
    end if;

    -- Retry sau timeout trả đúng ACK cũ, không tạo Transaction lần hai.
    return v_old_receipt.result_json;
  end if;

  -- Đọc Request ban đầu để biết Listing/Material cần khóa.
  -- Chưa cập nhật dữ liệu ở bước này.
  select *
  into v_request
  from public.exchange_requests
  where id = v_request_id;

  if not found then
    return private.ss_err(
      'FORBIDDEN',
      'Bạn không có quyền thực hiện thao tác này.'
    );
  end if;

  select *
  into v_listing
  from public.listings
  where id = v_request.listing_id
  for update;

  if not found then
    return private.ss_err(
      'MATERIAL_UNAVAILABLE',
      'Tin đăng không còn khả dụng.'
    );
  end if;

  -- Khóa Material là điểm tuần tự hóa chung giữa các Request cạnh tranh.
  select *
  into v_material
  from public.materials
  where id = v_listing.material_id
  for update;

  if not found then
    return private.ss_err(
      'MATERIAL_UNAVAILABLE',
      'Tài liệu không còn khả dụng.'
    );
  end if;

  -- Đọc lại Request sau khi đã khóa Material.
  -- Nếu một lệnh cạnh tranh vừa duyệt trước, status mới sẽ được nhìn thấy.
  select *
  into v_request
  from public.exchange_requests
  where id = v_request_id
  for update;

  if not found then
    return private.ss_err(
      'FORBIDDEN',
      'Bạn không có quyền thực hiện thao tác này.'
    );
  end if;

  if v_material.owner_id <> v_actor then
    return private.ss_err(
      'FORBIDDEN',
      'Chỉ chủ tài liệu được duyệt yêu cầu.'
    );
  end if;

  if v_request.status <> 'PENDING' then
    return private.ss_err(
      'REQUEST_NOT_PENDING',
      'Yêu cầu không còn ở trạng thái chờ.'
    );
  end if;

  if v_listing.status <> 'PUBLISHED'
     or v_listing.publication_snapshot is null
     or v_material.owner_id <> v_material.holder_id
     or studyshare_private.listing_active(v_material.id) then
    return private.ss_err(
      'MATERIAL_UNAVAILABLE',
      'Tài liệu hiện không thể được duyệt.'
    );
  end if;

  if v_request.requester_id = v_material.owner_id then
    return private.ss_err(
      'FORBIDDEN',
      'Chủ tài liệu không thể nhận tài liệu từ chính mình.'
    );
  end if;

  if v_listing.offer_type = 'BORROW' then
    if v_request.requested_borrow_days is null
       or v_request.requested_borrow_days not between 1 and 30 then
      return private.ss_err(
        'INVALID_INPUT',
        'Số ngày mượn phải từ 1 đến 30.'
      );
    end if;

    v_initial_status := 'AWAITING_HANDOVER';
  elsif v_listing.offer_type = 'SELL' then
    if v_request.requested_borrow_days is not null
       or v_listing.asking_price_vnd is null
       or v_listing.asking_price_vnd <= 0 then
      return private.ss_err(
        'INVALID_INPUT',
        'Thông tin yêu cầu mua không hợp lệ.'
      );
    end if;

    v_initial_status := 'AWAITING_PAYMENT';
  elsif v_listing.offer_type = 'DONATE' then
    if v_request.requested_borrow_days is not null then
      return private.ss_err(
        'INVALID_INPUT',
        'Yêu cầu nhận tặng không có số ngày mượn.'
      );
    end if;

    v_initial_status := 'AWAITING_HANDOVER';
  else
    return private.ss_err(
      'INVALID_INPUT',
      'Hình thức trao đổi không hợp lệ.'
    );
  end if;

  -- Request được chọn thành ACCEPTED.
  -- Trigger guard_listing_request kiểm tra lại Listing và Material.
  update public.exchange_requests
  set status = 'ACCEPTED',
      decided_at = clock_timestamp(),
      reject_reason = null,
      revision = revision + 1
  where id = v_request.id;

  -- Các Request cạnh tranh đang chờ bị từ chối trong cùng transaction SQL.
  update public.exchange_requests
  set status = 'REJECTED',
      decided_at = clock_timestamp(),
      reject_reason =
        'Tài liệu đã được chủ sở hữu duyệt cho một yêu cầu khác.',
      revision = revision + 1
  where listing_id = v_listing.id
    and id <> v_request.id
    and status = 'PENDING';

  -- Tạo Transaction. Trigger listing_transaction_snapshot tự ghép
  -- publication_snapshot vào terms_snapshot.
  insert into public.transactions(
    listing_id,
    request_id,
    material_id,
    type,
    owner_at_acceptance,
    receiver_id,
    status,
    agreed_borrow_days,
    agreed_price_vnd,
    terms_snapshot
  )
  values (
    v_listing.id,
    v_request.id,
    v_material.id,
    v_listing.offer_type,
    v_material.owner_id,
    v_request.requester_id,
    v_initial_status,
    case
      when v_listing.offer_type = 'BORROW'
      then v_request.requested_borrow_days
      else null
    end,
    case
      when v_listing.offer_type = 'SELL'
      then v_listing.asking_price_vnd
      else null
    end,
    jsonb_build_object(
      'request', jsonb_build_object(
        'request_id', v_request.id,
        'requested_borrow_days',
          v_request.requested_borrow_days,
        'accepted_at', clock_timestamp()
      )
    )
  )
  returning * into v_transaction;

  v_event_id := private.ss_append_txn_event(
    v_transaction.id,
    v_actor,
    'REQUEST_ACCEPTED',
    case v_listing.offer_type
      when 'BORROW' then
        'Chủ tài liệu đã duyệt yêu cầu mượn.'
      when 'SELL' then
        'Chủ tài liệu đã duyệt yêu cầu mua.'
      else
        'Chủ tài liệu đã duyệt yêu cầu nhận tặng.'
    end,
    private.ss_source(c_cmd, p_idempotency_key)
  );

  v_result := private.ss_ok(
    private.ss_transaction_json(
      v_transaction.id,
      v_actor
    ),
    v_event_id::text
  );

  insert into public.command_receipts(
    actor_id,
    command_name,
    idempotency_key,
    payload_hash,
    result_json
  )
  values (
    v_actor,
    c_cmd,
    p_idempotency_key,
    v_payload_hash,
    v_result
  );

  return v_result;

exception
  when unique_violation then
    return private.ss_err(
      'DUPLICATE_ACTIVE_TRANSACTION',
      'Tài liệu đã có một giao dịch đang hoạt động.'
    );
  when serialization_failure or deadlock_detected then
    return private.ss_err(
      'CONFLICT',
      'Dữ liệu vừa thay đổi. Vui lòng tải lại và thử lại.'
    );
end;
$$;

-- Hàm nội bộ không được gọi trực tiếp từ mobile.
revoke all on function private.ss_request_json(uuid, uuid)
from public, anon, authenticated;

revoke all on function private.ss_request_receipt(uuid)
from public, anon, authenticated;

-- RPC Request chỉ dành cho tài khoản đã đăng nhập.
revoke all on function public.get_my_exchange_requests()
from public, anon;

grant execute on function public.get_my_exchange_requests()
to authenticated;

revoke all on function public.create_exchange_request(
  text,
  integer,
  text
)
from public, anon;

grant execute on function public.create_exchange_request(
  text,
  integer,
  text
)
to authenticated;

revoke all on function public.reject_exchange_request(
  text,
  text,
  text
)
from public, anon;

grant execute on function public.reject_exchange_request(
  text,
  text,
  text
)
to authenticated;

revoke all on function public.cancel_pending_request(
  text,
  text
)
from public, anon;

grant execute on function public.cancel_pending_request(
  text,
  text
)
to authenticated;

revoke all on function public.approve_exchange_request(
  text,
  text
)
from public, anon;

grant execute on function public.approve_exchange_request(
  text,
  text
)
to authenticated;