-- Rollback toàn bộ fixture; kiểm tra backend thật, không cần Storage file thật cho pgTAP.
begin;
create extension if not exists pgtap with schema extensions;
select extensions.no_plan();
insert into auth.users(id,email) values
 ('d3300000-0000-4000-8000-000000000001','listing-a@example.test'),
 ('d3300000-0000-4000-8000-000000000002','listing-b@example.test');
insert into public.profiles(user_id,display_name) values
 ('d3300000-0000-4000-8000-000000000001','Listing A'),
 ('d3300000-0000-4000-8000-000000000002','Listing B');
create temp table listing_ctx(k text primary key,v jsonb);
grant all on listing_ctx to authenticated,service_role;
-- Giả lập điểm gọi RPC của module Request, không mở grants/policy ghi mobile.
create function pg_temp.accept_listing_request() returns void language sql security definer set search_path='' as $$
  update public.exchange_requests set status='ACCEPTED' where id='d3300000-0000-4000-8000-000000000010'
$$;
set local role authenticated;
set local request.jwt.claim.sub='d3300000-0000-4000-8000-000000000001';
insert into listing_ctx values('m',public.save_material(
 '{"title":"Sách trùng tên","subject":"Toán","condition":"Tốt","image_ids":[]}','n3-m'));
insert into listing_ctx values('m2',public.save_material(
 '{"title":"Sách trùng tên","subject":"Toán","condition":"Tốt","image_ids":[]}','n3-m2'));
insert into listing_ctx values('draft',public.save_listing('draft',
 '{"offer_type":"SELL"}','n3-draft',(select (v->>'id')::uuid from listing_ctx where k='m'),null,null,1));
select extensions.is((select v->'data'->>'status' from listing_ctx where k='draft'),'DRAFT','SELL draft thiếu giá hợp lệ');
select extensions.is(public.save_listing('draft','{"offer_type":"SELL"}','n3-draft',
 (select (v->>'id')::uuid from listing_ctx where k='m'),null,null,1),
 (select v from listing_ctx where k='draft'),'Retry cùng payload giữ nguyên ACK/ID');
select extensions.throws_ok($$select public.save_listing('draft','{"offer_type":"BORROW"}','n3-draft',
 (select (v->>'id')::uuid from listing_ctx where k='m'),null,null,1)$$,'P0001','CONFLICT','Key cũ payload mới bị chặn');
select extensions.throws_ok($$select public.save_listing('draft','{"offer_type":"BORROW"}','n3-duplicate',
 (select (v->>'id')::uuid from listing_ctx where k='m'),null,null,1)$$,'P0001','CONFLICT','DRAFT cũng chiếm suất hiện hành');
select extensions.throws_ok($$select public.save_listing('publish','{"offer_type":"SELL"}','n3-null-price',null,
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),1,1)$$,'P0001','INVALID_INPUT','Công bố SELL thiếu giá bị chặn');
select extensions.throws_ok($$select public.save_listing('publish','{"offer_type":"BORROW"}','n3-no-image',null,
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),1,1)$$,'P0001','INVALID_INPUT','Không ảnh không công bố');
select extensions.is((public.get_my_listing((select (v->'data'->>'id')::uuid from listing_ctx where k='draft'))->>'revision')::bigint,
 1::bigint,'Publish lỗi rollback cả sửa nháp/revision');
select extensions.throws_ok($$select public.save_listing('draft','{"offer_type":"SELL","asking_price_vnd":1.5}','n3-float',null,
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),1,1)$$,'P0001','INVALID_INPUT','Không làm tròn giá lẻ');
select extensions.throws_ok($$select public.save_listing('draft','{"offer_type":"SELL","asking_price_vnd":"100"}','n3-string',null,
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),1,1)$$,'P0001','INVALID_INPUT','Giá RPC sai kiểu bị chặn');
select extensions.throws_ok($$select public.save_listing('draft','{"offer_type":"SELL","asking_price_vnd":9223372036854775808}','n3-overflow',null,
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),1,1)$$,'P0001','INVALID_INPUT','Chặn overflow bigint');
select extensions.throws_ok($$select public.save_listing('draft','{"offer_type":"DONATE","asking_price_vnd":1}','n3-donate-price',null,
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),1,1)$$,'P0001','INVALID_INPUT','DONATE không nhận giá');
select extensions.throws_ok($$select public.save_listing('draft','{"offer_type":"BORROW","owner_id":"x"}','n3-forge',null,
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),1,1)$$,'P0001','INVALID_INPUT','Chặn mass assignment');
insert into listing_ctx values('upload',public.prepare_material_image('image/png',68,(select (v->>'id')::uuid from listing_ctx where k='m')));
reset role;
insert into storage.objects(bucket_id,name,metadata) select 'studyshare-material-images',v->>'storage_path',
 '{"size":68,"mimetype":"image/png"}' from listing_ctx where k='upload';
