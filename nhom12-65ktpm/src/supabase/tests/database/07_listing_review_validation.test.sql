begin;
create extension if not exists pgtap with schema extensions;
select extensions.no_plan();
insert into auth.users(id,email) values('d3500000-0000-4000-8000-000000000001','review-listing@example.test');
insert into public.materials(id,owner_id,holder_id,title,subject,condition) values
 ('d3500000-0000-4000-8000-000000000010','d3500000-0000-4000-8000-000000000001',
  'd3500000-0000-4000-8000-000000000001','Tin ẩn','Toán','Tốt'),
 ('d3500000-0000-4000-8000-000000000011','d3500000-0000-4000-8000-000000000001',
  'd3500000-0000-4000-8000-000000000001','Nháp','Toán','Tốt');
insert into public.listings(id,material_id,offer_type,asking_price_vnd,status) values
 ('d3500000-0000-4000-8000-000000000020','d3500000-0000-4000-8000-000000000010','SELL',100,'HIDDEN');
set local role authenticated;
set local request.jwt.claim.sub='d3500000-0000-4000-8000-000000000001';
select extensions.throws_ok($$select public.save_listing('draft','{"offer_type":"SELL"}','hidden-null',null,
 'd3500000-0000-4000-8000-000000000020',1,1)$$,'P0001','INVALID_INPUT','HIDDEN SELL thiếu giá trả lỗi nghiệp vụ trước UPDATE');
select extensions.throws_ok($$select public.save_listing('draft','{"offer_type":"SELL","asking_price_vnd":null}','hidden-explicit-null',null,
 'd3500000-0000-4000-8000-000000000020',1,1)$$,'P0001','INVALID_INPUT','Null tường minh cũng bị chặn');
select extensions.throws_ok($$select public.save_listing('draft','{"offer_type":"SELL","asking_price_vnd":0}','hidden-zero',null,
 'd3500000-0000-4000-8000-000000000020',1,1)$$,'P0001','INVALID_INPUT','Giá 0 vẫn bị chặn');
select extensions.is(public.get_my_listing('d3500000-0000-4000-8000-000000000020')->>'revision','1','Lỗi không đổi revision');
select extensions.is(public.get_my_listing('d3500000-0000-4000-8000-000000000020')->>'asking_price_vnd','100','Lỗi không mất giá cũ');
select extensions.is(public.save_listing('draft','{"offer_type":"SELL","asking_price_vnd":1}','hidden-valid',null,
 'd3500000-0000-4000-8000-000000000020',1,1)->'data'->>'status','HIDDEN','Lưu giá hợp lệ giữ trạng thái HIDDEN');
select extensions.is(public.save_listing('draft','{"offer_type":"SELL"}','draft-null',
 'd3500000-0000-4000-8000-000000000011',null,null,1)->'data'->>'status','DRAFT','DRAFT SELL vẫn được thiếu giá');
reset role;
select extensions.is((select count(*) from public.command_receipts where actor_id='d3500000-0000-4000-8000-000000000001'
 and idempotency_key in ('hidden-null','hidden-explicit-null','hidden-zero')),0::bigint,'Lệnh sai không sinh receipt');
select extensions.is((select reason from studyshare_private.listing_snapshot_audit()
 where listing_id='d3500000-0000-4000-8000-000000000020'),'MISSING_IMAGES','Báo rõ tin cũ bị bỏ qua vì thiếu ảnh');
select extensions.is((select count(*) from studyshare_private.listing_snapshot_audit()
 where listing_id='d3500000-0000-4000-8000-000000000011'),0::bigint,'DRAFT không bị tính là tin công khai bị loại');
select extensions.ok(not has_function_privilege('authenticated','studyshare_private.listing_snapshot_audit()','EXECUTE'),
 'Mobile không gọi được báo cáo quản trị');
select extensions.ok(not has_function_privilege('anon','studyshare_private.listing_snapshot_audit()','EXECUTE'),
 'Anon không gọi được báo cáo quản trị');
select * from extensions.finish();
rollback;
