-- StudyShare - SQL schema nền tảng (SS-BR v2.0, CONTRACTS.md).
-- CHỈ khai báo dữ liệu và ràng buộc; chưa cho ứng dụng sửa trạng thái trực tiếp.
-- Không sửa các bảng do Supabase quản lý (auth.users, storage.objects).

-- 1. Hồ sơ người dùng và bản sách vật lý.
create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 100),
  created_at timestamptz not null default now()
);

create table public.materials (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id),
  holder_id uuid not null references auth.users(id),
  title text not null check (char_length(trim(title)) between 1 and 200),
  subject text not null check (char_length(trim(subject)) between 1 and 100),
  condition text not null check (char_length(trim(condition)) between 1 and 100),
  isbn text,
  created_at timestamptz not null default now()
);

create table public.material_images (
  id uuid primary key default gen_random_uuid(),
  material_id uuid not null references public.materials(id) on delete cascade,
  storage_path text not null unique,
  display_order integer not null default 0 check (display_order >= 0),
  uploaded_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

-- Dữ liệu QR bí mật: tuyệt đối không cấp SELECT cho ứng dụng di động.
-- Chỉ RPC có kiểm tra quyền mới được đọc/kiểm chứng token trong tương lai.
create table public.material_qr_credentials (
  material_id uuid primary key references public.materials(id) on delete cascade,
  token_hash text not null,
  created_at timestamptz not null default now()
);

-- 2. Tin đăng, yêu cầu và giao dịch.
create table public.listings (
  id uuid primary key default gen_random_uuid(),
  material_id uuid not null references public.materials(id),
  offer_type text not null check (offer_type in ('BORROW','SELL','DONATE')),
  status text not null default 'DRAFT' check (status in ('DRAFT','PUBLISHED','HIDDEN','ARCHIVED')),
  asking_price_vnd bigint,
  description text,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  check (
    (offer_type = 'SELL' and asking_price_vnd > 0)
    or (offer_type in ('BORROW','DONATE') and asking_price_vnd is null)
  )
);
-- RESERVED là trạng thái suy ra từ giao dịch, không phải trạng thái Listing.
create unique index listings_one_current_per_material
  on public.listings(material_id) where status <> 'ARCHIVED';

create table public.exchange_requests (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id),
  requester_id uuid not null references auth.users(id),
  requested_borrow_days integer check (requested_borrow_days between 1 and 30),
  status text not null default 'PENDING'
    check (status in ('PENDING','ACCEPTED','REJECTED','CANCELLED')),
  reject_reason text,
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
create unique index requests_one_pending_per_user_listing
  on public.exchange_requests(listing_id, requester_id) where status = 'PENDING';
create unique index requests_one_accepted_per_listing
  on public.exchange_requests(listing_id) where status = 'ACCEPTED';

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id),
  request_id uuid not null unique references public.exchange_requests(id),
  material_id uuid not null references public.materials(id),
  type text not null check (type in ('BORROW','SELL','DONATE')),
  owner_at_acceptance uuid not null references auth.users(id),
  receiver_id uuid not null references auth.users(id),
  status text not null,
  agreed_borrow_days integer,
  agreed_price_vnd bigint,
  terms_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  check (owner_at_acceptance <> receiver_id),
  check (
    (type = 'BORROW' and agreed_borrow_days between 1 and 30
      and agreed_price_vnd is null
      and status in ('AWAITING_HANDOVER','HANDOVER_IN_PROGRESS',
                     'BORROWING','RETURN_PENDING','RETURN_IN_PROGRESS',
                     'COMPLETED','CANCELLED'))
    or (type = 'SELL' and agreed_borrow_days is null
      and agreed_price_vnd > 0
      and status in ('AWAITING_PAYMENT','AWAITING_HANDOVER',
                     'HANDOVER_IN_PROGRESS','COMPLETED','CANCELLED'))
    or (type = 'DONATE' and agreed_borrow_days is null
      and agreed_price_vnd is null
      and status in ('AWAITING_HANDOVER','HANDOVER_IN_PROGRESS',
                     'COMPLETED','CANCELLED'))
  )
);
-- Không được có hai giao dịch còn hoạt động trên cùng một bản sách.
create unique index transactions_one_active_per_material
  on public.transactions(material_id)
  where status not in ('COMPLETED','CANCELLED');

create table public.borrowing_records (
  transaction_id uuid primary key references public.transactions(id),
  started_at timestamptz,
  due_date date,
  return_to_courier_at timestamptz,
  final_return_confirmed_at timestamptz,
  re_handover_due_date date
);

create table public.payment_confirmations (
  transaction_id uuid primary key references public.transactions(id),
  amount_vnd bigint not null check (amount_vnd > 0),
  buyer_reported_at timestamptz,
  seller_confirmed_at timestamptz,
  refund_proposed_at timestamptz,
  buyer_refund_confirmed_at timestamptz
);
-- Chỉ A xác nhận thực nhận tiền qua RPC, không phải cập nhật trực tiếp bảng.

