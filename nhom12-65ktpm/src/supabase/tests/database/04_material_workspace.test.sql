-- Test transaction rollback; chỉ account/ảnh giả, không thay dữ liệu thật.
begin;
create extension if not exists pgtap with schema extensions;
select extensions.no_plan();
insert into auth.users(id,email) values
 ('d2200000-0000-4000-8000-000000000001','material-a@example.test'),
 ('d2200000-0000-4000-8000-000000000002','material-b@example.test');
insert into public.profiles(user_id,display_name) values
 ('d2200000-0000-4000-8000-000000000001','Material A'),
 ('d2200000-0000-4000-8000-000000000002','Material B');
create temp table material_test_ctx(k text primary key,v jsonb);
grant all on material_test_ctx to authenticated,service_role;
set local role authenticated;
set local request.jwt.claim.sub='d2200000-0000-4000-8000-000000000001';
select extensions.lives_ok($$insert into material_test_ctx values('created',
 public.save_material('{"title":"Giải tích","subject":"Toán","condition":"Tốt","isbn":"9780131103627","image_ids":[]}',
 'create-1'))$$,'Owner tao Material khong anh');
select extensions.is((select v->>'owner_id' from material_test_ctx where k='created'),
 auth.uid()::text,'Server tu dat owner');
select extensions.is((select v->>'holder_id' from material_test_ctx where k='created'),
 auth.uid()::text,'Server tu dat holder');
select extensions.is(public.save_material(
 '{"title":"Giải tích","subject":"Toán","condition":"Tốt","isbn":"9780131103627","image_ids":[]}',
 'create-1'),(select v from material_test_ctx where k='created'),'Retry cung key tra cung ACK');
select extensions.is(public.get_material_command_result('create_material','create-1'),
 (select v from material_test_ctx where k='created'),'Tra receipt sau timeout');
select extensions.throws_ok($$select public.save_material(
 '{"title":"Khác","subject":"Toán","condition":"Tốt","image_ids":[]}','create-1')$$,
 'P0001','CONFLICT','Key cu payload khac bi chan');
select extensions.lives_ok($$insert into material_test_ctx values('duplicate',
 public.save_material('{"title":"Giải tích","subject":"Toán","condition":"Tốt","isbn":"9780131103627","image_ids":[]}',
 'create-2'))$$,'Cho trung ISBN');
select extensions.isnt((select v->>'id' from material_test_ctx where k='created'),
 (select v->>'id' from material_test_ctx where k='duplicate'),'Hai ban vat ly ID rieng');
select extensions.throws_ok($$select public.save_material(
 '{"title":" ","subject":"Toán","condition":"Tốt","image_ids":[]}','empty')$$,
 'P0001','INVALID_INPUT','Chan ten rong');
select extensions.throws_ok($$select public.save_material(
 jsonb_build_object('title',E'\n\t','subject','Toán','condition','Tốt','image_ids','[]'::jsonb),
 'whitespace')$$,'P0001','INVALID_INPUT','Chan ten chi co tab va newline');
select extensions.throws_ok($$select public.save_material(
 jsonb_build_object('title','A','subject','B','condition','C','image_ids',
 (select jsonb_agg(gen_random_uuid()) from generate_series(1,6))),'six-images')$$,
 'P0001','INVALID_INPUT','Server chan tren 5 anh');
select extensions.throws_ok($$select public.save_material(
 '{"title":"A","subject":"B","condition":"C","image_ids":["d2200000-0000-4000-8000-000000000099","d2200000-0000-4000-8000-000000000099"]}',
 'duplicate-images')$$,'P0001','INVALID_INPUT','Server chan ID anh lap');
select extensions.throws_ok($$select public.save_material(
 jsonb_build_object('title',repeat('a',201),'subject','A','condition','A','image_ids','[]'::jsonb),
 'long')$$,'P0001','INVALID_INPUT','Chan ten qua 200');
select extensions.throws_ok($$select public.save_material(
 '{"title":42,"subject":"A","condition":"A","image_ids":[]}','type')$$,
 'P0001','INVALID_INPUT','Chan sai kieu JSON');
