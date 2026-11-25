-- ISBN-13 phải dùng prefix ISBN 978/979, không nhận EAN bất kỳ có checksum đúng.
-- Nguồn: https://www.isbn-international.org/index.php/node/10
create or replace function studyshare_private.valid_isbn(p_value text)
returns boolean language plpgsql immutable set search_path=''
as $$
declare v text:=upper(regexp_replace(coalesce(p_value,''),'[[:space:]-]','','g'));
  s integer:=0;
begin
  if v='' then return true; end if;
  if v ~ '^[0-9]{9}[0-9X]$' then
    for i in 1..10 loop
      s:=s+(11-i)*case when substr(v,i,1)='X' then 10 else substr(v,i,1)::integer end;
    end loop;
    return s%11=0;
  elsif v ~ '^97[89][0-9]{10}$' then
    for i in 1..13 loop
      s:=s+substr(v,i,1)::integer*case when i%2=1 then 1 else 3 end;
    end loop;
    return s%10=0;
  end if;
  return false;
end $$;
