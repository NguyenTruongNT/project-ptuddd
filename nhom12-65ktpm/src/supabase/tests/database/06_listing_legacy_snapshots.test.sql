-- Fixture mô phỏng dữ liệu trước ngày 3; rollback sau khi kiểm tra chuyển đổi.
begin;
create extension if not exists pgtap with schema extensions;
select extensions.no_plan();
insert into auth.users(id,email) values
 ('d3400000-0000-4000-8000-000000000001','legacy-listing-a@example.test'),
 ('d3400000-0000-4000-8000-000000000002','legacy-listing-b@example.test');
create temp table legacy_ctx(k text primary key,v jsonb);
grant all on legacy_ctx to authenticated,service_role;
set local role authenticated;
set local request.jwt.claim.sub='d3400000-0000-4000-8000-000000000001';
insert into legacy_ctx values('m',public.save_material(
 '{"title":"Tin cũ","subject":"Toán","condition":"Tốt","image_ids":[]}','legacy-m'));
insert into legacy_ctx values('empty',public.save_material(
 '{"title":"Thiếu ảnh","subject":"Toán","condition":"Tốt","image_ids":[]}','legacy-empty'));
insert into legacy_ctx values('upload',public.prepare_material_image('image/png',68,
 (select (v->>'id')::uuid from legacy_ctx where k='m')));
reset role;
insert into storage.objects(bucket_id,name,metadata) select 'studyshare-material-images',v->>'storage_path',
 '{"size":68,"mimetype":"image/png"}' from legacy_ctx where k='upload';
set local role service_role;
select public.verify_material_image_upload((select (v->>'id')::uuid from legacy_ctx where k='upload'),
 'd3400000-0000-4000-8000-000000000001');
reset role;
set local role authenticated;
insert into legacy_ctx values('attached',public.save_material(jsonb_build_object(
 'title','Tin cũ','subject','Toán','condition','Tốt',
 'image_ids',jsonb_build_array((select v->>'id' from legacy_ctx where k='upload'))),
 'legacy-attach',(select (v->>'id')::uuid from legacy_ctx where k='m'),1));
reset role;
insert into public.listings(id,material_id,offer_type,asking_price_vnd,status,published_at)
 values('d3400000-0000-4000-8000-000000000010',(select (v->>'id')::uuid from legacy_ctx where k='m'),
 'SELL',100,'HIDDEN','2026-11-25T01:00:00Z'),
 ('d3400000-0000-4000-8000-000000000011',(select (v->>'id')::uuid from legacy_ctx where k='empty'),
 'DONATE',null,'PUBLISHED','2026-11-25T02:00:00Z');
insert into public.exchange_requests(id,listing_id,requester_id,status)
 values('d3400000-0000-4000-8000-000000000020','d3400000-0000-4000-8000-000000000010',
 'd3400000-0000-4000-8000-000000000002','ACCEPTED');
insert into public.transactions(id,listing_id,request_id,material_id,type,owner_at_acceptance,receiver_id,status,agreed_price_vnd,terms_snapshot)
 values('d3400000-0000-4000-8000-000000000030','d3400000-0000-4000-8000-000000000010',
 'd3400000-0000-4000-8000-000000000020',(select (v->>'id')::uuid from legacy_ctx where k='m'),
 'SELL','d3400000-0000-4000-8000-000000000001','d3400000-0000-4000-8000-000000000002',
 'AWAITING_PAYMENT',100,'{"agreed_before_day3":true}');
insert into legacy_ctx select 'original_terms',terms_snapshot from public.transactions
 where id='d3400000-0000-4000-8000-000000000030';
select extensions.is(studyshare_private.backfill_legacy_listing_snapshots(),1,'Chuyển đổi đúng tin có ảnh hợp lệ');
select extensions.is((select status::text from public.listings where id='d3400000-0000-4000-8000-000000000010'),
 'HIDDEN','Giữ nguyên trạng thái ẩn');
select extensions.is((select published_at from public.listings where id='d3400000-0000-4000-8000-000000000010'),
 '2026-11-25T01:00:00Z'::timestamptz,'Giữ thời điểm công bố gốc');
select extensions.is((select publication_snapshot->>'captured_from' from public.listings
 where id='d3400000-0000-4000-8000-000000000010'),'legacy_migration','Ghi rõ nguồn snapshot tại thời điểm chuyển đổi');
select extensions.is((select terms_snapshot from public.transactions where id='d3400000-0000-4000-8000-000000000030'),
 (select v from legacy_ctx where k='original_terms'),'Không tự ghi lại điều khoản giao dịch lịch sử');
select extensions.ok((select publication_snapshot is null from public.listings
 where id='d3400000-0000-4000-8000-000000000011'),'Không công khai tin cũ thiếu ảnh');
select extensions.is((select count(*) from public.listing_snapshot_images
 where listing_id='d3400000-0000-4000-8000-000000000010'),1::bigint,'Có tham chiếu media thật');
select extensions.is(studyshare_private.backfill_legacy_listing_snapshots(),0,'Chạy lại không thay snapshot/revision');
select extensions.ok(not has_function_privilege('authenticated',
 'studyshare_private.backfill_legacy_listing_snapshots()','EXECUTE'),'Client không gọi được hàm chuyển đổi');
select extensions.ok(not has_function_privilege('anon',
 'studyshare_private.backfill_legacy_listing_snapshots()','EXECUTE'),'Anon không gọi được hàm chuyển đổi');
set local role authenticated;
select extensions.lives_ok($$select public.save_listing('show','{}','legacy-active-show',null,
 'd3400000-0000-4000-8000-000000000010',2)$$,'Tin cũ đang có giao dịch vẫn hiện lại nguyên nội dung');
set local request.jwt.claim.sub='d3400000-0000-4000-8000-000000000002';
select extensions.is(public.get_published_listing('d3400000-0000-4000-8000-000000000010')->>'title',
 'Tin cũ','Khám phá đọc được tin cũ sau chuyển đổi');
select extensions.ok(not (public.get_published_listing('d3400000-0000-4000-8000-000000000010')->>'is_requestable')::boolean,
 'Tin cũ đang giao dịch không nhận yêu cầu mới');
reset role;
select * from extensions.finish();
rollback;
