begin;
insert into auth.users (id,email) values
 ('00000000-0000-4000-8000-000000000011','hr-a@example.test'),
 ('00000000-0000-4000-8000-000000000012','candidate@example.test');
insert into public.profiles (id,display_name) values
 ('00000000-0000-4000-8000-000000000011','HR A'),
 ('00000000-0000-4000-8000-000000000012','Candidate') on conflict (id) do update set display_name=excluded.display_name;
insert into public.candidate_profiles (user_id) values ('00000000-0000-4000-8000-000000000012');
insert into public.organizations (id,name) values
 ('20000000-0000-4000-8000-000000000001','A'),
 ('20000000-0000-4000-8000-000000000002','B');
insert into public.organization_members (organization_id,user_id,role) values
 ('20000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000011','recruiter');
insert into public.jobs (id,organization_id,title) values
 ('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Job A'),
 ('30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002','Job B');
insert into public.applications (id,organization_id,job_id,candidate_id,status,profile_snapshot) values
 ('40000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000012','test_pending','{}');
insert into public.test_attempts (id,organization_id,application_id,status,deadline) values
 ('50000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000002','issued',now()+interval '1 hour');
insert into public.test_grades (organization_id,attempt_id,score) values
 ('20000000-0000-4000-8000-000000000002','50000000-0000-4000-8000-000000000002',8);
do $$ begin
  begin
    insert into public.applications (organization_id,job_id,candidate_id,status,profile_snapshot) values
     ('20000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000012','submitted','{}');
    raise exception 'FK chéo tenant không bị chặn';
  exception when foreign_key_violation then null;
  end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000011',true);
do $$ begin
  if (select count(*) from public.jobs) <> 1 or exists (select 1 from public.applications) or exists (select 1 from public.test_attempts) or exists (select 1 from public.test_grades) then
    raise exception 'HR A truy cập được dữ liệu của B';
  end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000012',true);
do $$ begin
  if (select count(*) from public.applications) <> 1 or exists (select 1 from public.test_grades) then
    raise exception 'Candidate không đọc được application hoặc đọc được điểm';
  end if;
end $$;
rollback;
