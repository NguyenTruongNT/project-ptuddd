-- StudyShare - Bổ sung dữ liệu E2E cho Delivery & Handover:
-- 1. Trả về leg1_handover_id và leg2_handover_id thật trong get_delivery_task_details
--    để SCR-17 không phải hardcode ID.
-- 2. Thêm RPC get_handover_evidence_paths có kiểm tra quyền theo chặng để SCR-20
--    tải Signed URL hiển thị ảnh minh chứng thật.

create or replace function public.get_delivery_task_details(p_task_id text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_task_id uuid := private.ss_try_uuid(p_task_id);
  v_task public.delivery_tasks%rowtype;
  v_apps jsonb;
  v_leg1_id uuid;
  v_leg2_id uuid;
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

  -- Lấy ID chặng H1 (sender -> assigned_courier) và H2 (assigned_courier -> final_receiver) mới nhất.
  if v_task.assigned_courier_id is not null then
    select h.id into v_leg1_id
    from public.handovers h
    where h.delivery_task_id = v_task.id
      and h.from_user_id = v_task.sender_id
      and h.to_user_id = v_task.assigned_courier_id
    order by h.created_at desc
    limit 1;

    select h.id into v_leg2_id
    from public.handovers h
    where h.delivery_task_id = v_task.id
      and h.from_user_id = v_task.assigned_courier_id
      and h.to_user_id = v_task.final_receiver_id
    order by h.created_at desc
    limit 1;
  end if;

  return jsonb_build_object(
    'task', private.ss_delivery_task_json(v_task.id, v_actor),
    'applications', v_apps,
    'leg1_handover_id', v_leg1_id,
    'leg2_handover_id', v_leg2_id
  );
end $$;

create or replace function public.get_handover_evidence_paths(p_handover_id text)
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
    return '[]'::jsonb;
  end if;

  select * into v_h from public.handovers where id = v_id;
  if not found then
    return '[]'::jsonb;
  end if;

  select * into v_txn from public.transactions where id = v_h.transaction_id;
  if not (
    v_h.from_user_id = v_actor
    or v_h.to_user_id = v_actor
    or v_txn.owner_at_acceptance = v_actor
    or v_txn.receiver_id = v_actor
  ) then
    return '[]'::jsonb;
  end if;

  return coalesce(
    (
      select jsonb_agg(he.private_path order by he.uploaded_at asc)
      from public.handover_evidence he
      where he.handover_id = v_h.id
    ),
    '[]'::jsonb
  );
end $$;

revoke all on function public.get_handover_evidence_paths(text) from public, anon;
grant execute on function public.get_handover_evidence_paths(text) to authenticated;
