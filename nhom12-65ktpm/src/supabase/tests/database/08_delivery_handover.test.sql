-- Test pgTAP cho RPC DeliveryTask, Courier, Handover, QR, Evidence & Rating.
-- Chạy trong transaction rollback, chỉ dùng dữ liệu giả lập.
begin;
create extension if not exists pgtap with schema extensions;
select extensions.no_plan();

-- 1. Tạo dữ liệu giả lập: A (owner), B (requester), C (courier 1), D (courier 2), Outsider.
insert into auth.users(id, email) values
  ('d3300000-0000-4000-8000-000000000001', 'del-a@example.test'),
  ('d3300000-0000-4000-8000-000000000002', 'del-b@example.test'),
  ('d3300000-0000-4000-8000-000000000003', 'del-c@example.test'),
  ('d3300000-0000-4000-8000-000000000004', 'del-d@example.test'),
  ('d3300000-0000-4000-8000-000000000005', 'del-outsider@example.test');

insert into public.profiles(user_id, display_name) values
  ('d3300000-0000-4000-8000-000000000001', 'Chu sach A'),
  ('d3300000-0000-4000-8000-000000000002', 'Nguoi muon B'),
  ('d3300000-0000-4000-8000-000000000003', 'Courier C'),
  ('d3300000-0000-4000-8000-000000000004', 'Courier D'),
  ('d3300000-0000-4000-8000-000000000005', 'Nguoi ngoai');

insert into public.materials(id, owner_id, holder_id, title, subject, condition) values
  ('e3300000-0000-4000-8000-000000000001', 'd3300000-0000-4000-8000-000000000001',
   'd3300000-0000-4000-8000-000000000001', 'Sach Borrow', 'CNTT', 'Tot'),
  ('e3300000-0000-4000-8000-000000000002', 'd3300000-0000-4000-8000-000000000001',
   'd3300000-0000-4000-8000-000000000001', 'Sach Sell', 'Toan', 'Moi');

insert into public.material_qr_credentials(material_id, qr_secret) values
  ('e3300000-0000-4000-8000-000000000001', 'qr-secret-borrow-01'),
  ('e3300000-0000-4000-8000-000000000002', 'qr-secret-sell-01');

insert into public.listings(id, material_id, offer_type, status, asking_price_vnd) values
  ('f3300000-0000-4000-8000-000000000001', 'e3300000-0000-4000-8000-000000000001', 'BORROW', 'PUBLISHED', null),
  ('f3300000-0000-4000-8000-000000000002', 'e3300000-0000-4000-8000-000000000002', 'SELL', 'PUBLISHED', 50000);

insert into public.exchange_requests(id, listing_id, requester_id, requested_borrow_days, status) values
  ('a3300000-0000-4000-8000-000000000001', 'f3300000-0000-4000-8000-000000000001',
   'd3300000-0000-4000-8000-000000000002', 7, 'ACCEPTED'),
  ('a3300000-0000-4000-8000-000000000002', 'f3300000-0000-4000-8000-000000000002',
   'd3300000-0000-4000-8000-000000000002', null, 'ACCEPTED');

insert into public.transactions(id, listing_id, request_id, material_id, type, owner_at_acceptance, receiver_id, status, agreed_borrow_days, agreed_price_vnd) values
  ('b3300000-0000-4000-8000-000000000001', 'f3300000-0000-4000-8000-000000000001',
   'a3300000-0000-4000-8000-000000000001', 'e3300000-0000-4000-8000-000000000001',
   'BORROW', 'd3300000-0000-4000-8000-000000000001', 'd3300000-0000-4000-8000-000000000002',
   'AWAITING_HANDOVER', 7, null),
  ('b3300000-0000-4000-8000-000000000002', 'f3300000-0000-4000-8000-000000000002',
   'a3300000-0000-4000-8000-000000000002', 'e3300000-0000-4000-8000-000000000002',
   'SELL', 'd3300000-0000-4000-8000-000000000001', 'd3300000-0000-4000-8000-000000000002',
   'AWAITING_PAYMENT', null, 50000);

insert into public.payment_confirmations(transaction_id, amount_vnd) values
  ('b3300000-0000-4000-8000-000000000002', 50000);

create temp table del_ctx(k text primary key, v jsonb);
grant all on del_ctx to authenticated, service_role;

