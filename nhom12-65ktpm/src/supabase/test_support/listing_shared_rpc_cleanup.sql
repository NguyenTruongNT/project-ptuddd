-- Dọn đúng hai RPC harness local; không xóa bảng hoặc dữ liệu người dùng.
begin;
drop function if exists public._test_listing_review_request(uuid);
drop function if exists public._test_listing_review_approve(uuid,boolean,boolean);
notify pgrst,'reload schema';
commit;
