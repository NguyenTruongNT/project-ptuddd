-- Bảo đảm client thường không thể đọc/bỏ qua các bảng quan trọng.
-- Các test dưới đây chạy trong giao dịch và KHÔNG sửa dữ liệu thật.
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(4);

set local role authenticated;
do $$
begin
  begin
    perform 1 from public.transactions limit 1;
    raise exception 'LOI: authenticated dang co quyen doc transactions';
  exception when insufficient_privilege then
    null; -- Kết quả đúng: backend chưa mở quyền đọc raw transaction.
  end;
end $$;
reset role;
select extensions.pass('authenticated bi chan SELECT transactions');

set local role authenticated;
do $$
begin
  begin
    perform 1 from public.material_qr_credentials limit 1;
    raise exception 'LOI: authenticated dang duoc doc QR secret';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
select extensions.pass('authenticated bi chan SELECT QR secret');

set local role anon;
do $$
begin
  begin
    perform 1 from public.profiles limit 1;
    raise exception 'LOI: anonymous dang duoc doc profiles';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
select extensions.pass('anon bi chan SELECT profiles');

set local role authenticated;
do $$
begin
  begin
    perform 1 from public.handover_evidence limit 1;
    raise exception 'LOI: authenticated dang duoc doc bang evidence';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
select extensions.pass('authenticated bi chan SELECT handover evidence');

select * from extensions.finish();
rollback;
