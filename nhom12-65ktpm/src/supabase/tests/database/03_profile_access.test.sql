-- Dữ liệu test được rollback, không tạo/sửa tài khoản thật.
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(9);

insert into auth.users(id, email) values
  ('a1100000-0000-4000-8000-000000000001', 'profile-a@example.test'),
  ('a1100000-0000-4000-8000-000000000002', 'profile-b@example.test'),
  ('a1100000-0000-4000-8000-000000000003', 'profile-c@example.test');
insert into public.profiles(user_id, display_name) values
  ('a1100000-0000-4000-8000-000000000001', 'Profile A'),
  ('a1100000-0000-4000-8000-000000000002', 'Profile B');

set local role authenticated;
set local request.jwt.claim.sub = 'a1100000-0000-4000-8000-000000000001';
select extensions.is((select count(*) from public.profiles), 1::bigint,
  'A chi doc duoc profile cua A');
select extensions.is((select display_name from public.profiles), 'Profile A',
  'Khong lo profile B');
update public.profiles set display_name = 'A updated'
  where user_id = 'a1100000-0000-4000-8000-000000000001';
select extensions.is((select display_name from public.profiles), 'A updated',
  'A duoc sua ten cua minh');
with changed as (
  update public.profiles set display_name = 'Attacker'
  where user_id = 'a1100000-0000-4000-8000-000000000002' returning user_id
)
select extensions.is((select count(*) from changed), 0::bigint,
  'A khong sua duoc profile B');
select extensions.throws_ok(
  $$insert into public.profiles(user_id,display_name)
    values ('a1100000-0000-4000-8000-000000000003','Forged')$$,
  '42501', null, 'Khong gia mao user_id khi tao profile');
select extensions.throws_ok(
  $$update public.profiles set user_id = 'a1100000-0000-4000-8000-000000000003'$$,
  '42501', null, 'Column grants chan doi dinh danh profile');
select extensions.throws_ok(
  $$update public.profiles set display_name = '   '$$,
  '23514', null, 'DB chan ten rong');
select extensions.throws_ok(
  $$update public.profiles set display_name = repeat('a',101)$$,
  '23514', null, 'DB chan ten qua dai');
reset role;
set local role anon;
select extensions.throws_ok($$select * from public.profiles$$,
  '42501', null, 'Anonymous khong duoc doc profile');
reset role;
select * from extensions.finish();
rollback;