select extensions.throws_ok($$select public.save_material(
 '{"title":"A","subject":"A","condition":"A","isbn":"9780131103628","image_ids":[]}','isbn')$$,
 'P0001','INVALID_INPUT','Chan ISBN sai checksum');
select extensions.throws_ok($$select public.save_material(
 '{"title":"A","subject":"A","condition":"A","isbn":"1234567890128","image_ids":[]}','ean')$$,
 'P0001','INVALID_INPUT','Chan EAN co checksum dung nhung khong phai ISBN');
select extensions.throws_ok($$select public.save_material(
 '{"title":"A","subject":"A","condition":"A","owner_id":"d2200000-0000-4000-8000-000000000002","image_ids":[]}','actor')$$,
 'P0001','INVALID_INPUT','Chan mass assignment owner');
select extensions.throws_ok($$update public.materials set owner_id=auth.uid()$$,
 '42501',null,'Khong cap UPDATE truc tiep');
select extensions.throws_ok($$select public.prepare_material_image('image/svg+xml',5)$$,
 'P0001','INVALID_INPUT','Chan MIME ngoai whitelist');
select extensions.throws_ok($$select public.prepare_material_image('image/png',5242881)$$,
 'P0001','INVALID_INPUT','Chan anh qua 5 MiB');
insert into material_test_ctx values('upload',public.prepare_material_image('image/png',68));
select extensions.throws_ok($$select public.verify_material_image_upload(
 (select (v->>'id')::uuid from material_test_ctx where k='upload'),auth.uid())$$,
 '42501',null,'Client khong tu xac nhan byte anh');
select extensions.throws_ok($$select public.save_material(
 jsonb_build_object('title','A','subject','A','condition','A','image_ids',
 jsonb_build_array((select v->>'id' from material_test_ctx where k='upload'))),'unverified')$$,
 'P0001','FORBIDDEN','Anh chua verify khong duoc gan');
reset role;
insert into storage.objects(bucket_id,name,metadata)
 select 'studyshare-material-images',v->>'storage_path',
 '{"size":68,"mimetype":"image/png"}'::jsonb from material_test_ctx where k='upload';
set local role service_role;
select public.verify_material_image_upload(
 (select (v->>'id')::uuid from material_test_ctx where k='upload'),
 'd2200000-0000-4000-8000-000000000001');
reset role;
set local role authenticated;
select extensions.lives_ok($$insert into material_test_ctx values('updated',
 public.save_material(jsonb_build_object('title','Giải tích mới','subject','Toán',
 'condition','Có ghi chú','description',E'Dòng 1\nDòng 2','image_ids',
 jsonb_build_array((select v->>'id' from material_test_ctx where k='upload'))),
 'edit-1',(select (v->>'id')::uuid from material_test_ctx where k='created'),1))$$,
 'Sua metadata va gan anh atomic');
select extensions.is((select (v->>'revision')::integer from material_test_ctx where k='updated'),
 2,'Tang revision');
select extensions.throws_ok($$select public.save_material(
 '{"title":"A","subject":"A","condition":"A","image_ids":[]}','stale',
 (select (v->>'id')::uuid from material_test_ctx where k='created'),1)$$,
 'P0001','CONFLICT','Chan thiet bi co revision cu');
select extensions.is((public.get_my_material((select (v->>'id')::uuid
 from material_test_ctx where k='created'))->'images'->0->>'id'),
 (select v->>'id' from material_test_ctx where k='upload'),'Gallery doc lai dung anh');
select extensions.is((public.search_my_materials('mới','ready')->'items')::jsonb,
 jsonb_build_array(public.get_my_material((select (v->>'id')::uuid
 from material_test_ctx where k='created'))),'Tim kiem va loc tren server');
set local request.jwt.claim.sub='d2200000-0000-4000-8000-000000000002';
select extensions.is(public.get_my_material((select (v->>'id')::uuid
 from material_test_ctx where k='created')),null::jsonb,'B khong doc chi tiet A');
select extensions.is((select count(*) from public.materials),0::bigint,'RLS khong lo row A');
select extensions.throws_ok($$select public.save_material(
 '{"title":"B","subject":"B","condition":"B","image_ids":[]}','forged-edit',
 (select (v->>'id')::uuid from material_test_ctx where k='created'),2)$$,
 'P0001','FORBIDDEN','B khong sua Material A');
