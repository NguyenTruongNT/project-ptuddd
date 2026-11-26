-- StudyShare - RPC & Storage RLS cho module của Đăng:
-- DeliveryTask, DeliveryApplication, Handover, QR verification, Evidence & Courier Rating.
-- Tuân thủ SS-BR v2.0, CONTRACTS.md §2, §5, §7-9, STATE_MACHINES.md §6-7.
--
-- Nguyên tắc:
-- - Client KHÔNG đọc/ghi trực tiếp bảng; mọi đọc qua read model RPC đã lọc theo auth.uid(),
--   mọi ghi qua command RPC nguyên tử (FOR UPDATE + command_receipts idempotency).
-- - Lỗi nghiệp vụ trả jsonb {ok:false, code, message}; thành công trả {ok:true, event_id, data}.

-- 1. Chỉ mục bổ sung ----------------------------------------------------------

create index if not exists delivery_tasks_txn_idx
  on public.delivery_tasks(transaction_id, status);

create index if not exists delivery_applications_task_idx
  on public.delivery_applications(task_id, applicant_id);

create index if not exists handovers_txn_idx
  on public.handovers(transaction_id, status);

create index if not exists handovers_task_idx
  on public.handovers(delivery_task_id);

create index if not exists handover_evidence_handover_idx
  on public.handover_evidence(handover_id);

-- 2. Storage RLS cho bucket private studyshare-handover-evidence --------------
-- Người dùng upload vào thư mục của chính mình: <auth.uid()>/<filename>.
-- Người liên quan của chặng (from_user_id / to_user_id) hoặc A/B của giao dịch
-- mới được đọc ảnh minh chứng đã gắn với handover_evidence.

create policy handover_evidence_upload_own_folder
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'studyshare-handover-evidence'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

create policy handover_evidence_read_authorized
  on storage.objects for select to authenticated
  using (
    bucket_id = 'studyshare-handover-evidence'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or exists (
        select 1
        from public.handover_evidence he
        join public.handovers h on h.id = he.handover_id
        join public.transactions t on t.id = h.transaction_id
        where he.private_path = name
          and (
            h.from_user_id = (select auth.uid())
            or h.to_user_id = (select auth.uid())
            or t.owner_at_acceptance = (select auth.uid())
            or t.receiver_id = (select auth.uid())
          )
      )
    )
  );

-- 3. Hàm nội bộ chuyển đổi JSON DTO an toàn -----------------------------------

create or replace function private.ss_delivery_task_json(
  p_task_id uuid, p_actor uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_task public.delivery_tasks%rowtype;
  v_can_see_details boolean;
begin
  select * into v_task from public.delivery_tasks where id = p_task_id;
  if not found then
    return null;
  end if;

  -- Chỉ người gửi, người nhận cuối hoặc Courier ĐÃ ĐƯỢC CHỌN mới thấy địa điểm chi tiết.
  v_can_see_details := (
    p_actor = v_task.sender_id
    or p_actor = v_task.final_receiver_id
    or p_actor = v_task.assigned_courier_id
  );

  return jsonb_build_object(
    'id', v_task.id,
    'transaction_id', v_task.transaction_id,
    'sender_id', v_task.sender_id,
    'final_receiver_id', v_task.final_receiver_id,
    'assigned_courier_id', v_task.assigned_courier_id,
    'status', v_task.status,
    'pickup_description', case when v_can_see_details then v_task.pickup_description else null end,
    'dropoff_description', case when v_can_see_details then v_task.dropoff_description else null end,
    'return_handover_id', v_task.return_handover_id,
    'created_at', v_task.created_at
  );
end $$;

create or replace function private.ss_delivery_application_json(p_app_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', a.id,
    'task_id', a.task_id,
    'applicant_id', a.applicant_id,
    'applicant_display', private.ss_display_name(a.applicant_id),
    'status', a.status,
    'created_at', a.created_at
  )
  from public.delivery_applications a
  where a.id = p_app_id;
$$;

create or replace function private.ss_handover_json(p_handover_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', h.id,
    'transaction_id', h.transaction_id,
    'delivery_task_id', h.delivery_task_id,
    'from_user_id', h.from_user_id,
    'to_user_id', h.to_user_id,
    'status', h.status,
    'verification_method', h.verification_method,
    'evidence_photo_count', (
      select count(*)::integer from public.handover_evidence he where he.handover_id = h.id
    ),
    'created_at', h.created_at,
    'confirmed_at', h.confirmed_at
  )
  from public.handovers h
  where h.id = p_handover_id;
$$;

-- 4. Read RPCs ----------------------------------------------------------------

-- Lấy danh sách nhiệm vụ OPEN cho Courier khám phá (ẩn A/B và địa điểm chi tiết).
create or replace function public.get_available_delivery_tasks()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', dt.id,
          'status', dt.status,
          'public_title', 'Nhiệm vụ giao hộ tài liệu'
        )
        order by dt.created_at desc
      )
      from public.delivery_tasks dt
      where dt.status = 'OPEN'
        and dt.sender_id <> v_actor
        and dt.final_receiver_id <> v_actor
    ),
    '[]'::jsonb
  );
end $$;

-- Lấy danh sách nhiệm vụ liên quan tới tôi (gửi, nhận, được giao, hoặc đã ứng tuyển).
create or replace function public.get_my_delivery_tasks()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  return coalesce(
    (
      select jsonb_agg(
        private.ss_delivery_task_json(dt.id, v_actor)
        order by dt.created_at desc
      )
      from public.delivery_tasks dt
      where dt.sender_id = v_actor
        or dt.final_receiver_id = v_actor
        or dt.assigned_courier_id = v_actor
        or exists (
          select 1 from public.delivery_applications da
          where da.task_id = dt.id and da.applicant_id = v_actor
        )
    ),
    '[]'::jsonb
  );
end $$;

