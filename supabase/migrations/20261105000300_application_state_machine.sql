alter table public.applications drop constraint applications_status_check;
alter table public.applications add constraint applications_status_check check(status in ('submitted','test_pending','test_submitted','under_review','interview_invited','rejected'));
alter table public.applications add column updated_at timestamptz not null default now(),add column decision_message text check(length(decision_message)<=2000);
alter table public.test_attempts add column review_ready_at timestamptz;
create table public.application_audit_logs(
 id uuid primary key default gen_random_uuid(),application_id uuid not null references public.applications(id),
 actor_id uuid references public.profiles(id),old_status text,new_status text not null,created_at timestamptz not null default now()
);
alter table public.application_audit_logs enable row level security;
create policy application_audit_read on public.application_audit_logs for select to authenticated using(exists(select 1 from public.applications a where a.id=application_id));
revoke all on public.application_audit_logs from anon,authenticated;
grant select on public.application_audit_logs to authenticated;
create index application_audit_application_idx on public.application_audit_logs(application_id,created_at);
create index applications_org_status_idx on public.applications(organization_id,status,created_at desc);
create function public.guard_application_transition() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='INSERT' then
  if new.status not in ('submitted','test_pending') then raise exception 'invalid initial status';end if;
 else
  if new.organization_id<>old.organization_id or new.job_id<>old.job_id or new.candidate_id<>old.candidate_id or new.profile_snapshot is distinct from old.profile_snapshot then raise exception 'immutable application';end if;
  if new.status<>old.status and not ((old.status='submitted' and new.status='under_review') or (old.status='test_pending' and new.status='test_submitted') or (old.status='test_submitted' and new.status='under_review') or (old.status='under_review' and new.status in ('interview_invited','rejected'))) then raise exception 'invalid transition';end if;
 end if;
 new.updated_at=now();return new;
end $$;
create trigger application_transition_guard before insert or update on public.applications for each row execute function public.guard_application_transition();
create function public.audit_application_transition() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then insert into public.application_audit_logs(application_id,actor_id,new_status) values(new.id,auth.uid(),new.status);
 elsif old.status<>new.status then insert into public.application_audit_logs(application_id,actor_id,old_status,new_status) values(new.id,auth.uid(),old.status,new.status);end if;
 return new;
end $$;
revoke all on function public.audit_application_transition() from public,anon,authenticated;
create trigger application_transition_audit after insert or update on public.applications for each row execute function public.audit_application_transition();
create function public.review_application(application uuid,expected text,target text,message text default null) returns void language plpgsql security definer set search_path='' as $$
declare a public.applications;
begin
 select * into a from public.applications where id=application for update;
 if not found or not public.is_org_member(a.organization_id) then raise exception 'forbidden';end if;
 if target not in ('under_review','interview_invited','rejected') or target is null then raise exception 'invalid target';end if;
 if a.status=target then return;end if;
 if a.status<>expected then raise exception 'stale state';end if;
 if not ((a.status='submitted' and target='under_review') or (a.status='under_review' and target in ('interview_invited','rejected'))) then raise exception 'invalid transition';end if;
 update public.applications set status=target,decision_message=case when target in ('interview_invited','rejected') then message else null end where id=application;
end $$;
revoke all on function public.review_application(uuid,text,text,text) from public,anon;
grant execute on function public.review_application(uuid,text,text,text) to authenticated;
-- Integration hook for the future trusted test processor; not exposed to candidates/HR/API.
create function public.application_test_event(attempt uuid,event text) returns void language plpgsql security definer set search_path='' as $$
declare t public.test_attempts;a public.applications;
begin
 select * into t from public.test_attempts where id=attempt for update;
 if not found or t.status<>'submitted' then raise exception 'test not submitted';end if;
 select * into a from public.applications where id=t.application_id and organization_id=t.organization_id for update;
 if event='submitted' then
  if a.status in ('test_submitted','under_review','interview_invited','rejected') then return;end if;
  if a.status<>'test_pending' then raise exception 'invalid transition';end if;
  update public.applications set status='test_submitted' where id=a.id;
 elsif event='graded' then
  if t.review_ready_at is null then raise exception 'grading incomplete';end if;
  if a.status in ('under_review','interview_invited','rejected') then return;end if;
  if a.status<>'test_submitted' then raise exception 'invalid transition';end if;
  update public.applications set status='under_review' where id=a.id;
 else raise exception 'invalid test event';end if;
end $$;
revoke all on function public.application_test_event(uuid,text) from public,anon,authenticated;
create or replace function public.apply_to_job(job uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare j public.jobs;p public.candidate_profiles;result uuid;
begin
 if not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null) then raise exception 'unauthorized';end if;
 select id into result from public.applications where job_id=job and candidate_id=auth.uid();
 if found then return result;end if;
 select * into j from public.jobs where id=job for share;
 if not found or j.status<>'published'  then raise exception 'job unavailable';end if;
 perform 1 from public.organizations o where o.id=j.organization_id and o.verification_status='verified' for share;
 if not found then raise exception 'organization unavailable';end if;
 select * into p from public.candidate_profiles where user_id=auth.uid();
 if not found or p.display_name is null or p.skills is null or p.district is null or p.province is null or p.desired_position is null or p.work_mode is null or p.salary is null or p.salary_unit is null then raise exception 'profile incomplete';end if;
 insert into public.applications(organization_id,job_id,candidate_id,status,profile_snapshot)
 values(j.organization_id,j.id,auth.uid(),case when j.test_enabled then 'test_pending' else 'submitted' end,jsonb_build_object('display_name',p.display_name,'school',p.school,'study_year',p.study_year,'district',p.district,'province',p.province,'desired_position',p.desired_position,'work_mode',p.work_mode,'salary',p.salary,'salary_unit',p.salary_unit,'skills',p.skills,'bio',p.bio,'avatar_visible',p.avatar_visible)) on conflict(job_id,candidate_id) do nothing;
 select id into result from public.applications where job_id=job and candidate_id=auth.uid();return result;
end $$;
revoke all on function public.apply_to_job(uuid) from public,anon;
grant execute on function public.apply_to_job(uuid) to authenticated;
