begin;
create table public.sourcing_limits(id boolean primary key default true check(id),daily_per_org integer not null check(daily_per_org between 1 and 100),monthly_per_candidate integer not null check(monthly_per_candidate between 1 and 10));
alter table public.sourcing_limits enable row level security;
insert into public.sourcing_limits values(true,20,3);
revoke all on public.sourcing_limits from public,anon,authenticated;
create table public.sourcing_invitations(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,job_id uuid not null,candidate_id uuid not null references public.candidate_profiles(user_id),
 kind text not null check(kind in ('apply','test')),sender_id uuid not null references public.profiles(id),created_at timestamptz not null default now(),
 unique(job_id,candidate_id,kind),foreign key(organization_id,job_id) references public.jobs(organization_id,id)
);
create index sourcing_invites_org_time on public.sourcing_invitations(organization_id,created_at);
create index sourcing_invites_candidate_time on public.sourcing_invitations(candidate_id,created_at);
alter table public.sourcing_invitations enable row level security;
create policy invitation_read on public.sourcing_invitations for select to authenticated using(candidate_id=auth.uid() or public.is_org_member(organization_id));
revoke all on public.sourcing_invitations from anon,authenticated;
grant select on public.sourcing_invitations to authenticated;
-- Calendar contract only; creation/confirmation will belong to the interview workflow.
create table public.interview_appointments(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,application_id uuid not null,
 status text not null check(status in ('proposed','confirmed','cancelled','completed')),starts_at timestamptz not null,
 foreign key(organization_id,application_id) references public.applications(organization_id,id)
);
create index interview_org_status_time on public.interview_appointments(organization_id,status,starts_at);
alter table public.interview_appointments enable row level security;
create policy interview_read on public.interview_appointments for select to authenticated using(public.is_org_member(organization_id) or exists(select 1 from public.applications a where a.id=application_id and a.candidate_id=auth.uid()));
revoke all on public.interview_appointments from anon,authenticated;
grant select on public.interview_appointments to authenticated;
create function public.recruiter_dashboard(org uuid,page_number integer default 1) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not public.is_org_member(org) then raise exception 'forbidden';end if;
 if page_number not between 1 and 100000 then raise exception 'invalid page';end if;
 return jsonb_build_object(
 'jobs_total',(select count(*) from public.jobs where organization_id=org),
 'waiting_grading',(select count(*) from public.test_attempts where organization_id=org and status='submitted' and review_ready_at is null),
 'waiting_review',(select count(*) from public.applications where organization_id=org and status in ('submitted','under_review')),
 'proposed',(select count(*) from public.interview_appointments where organization_id=org and status='proposed'),
 'confirmed',(select count(*) from public.interview_appointments where organization_id=org and status='confirmed'),
 'jobs',coalesce((select jsonb_agg(to_jsonb(x)) from (select j.id,j.title,j.status,(select count(*) from public.applications a where a.job_id=j.id) applicants from public.jobs j where j.organization_id=org order by j.created_at desc,j.id limit 20 offset (page_number-1)*20)x),'[]'::jsonb));
end $$;
create function public.source_candidates(org uuid,channel text,filters jsonb default '{}',page_number integer default 1) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if not public.is_org_member(org) then raise exception 'forbidden';end if;
 if channel not in ('applied','public') or page_number not between 1 and 100000 then raise exception 'invalid query';end if;
 -- Only whitelist projections: CV, contact details, source identities and other jobs' scores never enter this result.
 with cards as (
 select a.id application_id,a.candidate_id,a.job_id,a.status,a.profile_snapshot card from public.applications a where channel='applied' and a.organization_id=org
 union all
 select null,p.user_id,null,null,jsonb_build_object('display_name',p.display_name,'school',p.school,'study_year',p.study_year,'district',p.district,'province',p.province,'desired_position',p.desired_position,'work_mode',p.work_mode,'salary',p.salary,'salary_unit',p.salary_unit,'skills',p.skills,'bio',p.bio)
 from public.candidate_profiles p where channel='public' and p.discoverable
 ), filtered as (
 select * from cards c where
 (coalesce(filters->>'job','')='' or c.job_id::text=filters->>'job') and
 (coalesce(filters->>'status','')='' or c.status=filters->>'status') and
 (coalesce(filters->>'skill','')='' or exists(select 1 from jsonb_array_elements_text(c.card->'skills') s where s ilike '%'||(filters->>'skill')||'%')) and
 (coalesce(filters->>'area','')='' or concat(c.card->>'district',' ',c.card->>'province') ilike '%'||(filters->>'area')||'%') and
 (coalesce(filters->>'position','')='' or c.card->>'desired_position' ilike '%'||(filters->>'position')||'%') and
 (coalesce(filters->>'mode','')='' or c.card->>'work_mode'=filters->>'mode') and
 (coalesce(filters->>'salary_max','')='' or (c.card->>'salary_unit'=filters->>'salary_unit' and (c.card->>'salary')::numeric<=(filters->>'salary_max')::numeric))
 ), paged as (select * from filtered order by candidate_id,application_id nulls last limit 20 offset (page_number-1)*20)
 select jsonb_build_object('total',(select count(*) from filtered),'items',coalesce((select jsonb_agg(to_jsonb(p)) from paged p),'[]'::jsonb)) into result;
 return result;
end $$;
create function public.send_sourcing_invitation(org uuid,job uuid,candidate uuid,invitation_kind text) returns uuid language plpgsql security definer set search_path='' as $$
declare j public.jobs;existing uuid;lim public.sourcing_limits;result uuid;
begin
 -- Organization and candidate locks serialize quota checks even across HR accounts/tenants.
 perform 1 from public.organizations where id=org for update;
 if not public.is_org_member(org) then raise exception 'forbidden';end if;
 select * into j from public.jobs where id=job and organization_id=org for share;
 if not found or j.status<>'published' or not exists(select 1 from public.organizations where id=org and verification_status='verified') then raise exception 'job unavailable';end if;
 perform 1 from public.candidate_profiles where user_id=candidate and discoverable for update;
 if not found then raise exception 'candidate unavailable';end if;
 if invitation_kind not in ('apply','test') or invitation_kind is null or (invitation_kind='test' and not j.test_enabled) then raise exception 'invalid kind';end if;
 select id into existing from public.sourcing_invitations where job_id=job and candidate_id=candidate and kind=invitation_kind;
 if found then return existing;end if;
 if exists(select 1 from public.applications where job_id=job and candidate_id=candidate) then raise exception 'already applied';end if;
 select * into lim from public.sourcing_limits where id=true;
 if (select count(*) from public.sourcing_invitations where organization_id=org and created_at>=date_trunc('day',clock_timestamp() at time zone 'UTC') at time zone 'UTC')>=lim.daily_per_org or
 (select count(*) from public.sourcing_invitations where candidate_id=candidate and created_at>=clock_timestamp()-interval '30 days')>=lim.monthly_per_candidate then raise exception 'invitation quota exceeded';end if;
 insert into public.sourcing_invitations(organization_id,job_id,candidate_id,kind,sender_id) values(org,job,candidate,invitation_kind,auth.uid()) returning id into result;
 return result;
end $$;
revoke all on function public.recruiter_dashboard(uuid,integer),public.source_candidates(uuid,text,jsonb,integer),public.send_sourcing_invitation(uuid,uuid,uuid,text) from public,anon;
grant execute on function public.recruiter_dashboard(uuid,integer),public.source_candidates(uuid,text,jsonb,integer),public.send_sourcing_invitation(uuid,uuid,uuid,text) to authenticated;
commit;
