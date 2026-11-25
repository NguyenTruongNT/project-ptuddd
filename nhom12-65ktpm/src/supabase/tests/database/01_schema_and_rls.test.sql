-- Kiểm tra cấu trúc cơ bản, RLS và các bucket riêng tư bằng pgTAP.
-- Chạy: npx supabase test db (sau khi đã supabase start / db reset).
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(20);

select extensions.ok(to_regclass('public.profiles') is not null, 'profiles ton tai');
select extensions.ok(to_regclass('public.materials') is not null, 'materials ton tai');
select extensions.ok(to_regclass('public.listings') is not null, 'listings ton tai');
select extensions.ok(to_regclass('public.exchange_requests') is not null, 'exchange_requests ton tai');
select extensions.ok(to_regclass('public.transactions') is not null, 'transactions ton tai');
select extensions.ok(to_regclass('public.handovers') is not null, 'handovers ton tai');
select extensions.ok(to_regclass('public.issues') is not null, 'issues ton tai');
select extensions.ok(to_regclass('public.command_receipts') is not null, 'command_receipts ton tai');

select extensions.ok(to_regclass('public.transactions_one_active_per_material') is not null,
  'khong cho hai giao dich active tren mot Material');
select extensions.ok(to_regclass('public.requests_one_pending_per_user_listing') is not null,
  'khong tao duplicate Request PENDING');

select extensions.ok(
  (select count(*) = 19 from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
      and c.relname in (
        'profiles','materials','material_images','material_qr_credentials',
        'listings','exchange_requests','transactions','borrowing_records',
        'payment_confirmations','delivery_tasks','delivery_applications',
        'handovers','handover_evidence','issues','issue_consents',
        'transaction_events','notifications','courier_ratings','command_receipts'
      ) and c.relrowsecurity),
  'RLS bat cho 19 bang');

select extensions.ok(has_table_privilege('authenticated', 'public.materials', 'SELECT')
  and exists(select 1 from pg_policies where schemaname='public'
    and tablename='materials' and policyname='materials_read_owner'),
  'client doc materials qua owner RLS; test A/B o 04');
select extensions.ok(not has_table_privilege('authenticated', 'public.material_qr_credentials', 'SELECT'),
  'QR credential khong the doc tu client');
select extensions.ok(not has_table_privilege('authenticated', 'public.transactions', 'UPDATE'),
  'client khong duoc UPDATE giao dich truc tiep');
select extensions.ok(has_table_privilege('authenticated', 'public.profiles', 'SELECT'),
  'profile co quyen doc theo RLS');

select extensions.ok(
  exists (select 1 from pg_policies
          where schemaname = 'public' and tablename = 'profiles'
            and policyname = 'profiles_select_self'),
  'profile co RLS chi doc chinh minh');
select extensions.ok(
  exists (select 1 from pg_policies
          where schemaname = 'public' and tablename = 'notifications'
            and policyname = 'notifications_select_self'),
  'notifications co RLS theo nguoi nhan');
select extensions.ok(
  exists (select 1 from pg_policies
          where schemaname = 'storage' and tablename = 'objects'
            and policyname = 'material_images_upload_registered'),
  'anh tai lieu chi upload vao path dang ky cho actor');
select extensions.ok(
  (select public is false from storage.buckets where id = 'studyshare-material-images'),
  'material images bucket PRIVATE');
select extensions.ok(
  (select public is false from storage.buckets where id = 'studyshare-handover-evidence'),
  'handover evidence bucket PRIVATE');

select * from extensions.finish();
rollback;