set local role service_role;
select public.verify_material_image_upload((select (v->>'id')::uuid from listing_ctx where k='upload'),
 'd3300000-0000-4000-8000-000000000001');
reset role;
set local role authenticated;
select extensions.throws_ok($$select public.save_listing('publish','{"offer_type":"SELL","asking_price_vnd":1}','n3-unattached',null,
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),1,1)$$,'P0001','INVALID_INPUT','VERIFIED chưa gắn không đủ ảnh');
insert into listing_ctx values('attached',public.save_material(jsonb_build_object('title','Sách trùng tên','subject','Toán','condition','Tốt',
 'image_ids',jsonb_build_array((select v->>'id' from listing_ctx where k='upload'))),'n3-attach',
 (select (v->>'id')::uuid from listing_ctx where k='m'),1));
select extensions.throws_ok($$select public.save_listing('publish','{"offer_type":"SELL","asking_price_vnd":1}','n3-stale-m',null,
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),1,1)$$,'P0001','CONFLICT','Material revision cũ bị chặn');
insert into listing_ctx values('published',public.save_listing('publish','{"offer_type":"SELL","asking_price_vnd":1,"description":"Giá chốt"}',
 'n3-publish',null,(select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),1,2));
select extensions.is((select v->'data'->>'status' from listing_ctx where k='published'),'PUBLISHED','Công bố ảnh đã gắn và giá 1');
select extensions.is(public.get_listing_command_result('listing_publish','n3-publish'),
 (select v from listing_ctx where k='published'),'Tra receipt sau timeout');
select extensions.throws_ok($$update public.listings set status='HIDDEN'$$,'42501',null,'Mobile không UPDATE trực tiếp');
set local request.jwt.claim.sub='d3300000-0000-4000-8000-000000000002';
select extensions.is((public.get_published_listing((select (v->'data'->>'id')::uuid from listing_ctx where k='draft'))->>'title'),
 'Sách trùng tên','B đọc DTO từ snapshot');
select extensions.ok((public.get_published_listing((select (v->'data'->>'id')::uuid from listing_ctx where k='draft'))->>'is_requestable')::boolean,
 'B được gửi yêu cầu khi khả dụng');
select extensions.is((select count(*) from public.materials),0::bigint,'B không SELECT raw Material A');
select extensions.is((select count(*) from storage.objects where bucket_id='studyshare-material-images'),1::bigint,'B đọc đúng ảnh đang công bố');
select extensions.is(public.get_my_listing((select (v->'data'->>'id')::uuid from listing_ctx where k='draft')),null::jsonb,'B không đọc quản lý tin A');
select extensions.throws_ok($$select public.save_listing('hide','{}','n3-b-hide',null,
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),
 (select (v->>'server_revision')::bigint from listing_ctx where k='published'))$$,'P0001','FORBIDDEN','B không ẩn tin A');
reset role;
insert into public.exchange_requests(id,listing_id,requester_id) values('d3300000-0000-4000-8000-000000000010',
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),'d3300000-0000-4000-8000-000000000002');
set local role authenticated;
set local request.jwt.claim.sub='d3300000-0000-4000-8000-000000000001';
insert into listing_ctx values('hidden',public.save_listing('hide','{}','n3-hide',null,
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),
 (select (v->>'server_revision')::bigint from listing_ctx where k='published')));
select extensions.ok((public.get_my_listing((select (v->'data'->>'id')::uuid from listing_ctx where k='draft'))->>'has_pending_requests')::boolean,
 'Ẩn giữ Request PENDING');
select extensions.throws_ok($$select public.save_listing('draft','{"offer_type":"DONATE"}','n3-edit-pending',null,
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),
 (select (v->>'server_revision')::bigint from listing_ctx where k='hidden'),2)$$,'P0001','MATERIAL_UNAVAILABLE','Không đổi điều kiện đang có PENDING');