-- 2. Kiểm tra chặn truy cập trực tiếp bảng.
set local role authenticated;
set local request.jwt.claim.sub = 'd3300000-0000-4000-8000-000000000001';
select extensions.throws_ok($$select * from public.delivery_tasks$$, '42501', null, 'Chan doc truc tiep delivery_tasks');
select extensions.throws_ok($$select * from public.handovers$$, '42501', null, 'Chan doc truc tiep handovers');

-- 3. Chặn tạo Handover cho giao dịch SELL trước khi xác nhận tiền (INV-07).
select extensions.is(
  public.create_handover('b3300000-0000-4000-8000-000000000002',
    'd3300000-0000-4000-8000-000000000002', null, 'sell-before-pay')->>'code',
  'PAYMENT_NOT_CONFIRMED',
  'INV-07: Chan Handover SELL truoc khi A xac nhan tien'
);

-- 4. A tạo DeliveryTask cho BORROW.
insert into del_ctx values ('task',
  public.create_delivery_task(
    'b3300000-0000-4000-8000-000000000001',
    'd3300000-0000-4000-8000-000000000002',
    'Cong chinh TLU', 'KTX P.304', 'task-create-1'));
select extensions.is((select v->>'ok' from del_ctx where k='task'), 'true', 'A tao DeliveryTask thanh cong');

-- Idempotency retry cùng key + payload trả lại kết quả cũ; khác payload -> CONFLICT.
select extensions.is(
  public.create_delivery_task(
    'b3300000-0000-4000-8000-000000000001',
    'd3300000-0000-4000-8000-000000000002',
    'Cong chinh TLU', 'KTX P.304', 'task-create-1')->'data'->>'id',
  (select v->'data'->>'id' from del_ctx where k='task'),
  'Retry cung key tra cung Task'
);
select extensions.is(
  public.create_delivery_task(
    'b3300000-0000-4000-8000-000000000001',
    'd3300000-0000-4000-8000-000000000002',
    'Diem khac', 'KTX P.304', 'task-create-1')->>'code',
  'CONFLICT',
  'Cung key khac payload tra CONFLICT'
);

-- A tự ứng tuyển Task của mình -> FORBIDDEN.
select extensions.is(
  public.apply_for_delivery((select v->'data'->>'id' from del_ctx where k='task'), 'a-apply')->>'code',
  'FORBIDDEN',
  'Nguoi gui khong duoc tu ung tuyen'
);

-- 5. C và D ứng tuyển; chưa được chọn thì không thấy địa điểm chi tiết.
set local request.jwt.claim.sub = 'd3300000-0000-4000-8000-000000000003';
insert into del_ctx values ('app_c',
  public.apply_for_delivery((select v->'data'->>'id' from del_ctx where k='task'), 'c-apply'));
select extensions.is((select v->>'ok' from del_ctx where k='app_c'), 'true', 'C ung tuyen thanh cong');
select extensions.is(
  public.get_delivery_task_details((select v->'data'->>'id' from del_ctx where k='task'))->'task'->>'pickup_description',
  null,
  'Courier chua duoc chon khong thay dia diem chi tiet'
);

set local request.jwt.claim.sub = 'd3300000-0000-4000-8000-000000000004';
insert into del_ctx values ('app_d',
  public.apply_for_delivery((select v->'data'->>'id' from del_ctx where k='task'), 'd-apply'));

-- 6. A chọn C -> Task ASSIGNED, C thấy địa điểm chi tiết.
set local request.jwt.claim.sub = 'd3300000-0000-4000-8000-000000000001';
select extensions.is(
  public.select_courier(
    (select v->'data'->>'id' from del_ctx where k='task'),
    (select v->'data'->>'id' from del_ctx where k='app_c'),
    'select-c')->'data'->>'status',
  'ASSIGNED',
  'A chon C thanh cong, Task sang ASSIGNED'
);

set local request.jwt.claim.sub = 'd3300000-0000-4000-8000-000000000003';
select extensions.is(
  public.get_delivery_task_details((select v->'data'->>'id' from del_ctx where k='task'))->'task'->>'pickup_description',
  'Cong chinh TLU',
  'C duoc chon thay dia diem chi tiet'
);

