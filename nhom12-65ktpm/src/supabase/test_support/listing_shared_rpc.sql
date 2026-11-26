-- Harness local tạm thời: kiểm tra trigger qua PostgREST/JWT thật.
-- Đặt ngoài tests/: CLI quét mọi file SQL trong cây tests như một bài pgTAP.
-- Không nằm trong migrations, không triển khai cloud, không thay RPC Request của Khanh.
begin;
create function public._test_listing_review_request(p_listing_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid; material uuid;
begin
  if not exists(select 1 from auth.users where id=auth.uid() and email ~ '^n3-[ab]-.*@example\.test$')
    then raise exception 'FORBIDDEN'; end if;
  select material_id into material from public.listings where id=p_listing_id;
  perform 1 from public.materials where id=material for update;
  insert into public.exchange_requests(listing_id,requester_id)
    values(p_listing_id,auth.uid()) returning id into result;
  return result;
end $$;

create function public._test_listing_review_approve(p_request_id uuid,
  p_wrong_order boolean default false,p_fail_after_insert boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare material uuid; r public.exchange_requests; l public.listings; result uuid;
begin
  if not exists(select 1 from auth.users where id=auth.uid() and email ~ '^n3-[ab]-.*@example\.test$')
    then raise exception 'FORBIDDEN'; end if;
  select x.material_id into material from public.exchange_requests q
    join public.listings x on x.id=q.listing_id where q.id=p_request_id;
  -- Cùng thứ tự khóa với Listing; không khóa Request trước rồi chờ Material.
  perform 1 from public.materials where id=material and owner_id=auth.uid() for update;
  if not found then raise exception 'FORBIDDEN'; end if;
  select * into r from public.exchange_requests where id=p_request_id for update;
  if r.status<>'PENDING' then raise exception 'REQUEST_NOT_PENDING'; end if;
  if not exists(select 1 from auth.users where id=r.requester_id and email ~ '^n3-[ab]-.*@example\.test$')
    then raise exception 'FORBIDDEN'; end if;
  select * into l from public.listings where id=r.listing_id;
  if l.offer_type<>'SELL' then raise exception 'INVALID_INPUT'; end if;
  if not p_wrong_order then
    update public.exchange_requests set status='ACCEPTED' where id=r.id;
  end if;
  insert into public.transactions(listing_id,request_id,material_id,type,owner_at_acceptance,
    receiver_id,status,agreed_price_vnd,terms_snapshot)
    values(l.id,r.id,material,'SELL',auth.uid(),r.requester_id,'AWAITING_PAYMENT',l.asking_price_vnd,
      '{"transaction_contract":"kept","listing":{"caller_fake":true}}') returning id into result;
  insert into public.payment_confirmations(transaction_id,amount_vnd) values(result,l.asking_price_vnd);
  -- Ca âm kiểm tra guard/rollback, không phải lựa chọn của API sản phẩm.
  if p_wrong_order then
    update public.exchange_requests set status='ACCEPTED' where id=r.id;
  end if;
  if p_fail_after_insert then raise exception 'CONFLICT'; end if;
  return result;
end $$;
revoke all on function public._test_listing_review_request(uuid),
  public._test_listing_review_approve(uuid,boolean,boolean) from public,anon,authenticated;
grant execute on function public._test_listing_review_request(uuid),
  public._test_listing_review_approve(uuid,boolean,boolean) to authenticated;
notify pgrst,'reload schema';
commit;