select extensions.throws_ok($$select public.save_material(jsonb_build_object(
 'title','B','subject','B','condition','B','image_ids',
 jsonb_build_array((select v->>'id' from material_test_ctx where k='upload'))),'steal')$$,
 'P0001','FORBIDDEN','B khong gan anh A');
select extensions.is((select count(*) from storage.objects
 where bucket_id='studyshare-material-images'),0::bigint,'B khong doc file A');
reset role;
update public.materials set owner_id='d2200000-0000-4000-8000-000000000002',
 holder_id='d2200000-0000-4000-8000-000000000002'
 where id=(select (v->>'id')::uuid from material_test_ctx where k='created');
set local role authenticated;
select extensions.is((select count(*) from storage.objects
 where name=(select v->>'storage_path' from material_test_ctx where k='upload')),
 1::bigint,'Chu moi doc anh du nguoi upload la A');
set local request.jwt.claim.sub='d2200000-0000-4000-8000-000000000001';
select extensions.is((select count(*) from storage.objects
 where name=(select v->>'storage_path' from material_test_ctx where k='upload')),
 0::bigint,'Chu cu khong con quyen theo folder cu');
select extensions.is(public.get_material_command_result('create_material','create-1'),
 null::jsonb,'Receipt khong lo du lieu sau mat quyen');
reset role;
set local role anon;
-- Authenticated write remains locked by pending requests and active transactions.
reset role;
insert into public.listings(id,material_id,offer_type,status)
 values('d2200000-0000-4000-8000-000000000011',
 (select (v->>'id')::uuid from material_test_ctx where k='created'),'DONATE','HIDDEN');
insert into public.exchange_requests(id,listing_id,requester_id,status)
 values('d2200000-0000-4000-8000-000000000012',
 'd2200000-0000-4000-8000-000000000011',
 'd2200000-0000-4000-8000-000000000001','PENDING');
set local role authenticated;
set local request.jwt.claim.sub='d2200000-0000-4000-8000-000000000002';
select extensions.is(public.get_my_material((select (v->>'id')::uuid
 from material_test_ctx where k='created'))->>'edit_blocked_reason',
 'REQUEST_PENDING','Chan sua khi co Request PENDING');
select extensions.throws_ok($$select public.save_material(
 '{"title":"A","subject":"A","condition":"A","image_ids":[]}','pending-edit',
 (select (v->>'id')::uuid from material_test_ctx where k='created'),2)$$,
 'P0001','MATERIAL_UNAVAILABLE','RPC cung chan Request PENDING');
reset role;
update public.exchange_requests set status='ACCEPTED'
 where id='d2200000-0000-4000-8000-000000000012';
insert into public.transactions(listing_id,request_id,material_id,type,
 owner_at_acceptance,receiver_id,status) values(
 'd2200000-0000-4000-8000-000000000011','d2200000-0000-4000-8000-000000000012',
 (select (v->>'id')::uuid from material_test_ctx where k='created'),'DONATE',
 'd2200000-0000-4000-8000-000000000002','d2200000-0000-4000-8000-000000000001',
 'AWAITING_HANDOVER');
set local role authenticated;
select extensions.is(public.get_my_material((select (v->>'id')::uuid
 from material_test_ctx where k='created'))->>'edit_blocked_reason',
 'TRANSACTION_ACTIVE','Chan sua khi co Transaction active');
select extensions.throws_ok($$select public.save_material(
 '{"title":"A","subject":"A","condition":"A","image_ids":[]}','active-edit',
 (select (v->>'id')::uuid from material_test_ctx where k='created'),2)$$,
 'P0001','MATERIAL_UNAVAILABLE','RPC cung chan Transaction active');
reset role;
set local role anon;
select extensions.throws_ok($$select public.search_my_materials()$$,
 '42501',null,'Anonymous khong goi RPC rieng tu');
select extensions.throws_ok($$select * from public.material_image_uploads$$,
 '42501',null,'Khong lo upload registry');
reset role;
select * from extensions.finish();
rollback;