-- 7. Chặng H1 (A -> C): tạo Handover, kiểm tra QR mismatch, thiếu ảnh, giver tự confirm.
set local request.jwt.claim.sub = 'd3300000-0000-4000-8000-000000000001';
insert into del_ctx values ('h1',
  public.create_handover(
    'b3300000-0000-4000-8000-000000000001',
    'd3300000-0000-4000-8000-000000000003',
    (select v->'data'->>'id' from del_ctx where k='task'),
    'create-h1'));
select extensions.is((select v->>'ok' from del_ctx where k='h1'), 'true', 'Tao H1 thanh cong');

-- QR sai -> QR_MISMATCH.
select extensions.is(
  public.verify_material_code((select v->'data'->>'id' from del_ctx where k='h1'),
    'wrong-qr', 'QR', null, 'qr-bad')->>'code',
  'QR_MISMATCH',
  'INV-05: QR sai tra QR_MISMATCH'
);

-- QR đúng -> thành công.
select extensions.is(
  public.verify_material_code((select v->'data'->>'id' from del_ctx where k='h1'),
    'qr-secret-borrow-01', 'QR', null, 'qr-ok')->>'ok',
  'true',
  'QR dung duoc chap nhan'
);

-- Thiếu ảnh -> EVIDENCE_REQUIRED.
select extensions.is(
  public.submit_handover_evidence((select v->'data'->>'id' from del_ctx where k='h1'),
    array[]::text[], 'ev-empty')->>'code',
  'EVIDENCE_REQUIRED',
  'INV-04: Thieu anh bi chan'
);

-- Nộp 1 ảnh -> AWAITING_RECEIVER_CONFIRMATION.
select extensions.is(
  public.submit_handover_evidence((select v->'data'->>'id' from del_ctx where k='h1'),
    array['d3300000-0000-4000-8000-000000000001/h1-1.jpg'], 'ev-ok')->'data'->>'status',
  'AWAITING_RECEIVER_CONFIRMATION',
  'Nop anh xong chuyen cho nguoi nhan xac nhan'
);

-- Người giao A tự xác nhận thay C -> INVALID_HANDOVER_PARTICIPANT.
select extensions.is(
  public.confirm_handover((select v->'data'->>'id' from del_ctx where k='h1'), 'a-self-ack')->>'code',
  'INVALID_HANDOVER_PARTICIPANT',
  'Giver khong the tu xac nhan thay receiver'
);

-- Người ngoài không đọc được Handover.
set local request.jwt.claim.sub = 'd3300000-0000-4000-8000-000000000005';
select extensions.is(
  public.get_handover_details((select v->'data'->>'id' from del_ctx where k='h1')),
  null,
  'Nguoi ngoai khong doc duoc Handover'
);

-- C xác nhận nhận H1 -> Handover CONFIRMED, holder=C, Task PICKED_UP.
set local request.jwt.claim.sub = 'd3300000-0000-4000-8000-000000000003';
select extensions.is(
  public.confirm_handover((select v->'data'->>'id' from del_ctx where k='h1'), 'c-ack-h1')->'data'->>'status',
  'CONFIRMED',
  'C xac nhan H1 thanh cong'
);

reset role;
select extensions.is(
  (select holder_id::text from public.materials where id = 'e3300000-0000-4000-8000-000000000001'),
  'd3300000-0000-4000-8000-000000000003',
  'holder_id da chuyen sang C'
);
select extensions.is(
  (select status from public.delivery_tasks where id = (select (v->'data'->>'id')::uuid from del_ctx where k='task')),
  'PICKED_UP',
  'Task chuyen sang PICKED_UP sau H1'
);

-- 8. C báo giao thất bại -> Task FAILED, holder vẫn là C, tạo return_handover_id.
set local role authenticated;
set local request.jwt.claim.sub = 'd3300000-0000-4000-8000-000000000003';
insert into del_ctx values ('failed',
  public.fail_delivery_task((select v->'data'->>'id' from del_ctx where k='task'), 'Khong lien lac duoc B', 'fail-1'));
select extensions.is((select v->'data'->>'status' from del_ctx where k='failed'), 'FAILED', 'Task chuyen sang FAILED');
select extensions.isnt((select v->'data'->>'return_handover_id' from del_ctx where k='failed'), null, 'Da tao return_handover_id');

reset role;
select extensions.is(
  (select holder_id::text from public.materials where id = 'e3300000-0000-4000-8000-000000000001'),
  'd3300000-0000-4000-8000-000000000003',
  'INV-08: Khi giao that bai holder van la C'
);

select * from extensions.finish();
rollback;
