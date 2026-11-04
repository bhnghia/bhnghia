begin;
alter table public.interview_appointments drop constraint interview_appointments_status_check;
alter table public.interview_appointments add constraint interview_appointments_status_check check(status in ('proposed','confirmed','declined','reschedule_requested','cancelled','completed'));
alter table public.interview_appointments add column timezone text not null default 'Asia/Ho_Chi_Minh',add column location text not null default '',add column revision integer not null default 1,add column candidate_note text;
create unique index interview_active_application on public.interview_appointments(application_id) where status in ('proposed','confirmed','reschedule_requested');
create table public.cv_consents(id uuid primary key default gen_random_uuid(),appointment_id uuid not null references public.interview_appointments(id),application_id uuid not null,organization_id uuid not null,candidate_id uuid not null references public.profiles(id),file_id uuid references public.candidate_cv_files(id),decision boolean not null,expires_at timestamptz,revoked_at timestamptz,created_at timestamptz not null default now(),foreign key(organization_id,application_id) references public.applications(organization_id,id),check(not decision or (file_id is not null and expires_at is not null)));
create index consent_access on public.cv_consents(application_id,expires_at) where decision and revoked_at is null;
create table public.cv_consent_audit(id uuid primary key default gen_random_uuid(),consent_id uuid not null references public.cv_consents(id),actor_id uuid references public.profiles(id),event text not null,created_at timestamptz not null default now());
alter table public.cv_consents enable row level security;
alter table public.cv_consent_audit enable row level security;
create policy consent_read on public.cv_consents for select to authenticated using(candidate_id=auth.uid() or public.is_org_member(organization_id));
create policy consent_audit_read on public.cv_consent_audit for select to authenticated using(exists(select 1 from public.cv_consents c where c.id=consent_id and c.candidate_id=auth.uid()));
revoke all on public.cv_consents,public.cv_consent_audit from anon,authenticated;
grant select on public.cv_consents,public.cv_consent_audit to authenticated;
create function public.propose_interview(application uuid,starts timestamptz,zone text,place text) returns uuid language plpgsql security definer set search_path='' as $$
declare a public.applications;i public.interview_appointments;result uuid;
begin
 select * into a from public.applications where id=application for update;
 if not found or not public.is_org_member(a.organization_id) then raise exception 'forbidden';end if;
 if a.status<>'interview_invited' or starts is null or not isfinite(starts) or starts<=clock_timestamp() or not exists(select 1 from pg_timezone_names where name=zone) or place is null or length(trim(place)) not between 1 and 1000 then raise exception 'invalid proposal';end if;
 select * into i from public.interview_appointments where application_id=application and status in ('proposed','confirmed','reschedule_requested') for update;
 if found then
 if i.status='confirmed' then raise exception 'confirmed schedule locked';end if;
 update public.interview_appointments set starts_at=starts,timezone=zone,location=place,status='proposed',revision=revision+1 where id=i.id;return i.id;
 end if;
 insert into public.interview_appointments(organization_id,application_id,status,starts_at,timezone,location) values(a.organization_id,application,'proposed',starts,zone,place) returning id into result;return result;
end $$;
create function public.respond_interview(appointment uuid,expected_revision integer,response text,share_cv boolean default null,cv_file uuid default null,note text default '') returns void language plpgsql security definer set search_path='' as $$
declare i public.interview_appointments;a public.applications;c uuid;
begin
 select * into i from public.interview_appointments where id=appointment for update;
 select * into a from public.applications where id=i.application_id;
 if a.candidate_id is distinct from auth.uid() or auth.uid() is null then raise exception 'forbidden';end if;
 if expected_revision is null or i.status<>'proposed' or i.revision<>expected_revision or i.starts_at<=clock_timestamp() or response not in ('confirmed','declined','reschedule_requested') or response is null or length(note)>1000 then raise exception 'stale or invalid response';end if;
 if response='confirmed' then
 if share_cv is null then raise exception 'explicit consent required';end if;
 if share_cv and not exists(select 1 from public.candidate_cv_files where id=cv_file and user_id=auth.uid()) then raise exception 'invalid CV';end if;
 insert into public.cv_consents(appointment_id,application_id,organization_id,candidate_id,file_id,decision,expires_at) values(i.id,a.id,a.organization_id,a.candidate_id,case when share_cv then cv_file end,share_cv,case when share_cv then least(i.starts_at+interval '1 day',clock_timestamp()+interval '7 days') end) returning id into c;
 insert into public.cv_consent_audit(consent_id,actor_id,event) values(c,auth.uid(),case when share_cv then 'granted' else 'declined' end);
 end if;
 update public.interview_appointments set status=response,candidate_note=note,revision=revision+1 where id=i.id;
end $$;
create function public.revoke_cv_consent(consent uuid) returns void language plpgsql security definer set search_path='' as $$
declare c public.cv_consents;
begin select * into c from public.cv_consents where id=consent for update;
 if not found or c.candidate_id<>auth.uid() or auth.uid() is null then raise exception 'forbidden';end if;
 if c.revoked_at is not null then return;end if;
 update public.cv_consents set revoked_at=clock_timestamp() where id=consent;
 insert into public.cv_consent_audit(consent_id,actor_id,event) values(consent,auth.uid(),'revoked');end $$;
create function public.authorize_interview_cv(application uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.cv_consents;path text;
begin
 select g.* into c from public.cv_consents g join public.interview_appointments i on i.id=g.appointment_id where g.application_id=application and g.decision and g.revoked_at is null and g.expires_at>clock_timestamp()+interval '1 second' and i.status='confirmed' and public.is_org_member(g.organization_id) order by g.created_at desc limit 1 for update of g;
 if not found then raise exception 'forbidden';end if;
 select object_path into path from public.candidate_cv_files where id=c.file_id and user_id=c.candidate_id;
 if path is null then raise exception 'CV unavailable';end if;
 insert into public.cv_consent_audit(consent_id,actor_id,event) values(c.id,auth.uid(),'access_authorized');
 return jsonb_build_object('path',path,'expires_at',c.expires_at);
end $$;
revoke all on function public.propose_interview(uuid,timestamptz,text,text),public.respond_interview(uuid,integer,text,boolean,uuid,text),public.revoke_cv_consent(uuid),public.authorize_interview_cv(uuid) from public,anon;
grant execute on function public.propose_interview(uuid,timestamptz,text,text),public.respond_interview(uuid,integer,text,boolean,uuid,text),public.revoke_cv_consent(uuid),public.authorize_interview_cv(uuid) to authenticated;
commit;
