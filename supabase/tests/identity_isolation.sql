-- Chạy trên Supabase local đã áp dụng migration, bằng kết nối postgres; rollback toàn bộ fixture.
-- Kiểm thử mô phỏng JWT auth.uid(), không thay thế kiểm thử HTTP bằng token thật.
begin;
insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000001', 'isolation-a@example.test'),
  ('00000000-0000-4000-8000-000000000002', 'isolation-b@example.test');
insert into public.profiles (id, display_name) values
  ('00000000-0000-4000-8000-000000000001', 'A'),
  ('00000000-0000-4000-8000-000000000002', 'B') on conflict (id) do update set display_name=excluded.display_name;
insert into public.candidate_profiles (user_id) values
  ('00000000-0000-4000-8000-000000000001');
insert into public.organizations (id, name) values
  ('10000000-0000-4000-8000-000000000001', 'Org A'),
  ('10000000-0000-4000-8000-000000000002', 'Org B');
insert into public.organization_members (organization_id, user_id, role) values
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'recruiter'),
  ('10000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000002', 'org_admin');
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
do $$
begin
  if (select count(*) from public.organizations) <> 1 or
     exists (select 1 from public.organizations where id = '10000000-0000-4000-8000-000000000002') then
    raise exception 'Org A có thể xem Org B hoặc không thấy Org A';
  end if;
  if (select count(*) from public.profiles) <> 1 or
     exists (select 1 from public.profiles where id = '00000000-0000-4000-8000-000000000002') then
    raise exception 'Có thể xem profile người khác';
  end if;
  if not exists (select 1 from public.candidate_profiles where not discoverable and not avatar_visible) then
    raise exception 'Mặc định quyền riêng tư không an toàn';
  end if;
  begin
    insert into public.organization_members (organization_id, user_id, role)
      values ('10000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'org_admin');
    raise exception 'Có thể tự cấp membership';
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;
