-- StudyShare: nghiệp vụ người mượn yêu cầu trả tài liệu.
--
-- Chỉ chuyển BORROWING -> RETURN_PENDING.
-- Không thay owner_id, holder_id, due_date hoặc tự hoàn tất giao dịch.
-- Lệnh có idempotency receipt và TransactionEvent theo contract chung.

create or replace function public.request_borrow_return(
  p_transaction_id text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_cmd constant text := 'request_borrow_return';
  v_early jsonb;
  v_transaction public.transactions;
  v_event_id uuid;
begin
  -- Helper chung kiểm tra:
  -- session, idempotency key, quyền A/B, khóa Transaction và retry.
  v_early := private.ss_begin_txn_command(
    c_cmd,
    p_transaction_id,
    p_idempotency_key,
    ''
  );

  if v_early is not null then
    return v_early;
  end if;

  select *
  into v_transaction
  from public.transactions
  where id = private.ss_try_uuid(p_transaction_id);

  if not found then
    return private.ss_err(
      'FORBIDDEN',
      'Bạn không có quyền thực hiện thao tác này.'
    );
  end if;

  if v_transaction.type <> 'BORROW' then
    return private.ss_err(
      'INVALID_TRANSACTION_TRANSITION',
      'Chỉ giao dịch cho mượn mới có thể yêu cầu trả.'
    );
  end if;

  if v_transaction.receiver_id <> auth.uid() then
    return private.ss_err(
      'FORBIDDEN',
      'Chỉ người đang mượn mới có thể yêu cầu trả tài liệu.'
    );
  end if;

  if v_transaction.status <> 'BORROWING' then
    return private.ss_err(
      'INVALID_TRANSACTION_TRANSITION',
      'Giao dịch không ở trạng thái đang mượn.'
    );
  end if;

  -- Chỉ ghi nhận ý định trả.
  -- holder_id vẫn giữ nguyên cho tới Handover trả được xác nhận.
  update public.transactions
  set status = 'RETURN_PENDING'
  where id = v_transaction.id;

  v_event_id := private.ss_append_txn_event(
    v_transaction.id,
    auth.uid(),
    'RETURN_REQUESTED',
    'Người mượn đã gửi yêu cầu trả tài liệu.',
    private.ss_source(c_cmd, p_idempotency_key)
  );

  return private.ss_finish_txn_command(
    c_cmd,
    v_transaction.id,
    p_idempotency_key,
    '',
    v_event_id
  );
end;
$$;

revoke all on function public.request_borrow_return(text, text)
from public, anon;

grant execute on function public.request_borrow_return(text, text)
to authenticated;