select extensions.throws_ok($$update public.exchange_requests set status='ACCEPTED' where id='d3300000-0000-4000-8000-000000000010'$$,
 '42501',null,'Không duyệt bằng direct update');
select extensions.throws_ok($$select pg_temp.accept_listing_request()$$,'P0001','MATERIAL_UNAVAILABLE',
 'Guard vẫn chặn RPC definer duyệt Request khi Listing HIDDEN');
set local request.jwt.claim.sub='d3300000-0000-4000-8000-000000000002';
select extensions.is(public.get_published_listing((select (v->'data'->>'id')::uuid from listing_ctx where k='draft')),null::jsonb,'Tin HIDDEN không có DTO công khai');
select extensions.is(public.get_listing_image_path((select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),
 (select (v->>'id')::uuid from listing_ctx where k='upload')),null::text,'Tin HIDDEN không cấp path mới');
select extensions.is((select count(*) from storage.objects where bucket_id='studyshare-material-images'),0::bigint,'Tin HIDDEN không đọc bucket bằng quyền công bố');
set local request.jwt.claim.sub='d3300000-0000-4000-8000-000000000001';
insert into listing_ctx values('shown',public.save_listing('show','{}','n3-show',null,
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),
 (select (v->>'server_revision')::bigint from listing_ctx where k='hidden'),2));
select extensions.is((select v->'data'->>'asking_price_vnd' from listing_ctx where k='shown'),'1','Hiện lại giữ nguyên điều kiện PENDING');
reset role;
update public.exchange_requests set status='ACCEPTED' where id='d3300000-0000-4000-8000-000000000010';
insert into public.transactions(id,listing_id,request_id,material_id,type,owner_at_acceptance,receiver_id,status,agreed_price_vnd)
 values('d3300000-0000-4000-8000-000000000020',
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),'d3300000-0000-4000-8000-000000000010',
 (select (v->>'id')::uuid from listing_ctx where k='m'),'SELL','d3300000-0000-4000-8000-000000000001',
 'd3300000-0000-4000-8000-000000000002','AWAITING_PAYMENT',1);
select extensions.is((select terms_snapshot->'listing'->>'description' from public.transactions
 where id='d3300000-0000-4000-8000-000000000020'),'Giá chốt','Transaction có snapshot điều kiện');
select extensions.is((select jsonb_array_length(terms_snapshot->'listing'->'images') from public.transactions
 where id='d3300000-0000-4000-8000-000000000020'),1,'Transaction snapshot có media ID lịch sử');
set local role authenticated;
set local request.jwt.claim.sub='d3300000-0000-4000-8000-000000000002';
select extensions.ok((public.get_published_listing((select (v->'data'->>'id')::uuid from listing_ctx where k='draft'))->>'is_reserved')::boolean,'AWAITING_PAYMENT đã RESERVED');
select extensions.ok(not (public.get_published_listing((select (v->'data'->>'id')::uuid from listing_ctx where k='draft'))->>'is_requestable')::boolean,'RESERVED không Request');
select extensions.is(jsonb_array_length(public.search_published_listings('Sách')->'items'),1,'RESERVED vẫn xuất hiện trong tìm kiếm');
set local request.jwt.claim.sub='d3300000-0000-4000-8000-000000000001';
insert into listing_ctx values('active-hidden',public.save_listing('hide','{}','n3-active-hide',null,
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),
 (select (v->>'server_revision')::bigint from listing_ctx where k='shown')));
select extensions.throws_ok($$select public.save_listing('draft','{"offer_type":"DONATE"}','n3-active-edit',null,
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),
 (select (v->>'server_revision')::bigint from listing_ctx where k='active-hidden'),2)$$,'P0001','MATERIAL_UNAVAILABLE','Active transaction khóa nội dung');
set local request.jwt.claim.sub='d3300000-0000-4000-8000-000000000002';
select extensions.is(public.get_transaction_listing_image_path('d3300000-0000-4000-8000-000000000020',
 (select (v->>'id')::uuid from listing_ctx where k='upload')),
 (select v->>'storage_path' from listing_ctx where k='upload'),'B đọc ảnh snapshot theo Transaction khi tin ẩn');
select extensions.is((select count(*) from storage.objects where bucket_id='studyshare-material-images'),1::bigint,
 'Storage cấp đúng quyền ảnh lịch sử của A/B');