-- Lấy chi tiết nhiệm vụ giao hộ + danh sách ứng viên (theo quyền).
create or replace function public.get_delivery_task_details(p_task_id text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_task_id uuid := private.ss_try_uuid(p_task_id);
  v_task public.delivery_tasks%rowtype;
  v_apps jsonb;
begin
  if v_actor is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if v_task_id is null then
    return null;
  end if;

  select * into v_task from public.delivery_tasks where id = v_task_id;
  if not found then
    return null;
  end if;

  -- Chỉ cho xem nếu là bên liên quan hoặc Task đang OPEN.
  if not (
    v_task.status = 'OPEN'
    or v_task.sender_id = v_actor
    or v_task.final_receiver_id = v_actor
    or v_task.assigned_courier_id = v_actor
    or exists (
      select 1 from public.delivery_applications da
      where da.task_id = v_task.id and da.applicant_id = v_actor
    )
  ) then
    return null;
  end if;

  -- Người tạo Task thấy mọi ứng viên; người khác chỉ thấy đơn của chính mình.
  v_apps := coalesce(
    (
      select jsonb_agg(
        private.ss_delivery_application_json(da.id)
        order by da.created_at asc
      )
      from public.delivery_applications da
      where da.task_id = v_task.id
        and (v_task.sender_id = v_actor or da.applicant_id = v_actor)
    ),
    '[]'::jsonb
  );

  return jsonb_build_object(
    'task', private.ss_delivery_task_json(v_task.id, v_actor),
    'applications', v_apps
  );
end $$;

-- Lấy chi tiết 1 lượt bàn giao (chỉ người giao/nhận của chặng hoặc A/B giao dịch).
create or replace function public.get_handover_details(p_handover_id text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_id uuid := private.ss_try_uuid(p_handover_id);
  v_h public.handovers%rowtype;
  v_txn public.transactions%rowtype;
begin
  if v_actor is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if v_id is null then
    return null;
  end if;

  select * into v_h from public.handovers where id = v_id;
  if not found then
    return null;
  end if;

  select * into v_txn from public.transactions where id = v_h.transaction_id;
  if not (
    v_h.from_user_id = v_actor
    or v_h.to_user_id = v_actor
    or v_txn.owner_at_acceptance = v_actor
    or v_txn.receiver_id = v_actor
  ) then
    return null;
  end if;

  return private.ss_handover_json(v_h.id);
end $$;

-- 5. Command RPCs: DeliveryTask & Courier -------------------------------------

create or replace function public.create_delivery_task(
  p_transaction_id text,
  p_final_receiver_id text,
  p_pickup_description text,
  p_dropoff_description text,
  p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'create_delivery_task';
  v_actor uuid := auth.uid();
  v_txn_id uuid := private.ss_try_uuid(p_transaction_id);
  v_receiver_id uuid := private.ss_try_uuid(p_final_receiver_id);
  v_pickup text := trim(coalesce(p_pickup_description, ''));
  v_dropoff text := trim(coalesce(p_dropoff_description, ''));
  v_hash text;
  v_receipt public.command_receipts%rowtype;
  v_txn public.transactions%rowtype;
  v_mat public.materials%rowtype;
  v_task_id uuid;
  v_event_id uuid;
begin
  if v_actor is null then
    return private.ss_err('AUTH_REQUIRED', 'Vui lòng đăng nhập để tiếp tục.');
  end if;
  if nullif(trim(coalesce(p_idempotency_key, '')), '') is null
     or v_txn_id is null or v_receiver_id is null
     or v_pickup = '' or v_dropoff = '' then
    return private.ss_err('INVALID_INPUT', 'Thiếu thông tin điểm lấy/giao hoặc mã giao dịch.');
  end if;

  v_hash := private.ss_payload_hash(
    c_cmd, v_txn_id::text, v_receiver_id::text || '|' || v_pickup || '|' || v_dropoff);

  select * into v_receipt from public.command_receipts
  where actor_id = v_actor and command_name = c_cmd and idempotency_key = p_idempotency_key;
  if found then
    if v_receipt.payload_hash <> v_hash then
      return private.ss_err('CONFLICT', 'Yêu cầu lặp lại không khớp dữ liệu ban đầu.');
    end if;
    return private.ss_ok(
      private.ss_delivery_task_json((v_receipt.result_json->>'entity_id')::uuid, v_actor),
      v_receipt.result_json->>'event_id');
  end if;

  select * into v_txn from public.transactions where id = v_txn_id for update;
  if not found then
    return private.ss_err('FORBIDDEN', 'Không có quyền hoặc giao dịch không tồn tại.');
  end if;

  select * into v_mat from public.materials where id = v_txn.material_id for update;
  if v_mat.holder_id <> v_actor then
    return private.ss_err('FORBIDDEN', 'Chỉ người đang giữ tài liệu hiện tại mới được tạo nhiệm vụ giao hộ.');
  end if;
  if v_actor = v_receiver_id then
    return private.ss_err('INVALID_INPUT', 'Người nhận cuối không thể trùng với người gửi.');
  end if;
  if v_receiver_id not in (v_txn.owner_at_acceptance, v_txn.receiver_id) then
    return private.ss_err('INVALID_INPUT', 'Người nhận cuối phải thuộc giao dịch này.');
  end if;
  if v_txn.status in ('COMPLETED', 'CANCELLED') then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Giao dịch đã kết thúc, không thể tạo nhiệm vụ mới.');
  end if;

  if exists (
    select 1 from public.delivery_tasks dt
    where dt.transaction_id = v_txn_id
      and dt.status in ('OPEN', 'ASSIGNED', 'PICKED_UP', 'DELIVERY_PENDING_CONFIRMATION')
  ) then
    return private.ss_err('CONFLICT', 'Đang có một nhiệm vụ giao hộ hoạt động cho giao dịch này.');
  end if;

  insert into public.delivery_tasks(
    transaction_id, sender_id, final_receiver_id, status, pickup_description, dropoff_description)
  values (v_txn_id, v_actor, v_receiver_id, 'OPEN', v_pickup, v_dropoff)
  returning id into v_task_id;

  v_event_id := private.ss_append_txn_event(
    v_txn_id, v_actor, 'DELIVERY_TASK_CREATED',
    'Đã tạo nhiệm vụ giao hộ mới chờ sinh viên ứng tuyển.');

  perform private.ss_save_receipt(v_actor, c_cmd, p_idempotency_key, v_hash, v_event_id, v_task_id);
  return private.ss_ok(private.ss_delivery_task_json(v_task_id, v_actor), v_event_id::text);
end $$;

create or replace function public.apply_for_delivery(
  p_task_id text,
  p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'apply_for_delivery';
  v_actor uuid := auth.uid();
  v_task_id uuid := private.ss_try_uuid(p_task_id);
  v_hash text;
  v_receipt public.command_receipts%rowtype;
  v_task public.delivery_tasks%rowtype;
  v_app_id uuid;
  v_event_id uuid;
begin
  if v_actor is null then
    return private.ss_err('AUTH_REQUIRED', 'Vui lòng đăng nhập để tiếp tục.');
  end if;
  if nullif(trim(coalesce(p_idempotency_key, '')), '') is null or v_task_id is null then
    return private.ss_err('INVALID_INPUT', 'Mã nhiệm vụ không hợp lệ.');
  end if;

  v_hash := private.ss_payload_hash(c_cmd, v_task_id::text, v_actor::text);
  select * into v_receipt from public.command_receipts
  where actor_id = v_actor and command_name = c_cmd and idempotency_key = p_idempotency_key;
  if found then
    if v_receipt.payload_hash <> v_hash then
      return private.ss_err('CONFLICT', 'Yêu cầu lặp lại không khớp.');
    end if;
    return private.ss_ok(
      private.ss_delivery_application_json((v_receipt.result_json->>'entity_id')::uuid),
      v_receipt.result_json->>'event_id');
  end if;

  select * into v_task from public.delivery_tasks where id = v_task_id for update;
  if not found then
    return private.ss_err('INVALID_INPUT', 'Không tìm thấy nhiệm vụ giao hộ.');
  end if;
  if v_task.status <> 'OPEN' then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Nhiệm vụ này đã đóng ứng tuyển.');
  end if;
  if v_actor in (v_task.sender_id, v_task.final_receiver_id) then
    return private.ss_err('FORBIDDEN', 'Người gửi hoặc người nhận không thể tự ứng tuyển giao hộ.');
  end if;
  if exists (
    select 1 from public.delivery_applications
    where task_id = v_task_id and applicant_id = v_actor
  ) then
    return private.ss_err('DUPLICATE_REQUEST', 'Bạn đã ứng tuyển nhiệm vụ này rồi.');
  end if;

  insert into public.delivery_applications(task_id, applicant_id, status)
  values (v_task_id, v_actor, 'PENDING')
  returning id into v_app_id;

  v_event_id := private.ss_append_txn_event(
    v_task.transaction_id, v_actor, 'DELIVERY_APPLIED',
    'Có một sinh viên ứng tuyển nhận nhiệm vụ giao hộ.');

  perform private.ss_save_receipt(v_actor, c_cmd, p_idempotency_key, v_hash, v_event_id, v_app_id);
  return private.ss_ok(private.ss_delivery_application_json(v_app_id), v_event_id::text);
end $$;

create or replace function public.select_courier(
  p_task_id text,
  p_application_id text,
  p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'select_courier';
  v_actor uuid := auth.uid();
  v_task_id uuid := private.ss_try_uuid(p_task_id);
  v_app_id uuid := private.ss_try_uuid(p_application_id);
  v_hash text;
  v_receipt public.command_receipts%rowtype;
  v_task public.delivery_tasks%rowtype;
  v_app public.delivery_applications%rowtype;
  v_event_id uuid;
begin
  if v_actor is null then
    return private.ss_err('AUTH_REQUIRED', 'Vui lòng đăng nhập để tiếp tục.');
  end if;
  if nullif(trim(coalesce(p_idempotency_key, '')), '') is null
     or v_task_id is null or v_app_id is null then
    return private.ss_err('INVALID_INPUT', 'Tham số chọn người giao hộ không hợp lệ.');
  end if;

  v_hash := private.ss_payload_hash(c_cmd, v_task_id::text, v_app_id::text);
  select * into v_receipt from public.command_receipts
  where actor_id = v_actor and command_name = c_cmd and idempotency_key = p_idempotency_key;
  if found then
    if v_receipt.payload_hash <> v_hash then
      return private.ss_err('CONFLICT', 'Yêu cầu lặp lại không khớp.');
    end if;
    return private.ss_ok(
      private.ss_delivery_task_json(v_task_id, v_actor),
      v_receipt.result_json->>'event_id');
  end if;

  select * into v_task from public.delivery_tasks where id = v_task_id for update;
  if not found or v_task.sender_id <> v_actor then
    return private.ss_err('FORBIDDEN', 'Chỉ người tạo nhiệm vụ mới được chọn người giao hộ.');
  end if;
  if v_task.status <> 'OPEN' then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Nhiệm vụ đã được phân công hoặc đóng.');
  end if;

  select * into v_app from public.delivery_applications
  where id = v_app_id and task_id = v_task_id for update;
  if not found or v_app.status <> 'PENDING' then
    return private.ss_err('INVALID_INPUT', 'Đơn ứng tuyển không hợp lệ hoặc đã xử lý.');
  end if;

  -- Nguyên tử: 1 ACCEPTED, các đơn PENDING khác REJECTED, Task ASSIGNED.
  update public.delivery_applications set status = 'ACCEPTED' where id = v_app_id;
  update public.delivery_applications set status = 'REJECTED'
  where task_id = v_task_id and id <> v_app_id and status = 'PENDING';

  update public.delivery_tasks
  set status = 'ASSIGNED', assigned_courier_id = v_app.applicant_id
  where id = v_task_id;

  v_event_id := private.ss_append_txn_event(
    v_task.transaction_id, v_actor, 'COURIER_SELECTED',
    'Người gửi đã chọn một sinh viên giao hộ.');

  perform private.ss_save_receipt(v_actor, c_cmd, p_idempotency_key, v_hash, v_event_id, v_task_id);
  return private.ss_ok(private.ss_delivery_task_json(v_task_id, v_actor), v_event_id::text);
end $$;

create or replace function public.withdraw_delivery_application(
  p_task_id text,
  p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'withdraw_delivery_application';
  v_actor uuid := auth.uid();
  v_task_id uuid := private.ss_try_uuid(p_task_id);
  v_hash text;
  v_receipt public.command_receipts%rowtype;
  v_task public.delivery_tasks%rowtype;
  v_app public.delivery_applications%rowtype;
  v_event_id uuid;
begin
  if v_actor is null then
    return private.ss_err('AUTH_REQUIRED', 'Vui lòng đăng nhập để tiếp tục.');
  end if;
  if nullif(trim(coalesce(p_idempotency_key, '')), '') is null or v_task_id is null then
    return private.ss_err('INVALID_INPUT', 'Mã nhiệm vụ không hợp lệ.');
  end if;

  v_hash := private.ss_payload_hash(c_cmd, v_task_id::text, v_actor::text);
  select * into v_receipt from public.command_receipts
  where actor_id = v_actor and command_name = c_cmd and idempotency_key = p_idempotency_key;
  if found then
    if v_receipt.payload_hash <> v_hash then
      return private.ss_err('CONFLICT', 'Yêu cầu lặp lại không khớp.');
    end if;
    return private.ss_ok(
      private.ss_delivery_task_json(v_task_id, v_actor),
      v_receipt.result_json->>'event_id');
  end if;

  select * into v_task from public.delivery_tasks where id = v_task_id for update;
  if not found then
    return private.ss_err('INVALID_INPUT', 'Không tìm thấy nhiệm vụ.');
  end if;

  -- Nếu đang PENDING -> WITHDRAWN. Nếu đã ASSIGNED mà chưa PICKED_UP -> hủy Task (MVP-D04).
  select * into v_app from public.delivery_applications
  where task_id = v_task_id and applicant_id = v_actor for update;
  if not found then
    return private.ss_err('FORBIDDEN', 'Bạn không có đơn ứng tuyển ở nhiệm vụ này.');
  end if;

  if v_app.status = 'PENDING' and v_task.status = 'OPEN' then
    update public.delivery_applications set status = 'WITHDRAWN' where id = v_app.id;
    v_event_id := private.ss_append_txn_event(
      v_task.transaction_id, v_actor, 'DELIVERY_APPLICATION_WITHDRAWN',
      'Ứng viên giao hộ đã rút đơn trước khi phân công.');
  elsif v_app.status = 'ACCEPTED' and v_task.status = 'ASSIGNED' then
    if exists (
      select 1 from public.handovers h
      where h.delivery_task_id = v_task_id and h.status = 'CONFIRMED'
    ) then
      return private.ss_err('INVALID_TRANSACTION_TRANSITION',
        'Đã nhận tài liệu, không thể rút nhanh. Phải dùng quy trình báo giao thất bại.');
    end if;
    update public.delivery_tasks set status = 'CANCELLED' where id = v_task_id;
    v_event_id := private.ss_append_txn_event(
      v_task.transaction_id, v_actor, 'DELIVERY_TASK_CANCELLED',
      'Người giao hộ xin rút trước khi nhận sách, nhiệm vụ đã hủy.');
  else
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Không thể rút đơn ở trạng thái hiện tại.');
  end if;

  perform private.ss_save_receipt(v_actor, c_cmd, p_idempotency_key, v_hash, v_event_id, v_task_id);
  return private.ss_ok(private.ss_delivery_task_json(v_task_id, v_actor), v_event_id::text);
end $$;

-- 6. Command RPCs: Handover, QR, Evidence & Confirmation ----------------------

create or replace function public.create_handover(
  p_transaction_id text,
  p_to_user_id text,
  p_delivery_task_id text,
  p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'create_handover';
  v_actor uuid := auth.uid();
  v_txn_id uuid := private.ss_try_uuid(p_transaction_id);
  v_to_id uuid := private.ss_try_uuid(p_to_user_id);
  v_task_id uuid := private.ss_try_uuid(p_delivery_task_id);
  v_hash text;
  v_receipt public.command_receipts%rowtype;
  v_txn public.transactions%rowtype;
  v_mat public.materials%rowtype;
  v_pay public.payment_confirmations%rowtype;
  v_handover_id uuid;
  v_event_id uuid;
begin
  if v_actor is null then
    return private.ss_err('AUTH_REQUIRED', 'Vui lòng đăng nhập để tiếp tục.');
  end if;
  if nullif(trim(coalesce(p_idempotency_key, '')), '') is null
     or v_txn_id is null or v_to_id is null then
    return private.ss_err('INVALID_INPUT', 'Thiếu thông tin giao dịch hoặc người nhận.');
  end if;

  v_hash := private.ss_payload_hash(
    c_cmd, v_txn_id::text, v_to_id::text || '|' || coalesce(v_task_id::text, ''));
  select * into v_receipt from public.command_receipts
  where actor_id = v_actor and command_name = c_cmd and idempotency_key = p_idempotency_key;
  if found then
    if v_receipt.payload_hash <> v_hash then
      return private.ss_err('CONFLICT', 'Yêu cầu lặp lại không khớp.');
    end if;
    return private.ss_ok(
      private.ss_handover_json((v_receipt.result_json->>'entity_id')::uuid),
      v_receipt.result_json->>'event_id');
  end if;

  select * into v_txn from public.transactions where id = v_txn_id for update;
  if not found then
    return private.ss_err('FORBIDDEN', 'Không có quyền hoặc giao dịch không tồn tại.');
  end if;
  if v_txn.status in ('COMPLETED', 'CANCELLED') then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Giao dịch đã kết thúc.');
  end if;

  -- BẤT BIẾN SELL (INV-07): Trước khi A xác nhận tiền, cấm tạo bất kỳ Handover SELL nào.
  if v_txn.type = 'SELL' then
    select * into v_pay from public.payment_confirmations where transaction_id = v_txn_id;
    if not found or v_pay.seller_confirmed_at is null then
      return private.ss_err('PAYMENT_NOT_CONFIRMED',
        'Giao dịch bán chỉ được bắt đầu bàn giao sau khi người bán xác nhận đã nhận tiền.');
    end if;
  end if;

  select * into v_mat from public.materials where id = v_txn.material_id for update;
  if v_mat.holder_id <> v_actor then
    return private.ss_err('INVALID_HANDOVER_PARTICIPANT',
      'Chỉ người đang giữ tài liệu trên hệ thống mới có quyền lập lượt bàn giao.');
  end if;
  if v_actor = v_to_id then
    return private.ss_err('INVALID_INPUT', 'Người giao và người nhận không thể trùng nhau.');
  end if;

  if exists (
    select 1 from public.handovers h
    where h.transaction_id = v_txn_id
      and h.status in ('PENDING', 'AWAITING_RECEIVER_CONFIRMATION')
  ) then
    return private.ss_err('CONFLICT', 'Đang có một lượt bàn giao chưa hoàn tất cho giao dịch này.');
  end if;

  insert into public.handovers(
    transaction_id, delivery_task_id, from_user_id, to_user_id, status)
  values (v_txn_id, v_task_id, v_actor, v_to_id, 'PENDING')
  returning id into v_handover_id;

  -- Chuyển Transaction sang giai đoạn đang bàn giao (đi hoặc trả).
  if v_txn.status = 'AWAITING_HANDOVER' then
    update public.transactions set status = 'HANDOVER_IN_PROGRESS' where id = v_txn_id;
  elsif v_txn.status in ('BORROWING', 'RETURN_PENDING') then
    update public.transactions set status = 'RETURN_IN_PROGRESS' where id = v_txn_id;
  end if;

  v_event_id := private.ss_append_txn_event(
    v_txn_id, v_actor, 'HANDOVER_CREATED',
    'Đã khởi tạo lượt bàn giao tài liệu mới.');

  perform private.ss_save_receipt(v_actor, c_cmd, p_idempotency_key, v_hash, v_event_id, v_handover_id);
  return private.ss_ok(private.ss_handover_json(v_handover_id), v_event_id::text);
end $$;

create or replace function public.verify_material_code(
  p_handover_id text,
  p_scanned_code text,
  p_verification_method text,
  p_fallback_reason text,
  p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'verify_material_code';
  v_actor uuid := auth.uid();
  v_h_id uuid := private.ss_try_uuid(p_handover_id);
  v_method text := upper(trim(coalesce(p_verification_method, 'QR')));
  v_code text := trim(coalesce(p_scanned_code, ''));
  v_reason text := trim(coalesce(p_fallback_reason, ''));
  v_hash text;
  v_receipt public.command_receipts%rowtype;
  v_h public.handovers%rowtype;
  v_txn public.transactions%rowtype;
  v_qr_secret text;
  v_event_id uuid;
begin
  if v_actor is null then
    return private.ss_err('AUTH_REQUIRED', 'Vui lòng đăng nhập để tiếp tục.');
  end if;
  if nullif(trim(coalesce(p_idempotency_key, '')), '') is null or v_h_id is null then
    return private.ss_err('INVALID_INPUT', 'Mã lượt bàn giao không hợp lệ.');
  end if;
  if v_method not in ('QR', 'FALLBACK') then
    return private.ss_err('INVALID_INPUT', 'Phương thức đối chiếu phải là QR hoặc FALLBACK.');
  end if;

  v_hash := private.ss_payload_hash(c_cmd, v_h_id::text, v_method || '|' || v_code || '|' || v_reason);
  select * into v_receipt from public.command_receipts
  where actor_id = v_actor and command_name = c_cmd and idempotency_key = p_idempotency_key;
  if found then
    if v_receipt.payload_hash <> v_hash then
      return private.ss_err('CONFLICT', 'Yêu cầu lặp lại không khớp.');
    end if;
    return private.ss_ok(private.ss_handover_json(v_h_id), v_receipt.result_json->>'event_id');
  end if;

  select * into v_h from public.handovers where id = v_h_id for update;
  if not found or v_h.from_user_id <> v_actor then
    return private.ss_err('INVALID_HANDOVER_PARTICIPANT', 'Chỉ người giao của chặng này mới được đối chiếu mã.');
  end if;
  if v_h.status <> 'PENDING' then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Lượt bàn giao không còn ở trạng thái chờ đối chiếu.');
  end if;

  select * into v_txn from public.transactions where id = v_h.transaction_id;

  if v_method = 'QR' then
    if v_code = '' then
      return private.ss_err('INVALID_INPUT', 'Vui lòng cung cấp chuỗi mã QR đã quét.');
    end if;
    select qr_secret into v_qr_secret
    from public.material_qr_credentials
    where material_id = v_txn.material_id;

    -- BẤT BIẾN INV-05: QR đọc được nhưng sai -> QR_MISMATCH (Hard block).
    if v_code <> v_txn.material_id::text
       and v_code <> v_h.id::text
       and (v_qr_secret is null or v_code <> v_qr_secret) then
      return private.ss_err('QR_MISMATCH',
        'Mã QR không khớp với tài liệu hoặc chặng bàn giao này. Tuyệt đối không dùng đối chiếu thủ công để bỏ qua.');
    end if;

    update public.handovers
    set verification_method = 'QR', fallback_reason = null
    where id = v_h_id;
  else
    if v_reason = '' then
      return private.ss_err('INVALID_INPUT', 'Đối chiếu thủ công bắt buộc phải ghi rõ lý do.');
    end if;
    update public.handovers
    set verification_method = 'FALLBACK', fallback_reason = v_reason
    where id = v_h_id;
  end if;

  v_event_id := private.ss_append_txn_event(
    v_h.transaction_id, v_actor, 'HANDOVER_VERIFIED',
    'Đã hoàn tất bước đối chiếu tài liệu cho lượt bàn giao.');

  perform private.ss_save_receipt(v_actor, c_cmd, p_idempotency_key, v_hash, v_event_id, v_h_id);
  return private.ss_ok(private.ss_handover_json(v_h_id), v_event_id::text);
end $$;

create or replace function public.submit_handover_evidence(
  p_handover_id text,
  p_storage_paths text[],
  p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'submit_handover_evidence';
  v_actor uuid := auth.uid();
  v_h_id uuid := private.ss_try_uuid(p_handover_id);
  v_hash text;
  v_receipt public.command_receipts%rowtype;
  v_h public.handovers%rowtype;
  v_task public.delivery_tasks%rowtype;
  v_path text;
  v_event_id uuid;
begin
  if v_actor is null then
    return private.ss_err('AUTH_REQUIRED', 'Vui lòng đăng nhập để tiếp tục.');
  end if;
  if nullif(trim(coalesce(p_idempotency_key, '')), '') is null or v_h_id is null then
    return private.ss_err('INVALID_INPUT', 'Mã lượt bàn giao không hợp lệ.');
  end if;
  if p_storage_paths is null or coalesce(array_length(p_storage_paths, 1), 0) < 1 then
    return private.ss_err('EVIDENCE_REQUIRED',
      'Bắt buộc phải tải lên ít nhất 1 ảnh minh chứng trước khi chuyển sang chờ nhận.');
  end if;

  v_hash := private.ss_payload_hash(c_cmd, v_h_id::text, array_to_string(p_storage_paths, ','));
  select * into v_receipt from public.command_receipts
  where actor_id = v_actor and command_name = c_cmd and idempotency_key = p_idempotency_key;
  if found then
    if v_receipt.payload_hash <> v_hash then
      return private.ss_err('CONFLICT', 'Yêu cầu lặp lại không khớp.');
    end if;
    return private.ss_ok(private.ss_handover_json(v_h_id), v_receipt.result_json->>'event_id');
  end if;

  select * into v_h from public.handovers where id = v_h_id for update;
  if not found or v_h.from_user_id <> v_actor then
    return private.ss_err('INVALID_HANDOVER_PARTICIPANT', 'Chỉ người giao mới được nộp ảnh minh chứng.');
  end if;
  if v_h.status <> 'PENDING' then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Lượt bàn giao đã nộp minh chứng hoặc kết thúc.');
  end if;
  if v_h.verification_method is null then
    return private.ss_err('INVALID_INPUT', 'Phải đối chiếu mã QR hoặc lý do hợp lệ trước khi nộp ảnh.');
  end if;

  foreach v_path in array p_storage_paths loop
    if trim(coalesce(v_path, '')) = '' then
      return private.ss_err('INVALID_INPUT', 'Đường dẫn ảnh minh chứng không hợp lệ.');
    end if;
    insert into public.handover_evidence(handover_id, uploaded_by, private_path)
    values (v_h_id, v_actor, trim(v_path));
  end loop;

  update public.handovers set status = 'AWAITING_RECEIVER_CONFIRMATION' where id = v_h_id;

  if v_h.delivery_task_id is not null then
    select * into v_task from public.delivery_tasks where id = v_h.delivery_task_id for update;
    if found and v_task.assigned_courier_id = v_actor and v_task.status = 'PICKED_UP' then
      update public.delivery_tasks set status = 'DELIVERY_PENDING_CONFIRMATION' where id = v_task.id;
    end if;
  end if;

  v_event_id := private.ss_append_txn_event(
    v_h.transaction_id, v_actor, 'HANDOVER_EVIDENCE_SUBMITTED',
    'Người giao đã nộp ảnh minh chứng, đang chờ người nhận xác nhận.');

  perform private.ss_save_receipt(v_actor, c_cmd, p_idempotency_key, v_hash, v_event_id, v_h_id);
  return private.ss_ok(private.ss_handover_json(v_h_id), v_event_id::text);
end $$;

create or replace function public.confirm_handover(
  p_handover_id text,
  p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'confirm_handover';
  v_actor uuid := auth.uid();
  v_h_id uuid := private.ss_try_uuid(p_handover_id);
  v_hash text;
  v_receipt public.command_receipts%rowtype;
  v_h public.handovers%rowtype;
  v_txn public.transactions%rowtype;
  v_mat public.materials%rowtype;
  v_task public.delivery_tasks%rowtype;
  v_pay public.payment_confirmations%rowtype;
  v_today_vn date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_event_id uuid;
begin
  if v_actor is null then
    return private.ss_err('AUTH_REQUIRED', 'Vui lòng đăng nhập để tiếp tục.');
  end if;
  if nullif(trim(coalesce(p_idempotency_key, '')), '') is null or v_h_id is null then
    return private.ss_err('INVALID_INPUT', 'Mã lượt bàn giao không hợp lệ.');
  end if;

  v_hash := private.ss_payload_hash(c_cmd, v_h_id::text, v_actor::text);
  select * into v_receipt from public.command_receipts
  where actor_id = v_actor and command_name = c_cmd and idempotency_key = p_idempotency_key;
  if found then
    if v_receipt.payload_hash <> v_hash then
      return private.ss_err('CONFLICT', 'Yêu cầu lặp lại không khớp.');
    end if;
    return private.ss_ok(private.ss_handover_json(v_h_id), v_receipt.result_json->>'event_id');
  end if;

  select * into v_h from public.handovers where id = v_h_id for update;
  if not found then
    return private.ss_err('INVALID_INPUT', 'Không tìm thấy lượt bàn giao.');
  end if;
  -- BẤT BIẾN INV-04: Chỉ đúng người nhận mới được bấm xác nhận.
  if v_h.to_user_id <> v_actor then
    return private.ss_err('INVALID_HANDOVER_PARTICIPANT',
      'Chỉ người nhận chỉ định của chặng này mới có quyền xác nhận.');
  end if;
  if v_h.status <> 'AWAITING_RECEIVER_CONFIRMATION' then
    return private.ss_err('RECEIVER_CONFIRMATION_REQUIRED',
      'Lượt bàn giao chưa sẵn sàng để xác nhận nhận tài liệu.');
  end if;

  select * into v_txn from public.transactions where id = v_h.transaction_id for update;
  select * into v_mat from public.materials where id = v_txn.material_id for update;

  -- Nếu là SELL, kiểm tra lại seller_confirmed_at một lần nữa trước khi đổi owner/hoàn tất.
  if v_txn.type = 'SELL' then
    select * into v_pay from public.payment_confirmations where transaction_id = v_txn.id;
    if not found or v_pay.seller_confirmed_at is null then
      return private.ss_err('PAYMENT_NOT_CONFIRMED', 'Chưa có xác nhận đã nhận tiền từ người bán.');
    end if;
  end if;

  -- Nguyên tử: Handover CONFIRMED + chuyển holder_id sang receiver.
  update public.handovers
  set status = 'CONFIRMED', confirmed_at = now()
  where id = v_h_id;

  update public.materials set holder_id = v_actor where id = v_mat.id;

  -- Cập nhật DeliveryTask nếu chặng này thuộc một DeliveryTask.
  if v_h.delivery_task_id is not null then
    select * into v_task from public.delivery_tasks where id = v_h.delivery_task_id for update;
    if found then
      if v_actor = v_task.assigned_courier_id then
        update public.delivery_tasks set status = 'PICKED_UP' where id = v_task.id;
      elsif v_actor = v_task.final_receiver_id and v_task.status in ('PICKED_UP', 'DELIVERY_PENDING_CONFIRMATION') then
        update public.delivery_tasks set status = 'COMPLETED' where id = v_task.id;
      end if;
    end if;
  end if;

  -- Cập nhật Transaction & BorrowingRecord & Listing theo loại giao dịch:
  if v_txn.type = 'BORROW' then
    if v_actor = v_txn.receiver_id and v_txn.status in ('AWAITING_HANDOVER', 'HANDOVER_IN_PROGRESS') then
      update public.transactions set status = 'BORROWING' where id = v_txn.id;
      insert into public.borrowing_records(transaction_id, started_at, due_date)
      values (v_txn.id, now(), v_today_vn + coalesce(v_txn.agreed_borrow_days, 7))
      on conflict (transaction_id) do update
        set started_at = excluded.started_at, due_date = excluded.due_date;
    elsif v_actor = v_txn.owner_at_acceptance and v_txn.status in ('RETURN_PENDING', 'RETURN_IN_PROGRESS') then
      update public.transactions set status = 'COMPLETED' where id = v_txn.id;
      update public.borrowing_records set final_return_confirmed_at = now() where transaction_id = v_txn.id;
      update public.listings set status = 'ARCHIVED' where id = v_txn.listing_id;
    elsif v_txn.status in ('RETURN_PENDING', 'RETURN_IN_PROGRESS') and v_h.from_user_id = v_txn.receiver_id then
      -- Chiều trả B -> C: ghi mốc return_to_courier_at, KHÔNG hoàn tất giao dịch sớm.
      update public.borrowing_records set return_to_courier_at = now() where transaction_id = v_txn.id;
    elsif v_txn.status in ('RETURN_PENDING', 'RETURN_IN_PROGRESS') and v_actor = v_txn.receiver_id then
      -- C -> B phục hồi ở chiều trả: cấp hạn 3 ngày lịch VN tái bàn giao.
      update public.borrowing_records set re_handover_due_date = v_today_vn + 3 where transaction_id = v_txn.id;
    end if;
  elsif v_txn.type in ('DONATE', 'SELL') and v_actor = v_txn.receiver_id then
    -- B nhận cuối DONATE/SELL -> đổi owner sang B, hoàn tất Transaction, archive Listing.
    update public.materials set owner_id = v_actor where id = v_mat.id;
    update public.transactions set status = 'COMPLETED' where id = v_txn.id;
    update public.listings set status = 'ARCHIVED' where id = v_txn.listing_id;
  end if;

  v_event_id := private.ss_append_txn_event(
    v_txn.id, v_actor, 'HANDOVER_CONFIRMED',
    'Người nhận đã xác nhận nhận tài liệu thành công.');

  perform private.ss_save_receipt(v_actor, c_cmd, p_idempotency_key, v_hash, v_event_id, v_h_id);
  return private.ss_ok(private.ss_handover_json(v_h_id), v_event_id::text);
end $$;

create or replace function public.refuse_handover(
  p_handover_id text,
  p_reason text,
  p_issue_type text,
  p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'refuse_handover';
  v_actor uuid := auth.uid();
  v_h_id uuid := private.ss_try_uuid(p_handover_id);
  v_reason text := trim(coalesce(p_reason, ''));
  v_type text := upper(trim(coalesce(p_issue_type, 'WRONG_MATERIAL')));
  v_hash text;
  v_receipt public.command_receipts%rowtype;
  v_h public.handovers%rowtype;
  v_issue_id uuid;
  v_event_id uuid;
begin
  if v_actor is null then
    return private.ss_err('AUTH_REQUIRED', 'Vui lòng đăng nhập để tiếp tục.');
  end if;
  if nullif(trim(coalesce(p_idempotency_key, '')), '') is null
     or v_h_id is null or v_reason = '' then
    return private.ss_err('INVALID_INPUT', 'Vui lòng nhập lý do từ chối cụ thể.');
  end if;

  v_hash := private.ss_payload_hash(c_cmd, v_h_id::text, v_type || '|' || v_reason);
  select * into v_receipt from public.command_receipts
  where actor_id = v_actor and command_name = c_cmd and idempotency_key = p_idempotency_key;
  if found then
    if v_receipt.payload_hash <> v_hash then
      return private.ss_err('CONFLICT', 'Yêu cầu lặp lại không khớp.');
    end if;
    return private.ss_ok(private.ss_handover_json(v_h_id), v_receipt.result_json->>'event_id');
  end if;

  select * into v_h from public.handovers where id = v_h_id for update;
  if not found or v_h.to_user_id <> v_actor then
    return private.ss_err('INVALID_HANDOVER_PARTICIPANT', 'Chỉ người nhận của chặng này mới có quyền từ chối.');
  end if;
  if v_h.status <> 'AWAITING_RECEIVER_CONFIRMATION' then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Lượt bàn giao không ở trạng thái chờ xác nhận.');
  end if;

  -- Chuyển Handover sang DISPUTED, tạo Issue OPEN, KHÔNG đổi holder_id/owner_id.
  update public.handovers set status = 'DISPUTED' where id = v_h_id;

  insert into public.issues(transaction_id, handover_id, reporter_id, issue_type, reason, status)
  values (v_h.transaction_id, v_h_id, v_actor, v_type, v_reason, 'OPEN')
  returning id into v_issue_id;

  perform private.ss_append_issue_event(v_issue_id, v_actor, 'ISSUE_OPENED', 'Từ chối nhận tài liệu: ' || v_reason);
  v_event_id := private.ss_append_txn_event(
    v_h.transaction_id, v_actor, 'HANDOVER_DISPUTED',
    'Người nhận đã từ chối nhận tài liệu và mở sự cố.');

  perform private.ss_save_receipt(v_actor, c_cmd, p_idempotency_key, v_hash, v_event_id, v_issue_id);
  return private.ss_ok(private.ss_handover_json(v_h_id), v_event_id::text);
end $$;

create or replace function public.fail_delivery_task(
  p_task_id text,
  p_reason text,
  p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c_cmd constant text := 'fail_delivery_task';
  v_actor uuid := auth.uid();
  v_task_id uuid := private.ss_try_uuid(p_task_id);
  v_reason text := trim(coalesce(p_reason, ''));
  v_hash text;
  v_receipt public.command_receipts%rowtype;
  v_task public.delivery_tasks%rowtype;
  v_return_h_id uuid;
  v_event_id uuid;
begin
  if v_actor is null then
    return private.ss_err('AUTH_REQUIRED', 'Vui lòng đăng nhập để tiếp tục.');
  end if;
  if nullif(trim(coalesce(p_idempotency_key, '')), '') is null
     or v_task_id is null or v_reason = '' then
    return private.ss_err('INVALID_INPUT', 'Vui lòng cung cấp lý do giao thất bại.');
  end if;

  v_hash := private.ss_payload_hash(c_cmd, v_task_id::text, v_reason);
  select * into v_receipt from public.command_receipts
  where actor_id = v_actor and command_name = c_cmd and idempotency_key = p_idempotency_key;
  if found then
    if v_receipt.payload_hash <> v_hash then
      return private.ss_err('CONFLICT', 'Yêu cầu lặp lại không khớp.');
    end if;
    return private.ss_ok(private.ss_delivery_task_json(v_task_id, v_actor), v_receipt.result_json->>'event_id');
  end if;

  select * into v_task from public.delivery_tasks where id = v_task_id for update;
  if not found or v_task.assigned_courier_id <> v_actor then
    return private.ss_err('FORBIDDEN', 'Chỉ người giao hộ đang giữ sách mới được báo giao thất bại.');
  end if;
  if v_task.status not in ('PICKED_UP', 'DELIVERY_PENDING_CONFIRMATION') then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Chỉ báo thất bại sau khi đã lấy sách.');
  end if;

  -- Tạo Handover phục hồi từ C trả về người đã trực tiếp giao sách cho C (sender_id).
  -- BẤT BIẾN INV-08: holder_id vẫn là C cho tới khi sender_id xác nhận nhận lại.
  insert into public.handovers(transaction_id, delivery_task_id, from_user_id, to_user_id, status)
  values (v_task.transaction_id, v_task_id, v_actor, v_task.sender_id, 'PENDING')
  returning id into v_return_h_id;

  update public.delivery_tasks
  set status = 'FAILED', return_handover_id = v_return_h_id
  where id = v_task_id;

  v_event_id := private.ss_append_txn_event(
    v_task.transaction_id, v_actor, 'DELIVERY_FAILED',
    'Giao hộ thất bại (' || v_reason || '). Đã tạo lượt bàn giao trả về người gửi.');

  perform private.ss_save_receipt(v_actor, c_cmd, p_idempotency_key, v_hash, v_event_id, v_task_id);
  return private.ss_ok(private.ss_delivery_task_json(v_task_id, v_actor), v_event_id::text);
end $$;

create or replace function public.rate_courier(
  p_task_id text,
  p_stars integer
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_task_id uuid := private.ss_try_uuid(p_task_id);
  v_task public.delivery_tasks%rowtype;
begin
  if v_actor is null then
    return private.ss_err('AUTH_REQUIRED', 'Vui lòng đăng nhập để tiếp tục.');
  end if;
  if v_task_id is null or p_stars is null or p_stars < 1 or p_stars > 5 then
    return private.ss_err('INVALID_INPUT', 'Số sao đánh giá phải từ 1 đến 5.');
  end if;

  select * into v_task from public.delivery_tasks where id = v_task_id;
  if not found or v_actor not in (v_task.sender_id, v_task.final_receiver_id) then
    return private.ss_err('FORBIDDEN', 'Chỉ người gửi hoặc người nhận cuối của nhiệm vụ mới được đánh giá.');
  end if;
  if v_task.status <> 'COMPLETED' then
    return private.ss_err('INVALID_TRANSACTION_TRANSITION', 'Chỉ đánh giá sau khi nhiệm vụ đã hoàn tất.');
  end if;

  insert into public.courier_ratings(task_id, rater_id, stars)
  values (v_task_id, v_actor, p_stars)
  on conflict (task_id, rater_id) do nothing;

  return private.ss_ok(jsonb_build_object('task_id', v_task_id, 'stars', p_stars), gen_random_uuid()::text);
end $$;

-- 7. Phân quyền EXECUTE cho RPC -----------------------------------------------

revoke all on all functions in schema private from public, anon, authenticated;

do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'get_available_delivery_tasks()',
    'get_my_delivery_tasks()',
    'get_delivery_task_details(text)',
    'get_handover_details(text)',
    'create_delivery_task(text, text, text, text, text)',
    'apply_for_delivery(text, text)',
    'select_courier(text, text, text)',
    'withdraw_delivery_application(text, text)',
    'create_handover(text, text, text, text)',
    'verify_material_code(text, text, text, text, text)',
    'submit_handover_evidence(text, text[], text)',
    'confirm_handover(text, text)',
    'refuse_handover(text, text, text, text)',
    'fail_delivery_task(text, text, text)',
    'rate_courier(text, integer)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', v_fn);
    execute format('grant execute on function public.%s to authenticated', v_fn);
  end loop;
end $$;
