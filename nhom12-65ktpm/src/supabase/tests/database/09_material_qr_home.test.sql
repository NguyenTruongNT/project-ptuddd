-- Kiểm tra QR thật, quyền hiện tại, hard block và tổng Home vượt một trang.
begin;
create extension if not exists pgtap with schema extensions;
select extensions.no_plan();

insert into auth.users(id,email) values
 ('d4400000-0000-4000-8000-000000000001','qr-a@example.test'),
 ('d4400000-0000-4000-8000-000000000002','qr-b@example.test'),
 ('d4400000-0000-4000-8000-000000000003','qr-outsider@example.test');
insert into public.materials(id,owner_id,holder_id,title,subject,condition) values
 ('e4400000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000001','Sach trung ten','CNTT','Tot'),
 ('e4400000-0000-4000-8000-000000000002','d4400000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000001','Sach trung ten','CNTT','Tot'),
 ('e4400000-0000-4000-8000-000000000003','d4400000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000001','Credential cu','CNTT','Tot');
create temporary table qr_ctx(k text primary key,v jsonb);

select set_config('request.jwt.claim.sub','',true);
select extensions.throws_ok($$select public.ensure_material_qr('e4400000-0000-4000-8000-000000000001','a')$$,'P0001','AUTH_REQUIRED','QR can dang nhap');
select extensions.throws_ok($$select public.get_home_overview()$$,'P0001','AUTH_REQUIRED','Home can dang nhap');
select set_config('request.jwt.claim.sub','d4400000-0000-4000-8000-000000000001',true);
select extensions.throws_ok($$select public.ensure_material_qr('khong-la-uuid','a')$$,'P0001','INVALID_INPUT','Chan ID sai dinh dang');
select extensions.throws_ok($$select public.ensure_material_qr('e4400000-0000-4000-8000-000000000001','')$$,'P0001','INVALID_INPUT','Chan key rong');
insert into qr_ctx values ('first',public.ensure_material_qr('e4400000-0000-4000-8000-000000000001','first'));
insert into qr_ctx values ('second',public.ensure_material_qr('e4400000-0000-4000-8000-000000000002','second'));
select extensions.ok((select (v->>'ok')::boolean from qr_ctx where k='first'),'Material khong anh va Listing van co QR');
select extensions.ok((select v->'data'->>'payload' from qr_ctx where k='first') ~ '^studyshare:material:1:[0-9a-f-]{36}:[0-9a-f]{64}$','Payload co loai, version va token kho doan');
select extensions.is((select v->'data'->>'material_id' from qr_ctx where k='first'),'e4400000-0000-4000-8000-000000000001','QR gan dung Material');
select extensions.isnt((select v->'data'->>'payload' from qr_ctx where k='first'),(select v->'data'->>'payload' from qr_ctx where k='second'),'Trung ten van khac QR');
select extensions.is(public.ensure_material_qr('e4400000-0000-4000-8000-000000000001','first')->>'command_id',(select v->>'command_id' from qr_ctx where k='first'),'Retry giu command receipt');
select extensions.is(public.ensure_material_qr('e4400000-0000-4000-8000-000000000001','reload')->'data'->>'payload',(select v->'data'->>'payload' from qr_ctx where k='first'),'Tai lai cung QR');
select extensions.is((select count(*) from public.material_qr_credentials where material_id='e4400000-0000-4000-8000-000000000001'),1::bigint,'Mot credential hien hanh');
select extensions.is((select revision from public.materials where id='e4400000-0000-4000-8000-000000000001'),1::bigint,'Phat hanh khong tang revision Material');
select extensions.throws_ok($$select public.ensure_material_qr('e4400000-0000-4000-8000-000000000002','first')$$,'P0001','CONFLICT','Cung key khac Material bi chan');
select extensions.ok(not exists(select 1 from public.command_receipts where command_name='ensure_material_qr' and result_json::text like '%studyshare:material:%'),'Receipt khong luu raw QR');
select extensions.ok(not has_table_privilege('authenticated','studyshare_private.material_qr_signing_keys','SELECT'),'App khong doc khoa ky');
select extensions.ok(not has_table_privilege('authenticated','public.material_qr_credentials','SELECT'),'App khong doc credential');
select extensions.ok(not has_function_privilege('anon','public.ensure_material_qr(text,text)','EXECUTE'),'Anon khong lay QR');
select extensions.ok(not has_function_privilege('authenticated','studyshare_private.material_qr_payload(uuid,integer)','EXECUTE'),'App khong tu goi helper lay token');