-- 3. Giao hộ và chứng cứ bàn giao.
create table public.delivery_tasks (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions(id),
  sender_id uuid not null references auth.users(id),
  final_receiver_id uuid not null references auth.users(id),
  assigned_courier_id uuid references auth.users(id),
  status text not null default 'OPEN'
    check (status in ('OPEN','ASSIGNED','PICKED_UP',
                     'DELIVERY_PENDING_CONFIRMATION','COMPLETED','FAILED','CANCELLED')),
  pickup_description text,
  dropoff_description text,
  return_handover_id uuid,
  created_at timestamptz not null default now(),
  check (sender_id <> final_receiver_id)
);

create table public.delivery_applications (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.delivery_tasks(id),
  applicant_id uuid not null references auth.users(id),
  status text not null default 'PENDING'
    check (status in ('PENDING','ACCEPTED','REJECTED','WITHDRAWN')),
  created_at timestamptz not null default now(),
  unique(task_id, applicant_id)
);
create unique index applications_one_accepted_per_task
  on public.delivery_applications(task_id) where status = 'ACCEPTED';

create table public.handovers (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions(id),
  delivery_task_id uuid references public.delivery_tasks(id),
  from_user_id uuid not null references auth.users(id),
  to_user_id uuid not null references auth.users(id),
  status text not null default 'PENDING'
    check (status in ('PENDING','AWAITING_RECEIVER_CONFIRMATION','CONFIRMED','DISPUTED')),
  verification_method text check (verification_method in ('QR','FALLBACK')),
  fallback_reason text,
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  check (from_user_id <> to_user_id),
  check (verification_method <> 'FALLBACK' or nullif(trim(fallback_reason), '') is not null)
);
alter table public.delivery_tasks
  add constraint delivery_tasks_return_handover_fk
  foreign key(return_handover_id) references public.handovers(id);

create table public.handover_evidence (
  id uuid primary key default gen_random_uuid(),
  handover_id uuid not null references public.handovers(id),
  uploaded_by uuid not null references auth.users(id),
  private_path text not null unique,
  sensitivity text not null default 'PRIVATE' check (sensitivity in ('PRIVATE')),
  uploaded_at timestamptz not null default now()
);

-- 4. Tranh chấp, lịch sử và thông báo.
create table public.issues (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions(id),
  handover_id uuid references public.handovers(id),
  reporter_id uuid not null references auth.users(id),
  issue_type text not null check (length(trim(issue_type)) > 0),
  reason text not null check (length(trim(reason)) > 0),
  status text not null default 'OPEN' check (status in ('OPEN','RESOLVED')),
  resolution_revision integer not null default 0 check (resolution_revision >= 0),
  resolution_text text,
  opened_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.issue_consents (
  issue_id uuid not null references public.issues(id),
  participant_id uuid not null references auth.users(id),
  resolution_revision integer not null check (resolution_revision > 0),
  approved_at timestamptz not null default now(),
  primary key(issue_id, participant_id, resolution_revision)
);

create table public.transaction_events (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions(id),
  actor_id uuid references auth.users(id),
  event_type text not null,
  payload_safe jsonb not null default '{}'::jsonb,
  server_at timestamptz not null default now(),
  source_action_id text not null unique
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id),
  type text not null,
  entity_type text not null,
  entity_id uuid not null,
  preview_safe text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create table public.courier_ratings (
  task_id uuid not null references public.delivery_tasks(id),
  rater_id uuid not null references auth.users(id),
  stars integer not null check (stars between 1 and 5),
  created_at timestamptz not null default now(),
  primary key(task_id, rater_id)
);

-- Dùng cho RPC idempotent; tuyệt đối không cho client tự ghi biên nhận.
create table public.command_receipts (
  actor_id uuid not null references auth.users(id),
  command_name text not null,
  idempotency_key text not null,
  payload_hash text not null,
  result_json jsonb not null,
  created_at timestamptz not null default now(),
  primary key(actor_id, command_name, idempotency_key)
);

-- 5. Chặn theo mặc định: bật RLS + thu hồi quyền SQL ứng dụng.
-- Stage 03 mới mở các quyền đọc/ghi TỐI THIỂU đã được review.
do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'profiles', 'materials', 'material_images', 'material_qr_credentials',
    'listings', 'exchange_requests', 'transactions', 'borrowing_records',
    'payment_confirmations', 'delivery_tasks', 'delivery_applications',
    'handovers', 'handover_evidence', 'issues', 'issue_consents',
    'transaction_events', 'notifications', 'courier_ratings', 'command_receipts'
  ] loop
    execute format('alter table public.%I enable row level security', v_table);
    execute format('revoke all on table public.%I from anon, authenticated', v_table);
  end loop;
end $$;

-- KHÔNG tự cấp INSERT/UPDATE cho các bảng giao dịch ở đây.
-- State/holder/owner thay đổi qua RPC có kiểm tra quyền và transaction ở PR sau.
