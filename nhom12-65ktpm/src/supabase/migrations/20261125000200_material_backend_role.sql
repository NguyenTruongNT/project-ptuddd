-- Cloud không tự cấp table grants cho service_role như stack local.
-- Chỉ backend tin cậy; KHÔNG cấp thêm quyền anon/authenticated.
-- Các quyền này phục vụ tác vụ server và fixture test A/B có cleanup giới hạn.
grant select,insert,update,delete on public.materials,public.material_images,
  public.material_image_uploads,public.command_receipts,public.listings
  to service_role;