insert into public.material_qr_credentials(material_id,token_hash) values ('e4400000-0000-4000-8000-000000000003','hash-cu-khong-duoc-ghi-de');
select extensions.throws_ok($$select public.ensure_material_qr('e4400000-0000-4000-8000-000000000003','legacy')$$,'P0001','BACKEND_UNAVAILABLE','Khong tu xoay credential cu');
select extensions.is((select token_hash from public.material_qr_credentials where material_id='e4400000-0000-4000-8000-000000000003'),'hash-cu-khong-duoc-ghi-de','Giu nguyen hash cu');

select set_config('request.jwt.claim.sub','d4400000-0000-4000-8000-000000000002',true);
select extensions.throws_ok($$select public.ensure_material_qr('e4400000-0000-4000-8000-000000000001','other')$$,'P0001','FORBIDDEN','Nguoi khac khong lay QR');
select extensions.throws_ok($$select public.ensure_material_qr('e4400000-0000-4000-8000-999999999999','other')$$,'P0001','FORBIDDEN','Khong ton tai va khong co quyen cung loi');
update public.materials set owner_id='d4400000-0000-4000-8000-000000000002',holder_id='d4400000-0000-4000-8000-000000000002'
  where id='e4400000-0000-4000-8000-000000000001';
select extensions.is(public.ensure_material_qr('e4400000-0000-4000-8000-000000000001','new-owner')->'data'->>'payload',(select v->'data'->>'payload' from qr_ctx where k='first'),'Doi chu giu ID/QR');
select set_config('request.jwt.claim.sub','d4400000-0000-4000-8000-000000000001',true);
select extensions.throws_ok($$select public.ensure_material_qr('e4400000-0000-4000-8000-000000000001','first')$$,'P0001','FORBIDDEN','Chu cu khong replay receipt lay QR');

-- Listing là một lần đăng, QR là bản vật lý: kết thúc/tái đăng không xoay mã.
insert into public.listings(id,material_id,created_by,offer_type,status) values
 ('f4400000-0000-4000-8000-000000000002','e4400000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000002','DONATE','ARCHIVED'),
 ('f4400000-0000-4000-8000-000000000003','e4400000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000002','BORROW','DRAFT');
select set_config('request.jwt.claim.sub','d4400000-0000-4000-8000-000000000002',true);
select extensions.is(public.ensure_material_qr('e4400000-0000-4000-8000-000000000001','relist')->'data'->>'payload',
 (select v->'data'->>'payload' from qr_ctx where k='first'),'Tai dang Listing moi giu nguyen QR');
select set_config('request.jwt.claim.sub','d4400000-0000-4000-8000-000000000001',true);

insert into public.listings(id,material_id,created_by,offer_type,status) values
 ('f4400000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000002','d4400000-0000-4000-8000-000000000001','BORROW','PUBLISHED');
insert into public.exchange_requests(id,listing_id,requester_id,requested_borrow_days,status) values
 ('a4400000-0000-4000-8000-000000000001','f4400000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000002',7,'ACCEPTED');
insert into public.transactions(id,listing_id,request_id,material_id,type,owner_at_acceptance,receiver_id,status,agreed_borrow_days) values
 ('b4400000-0000-4000-8000-000000000001','f4400000-0000-4000-8000-000000000001','a4400000-0000-4000-8000-000000000001','e4400000-0000-4000-8000-000000000002','BORROW','d4400000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000002','AWAITING_HANDOVER',7);
insert into qr_ctx values ('handover',public.create_handover('b4400000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000002',null,'create-h'));
select extensions.ok((select (v->>'ok')::boolean from qr_ctx where k='handover'),'Tao chặng hop le');
select extensions.is(public.verify_material_code((select v->'data'->>'id' from qr_ctx where k='handover'),
 'e4400000-0000-4000-8000-000000000002','QR',null,'plain-id')->>'code','QR_MISMATCH','UUID thuan khong thay token');
