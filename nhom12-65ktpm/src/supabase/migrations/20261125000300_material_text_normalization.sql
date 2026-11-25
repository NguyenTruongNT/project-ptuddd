-- PostgreSQL trim() chỉ bỏ space; align server với Dart trim cho tab/newline.
-- Trigger giữ nguyên các update owner/holder từ workflow giao nhận.
create function studyshare_private.normalize_material_fields()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  new.title:=regexp_replace(new.title,'^[[:space:]]+|[[:space:]]+$','','g');
  new.subject:=regexp_replace(new.subject,'^[[:space:]]+|[[:space:]]+$','','g');
  new.condition:=regexp_replace(new.condition,'^[[:space:]]+|[[:space:]]+$','','g');
  new.description:=nullif(regexp_replace(new.description,
    '^[[:space:]]+|[[:space:]]+$','','g'),'');
  new.isbn:=nullif(upper(regexp_replace(coalesce(new.isbn,''),
    '[[:space:]-]','','g')),'');
  if new.title is null or char_length(new.title) not between 1 and 200
    or new.subject is null or char_length(new.subject) not between 1 and 100
    or new.condition is null or char_length(new.condition) not between 1 and 100
    or char_length(new.description)>2000
    or translate(new.title||new.subject||new.condition||coalesce(new.description,''),
      E'\n\r\t','') ~ '[[:cntrl:]]'
    or not studyshare_private.valid_isbn(new.isbn) then
    raise exception 'INVALID_INPUT';
  end if;
  return new;
end $$;
revoke all on function studyshare_private.normalize_material_fields()
  from public,anon,authenticated,service_role;
create trigger material_normalize_text
  before insert or update of title,subject,condition,description,isbn
  on public.materials for each row
  execute function studyshare_private.normalize_material_fields();