set local request.jwt.claim.sub='d3300000-0000-4000-8000-000000000001';
select extensions.lives_ok($$select public.save_listing('show','{}','n3-active-show',null,
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),
 (select (v->>'server_revision')::bigint from listing_ctx where k='active-hidden'))$$,'Được hiện nguyên snapshot active');
select extensions.lives_ok($$select public.save_listing('draft','{"offer_type":"BORROW"}','n3-second-physical',
 (select (v->>'id')::uuid from listing_ctx where k='m2'),null,null,1)$$,'Tên trùng, khác Material vẫn tạo tin riêng');
reset role;
select extensions.is((select count(*) from public.transactions where material_id=(select (v->>'id')::uuid from listing_ctx where k='m')),1::bigint,'Ẩn/hiện không tạo hoặc hủy Transaction');
-- Fixture terminal/chuyển chủ để kiểm tra biên tích hợp; không giả đã chạy workflow bàn giao.
update public.transactions set status='COMPLETED' where id='d3300000-0000-4000-8000-000000000020';
update public.listings set status='ARCHIVED' where id=(select (v->'data'->>'id')::uuid from listing_ctx where k='draft');
update public.materials set owner_id='d3300000-0000-4000-8000-000000000002',holder_id='d3300000-0000-4000-8000-000000000002'
 where id=(select (v->>'id')::uuid from listing_ctx where k='m');
set local role authenticated;
select extensions.is(public.get_my_listing((select (v->'data'->>'id')::uuid from listing_ctx where k='draft')),null::jsonb,
 'Chủ cũ mất quyền quản lý sau chuyển chủ');
select extensions.throws_ok($$select public.save_listing('publish','{"offer_type":"SELL","asking_price_vnd":1,"description":"Giá chốt"}',
 'n3-publish',null,(select (v->'data'->>'id')::uuid from listing_ctx where k='draft'),1,2)$$,'P0001','FORBIDDEN',
 'Receipt cũ không cấp lại quyền mutation sau mất chủ');
set local request.jwt.claim.sub='d3300000-0000-4000-8000-000000000002';
select extensions.is(public.get_my_listing((select (v->'data'->>'id')::uuid from listing_ctx where k='draft')),null::jsonb,
 'Chủ mới không sửa Listing lịch sử của A');
select extensions.lives_ok($$select public.save_listing('publish','{"offer_type":"DONATE"}','n3-new-owner',
 (select (v->>'id')::uuid from listing_ctx where k='m'),null,null,2)$$,'Chủ mới đăng lượt mới cùng Material, dùng ảnh uploader A');
select public.save_listing('hide','{}','n3-new-owner-hide',null,
 (public.get_my_listing(null,(select (v->>'id')::uuid from listing_ctx where k='m'))->>'id')::uuid,
 (public.get_my_listing(null,(select (v->>'id')::uuid from listing_ctx where k='m'))->>'revision')::bigint);
select public.save_material('{"title":"Sau chuyển chủ","subject":"Toán","condition":"Tốt","image_ids":[]}',
 'n3-remove-gallery',(select (v->>'id')::uuid from listing_ctx where k='m'),2);
set local request.jwt.claim.sub='d3300000-0000-4000-8000-000000000001';
select extensions.is(public.get_transaction_listing_image_path('d3300000-0000-4000-8000-000000000020',
 (select (v->>'id')::uuid from listing_ctx where k='upload')),
 (select v->>'storage_path' from listing_ctx where k='upload'),'Gỡ gallery không mất quyền ảnh thỏa thuận lịch sử');
set local request.jwt.claim.sub='d3300000-0000-4000-8000-000000000003';
select extensions.is(public.get_transaction_listing_image_path('d3300000-0000-4000-8000-000000000020',
 (select (v->>'id')::uuid from listing_ctx where k='upload')),null::text,'Người ngoài không lấy path ảnh lịch sử');
select extensions.is((select count(*) from storage.objects where bucket_id='studyshare-material-images'),0::bigint,
 'Ảnh lịch sử không trở thành ảnh công khai');
reset role;
select extensions.is((select count(*) from public.listing_snapshot_images where listing_id=
 (select (v->'data'->>'id')::uuid from listing_ctx where k='draft')),1::bigint,'Archive không xóa media tham chiếu lịch sử');
set local role anon;
select extensions.throws_ok($$select public.get_published_listing('d3300000-0000-4000-8000-000000000099')$$,
 '42501',null,'Anon không gọi public read RPC');
reset role;
select * from extensions.finish();
rollback;