select extensions.is(public.verify_material_code((select v->'data'->>'id' from qr_ctx where k='handover'),
 '','FALLBACK','Ma bi rach','after-mismatch')->>'code','QR_MISMATCH','Chan fallback sau mismatch tren server');
select extensions.ok((public.get_handover_details((select v->'data'->>'id' from qr_ctx where k='handover'))->>'qr_mismatch_blocked')::boolean,'Mo lai van co co mismatch');
select extensions.ok((public.verify_material_code((select v->'data'->>'id' from qr_ctx where k='handover'),
 (select v->'data'->>'payload' from qr_ctx where k='second'),'QR',null,'correct')->>'ok')::boolean,'Quet dung token go chan');
select extensions.is((select count(*) from public.transaction_events where transaction_id='b4400000-0000-4000-8000-000000000001' and event_type='HANDOVER_VERIFIED'),1::bigint,'Mot Event doi chieu');
select public.verify_material_code((select v->'data'->>'id' from qr_ctx where k='handover'),
 (select v->'data'->>'payload' from qr_ctx where k='second'),'QR',null,'correct');
select extensions.is((select count(*) from public.transaction_events where transaction_id='b4400000-0000-4000-8000-000000000001' and event_type='HANDOVER_VERIFIED'),1::bigint,'Retry khong trung Event');
select extensions.is((select holder_id::text from public.materials where id='e4400000-0000-4000-8000-000000000002'),'d4400000-0000-4000-8000-000000000001','Quet dung khong doi holder');
select extensions.is((select status from public.transactions where id='b4400000-0000-4000-8000-000000000001'),'HANDOVER_IN_PROGRESS','Quet dung khong doi Transaction sau create_handover');
select public.verify_material_code((select v->'data'->>'id' from qr_ctx where k='handover'),
 (select v->'data'->>'payload' from qr_ctx where k='first'),'QR',null,'other-book');
select extensions.is(public.verify_material_code((select v->'data'->>'id' from qr_ctx where k='handover'),
 (select v->'data'->>'payload' from qr_ctx where k='second'),'QR',null,'correct')->>'code','QR_MISMATCH','Receipt cu khong vuot mismatch moi');
select extensions.throws_ok($$update public.handovers set verification_method='FALLBACK' where transaction_id='b4400000-0000-4000-8000-000000000001'$$,'P0001','QR_MISMATCH','Trigger chan RPC khac bo qua mismatch');
select set_config('request.jwt.claim.sub','d4400000-0000-4000-8000-000000000003',true);
select extensions.is(public.verify_material_code((select v->'data'->>'id' from qr_ctx where k='handover'),
 (select v->'data'->>'payload' from qr_ctx where k='second'),'QR',null,'outsider')->>'code','INVALID_HANDOVER_PARTICIPANT','Chi giver cua chặng duoc doi chieu');

-- Hơn một trang Material vẫn phải đếm đủ; holder không làm thay owner.
insert into public.materials(owner_id,holder_id,title,subject,condition)
 select 'd4400000-0000-4000-8000-000000000001','d4400000-0000-4000-8000-000000000001','Them '||i,'CNTT','Tot' from generate_series(1,25) i;
select set_config('request.jwt.claim.sub','d4400000-0000-4000-8000-000000000001',true);
select extensions.is((public.get_home_overview()->>'material_count')::integer,27,'Home dem het 27 Material, khong chi 20 dong');
select extensions.is((public.get_home_overview()->>'published_count')::integer,1,'Tin RESERVED van la tin cong bo');
select extensions.is((public.get_home_overview()->>'active_transaction_count')::integer,1,'Home dem giao dich actor');
select set_config('request.jwt.claim.sub','d4400000-0000-4000-8000-000000000002',true);
select extensions.is((public.get_home_overview()->>'material_count')::integer,1,'Home B khong thay tong Material A');
select extensions.is((public.get_home_overview()->>'published_count')::integer,0,'Home B khong thay tin cua A');
select extensions.ok(not has_function_privilege('anon','public.get_home_overview()','EXECUTE'),'Anon khong doc so lieu Home');
select * from extensions.finish();
rollback;
