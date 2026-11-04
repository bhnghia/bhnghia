begin;
create table public.safety_moderators(user_id uuid primary key references public.profiles(id));
create table public.safety_reports(id uuid primary key default gen_random_uuid(),reporter_id uuid not null references public.profiles(id),reporting_org uuid references public.organizations(id),target_org uuid references public.organizations(id),target_candidate uuid references public.profiles(id),job_id uuid not null references public.jobs(id),category text not null check(category in ('fees','documents','fake_location','misleading','other')),summary text not null check(length(trim(summary)) between 1 and 2000),evidence text not null check(length(trim(evidence)) between 1 and 10000),occurred_at timestamptz not null,status text not null default 'pending' check(status in ('pending','qualified','dismissed','appealed','cancelled')),independence_key text,decision text,created_at timestamptz not null default now(),check((target_org is null)<>(target_candidate is null)),unique(reporter_id,job_id,category));
create table public.safety_responses(id uuid primary key default gen_random_uuid(),report_id uuid not null references public.safety_reports(id),author_id uuid not null references public.profiles(id),kind text not null check(kind in ('response','appeal')),body text not null check(length(trim(body)) between 1 and 5000),created_at timestamptz not null default now());
create table public.safety_audit(id uuid primary key default gen_random_uuid(),report_id uuid not null references public.safety_reports(id),actor_id uuid references public.profiles(id),event text not null,reason text not null,created_at timestamptz not null default now());
create index safety_target_org on public.safety_reports(target_org,occurred_at) where status='qualified';
create index safety_target_candidate on public.safety_reports(target_candidate,occurred_at) where status='qualified';
alter table public.safety_moderators enable row level security;
alter table public.safety_reports enable row level security;
alter table public.safety_responses enable row level security;
alter table public.safety_audit enable row level security;
revoke all on public.safety_moderators,public.safety_reports,public.safety_responses,public.safety_audit from public,anon,authenticated;
create function public.safety_is_mod() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.safety_moderators where user_id=auth.uid())$$;
create function public.safety_subject(r public.safety_reports) returns boolean language sql stable security definer set search_path='' as $$select coalesce(r.target_candidate=auth.uid(),false) or coalesce(public.is_org_member(r.target_org),false)$$;
create function public.safety_allowed(r public.safety_reports) returns boolean language sql stable security definer set search_path='' as $$select public.safety_is_mod() or r.reporter_id=auth.uid() or public.safety_subject(r)$$;
create function public.safety_count(org uuid,candidate uuid,as_of timestamptz default now()) returns integer language sql stable security definer set search_path='' as $$select least(count(distinct independence_key),count(distinct coalesce(reporting_org,reporter_id)))::integer from public.safety_reports where target_org is not distinct from org and target_candidate is not distinct from candidate and status='qualified' and independence_key is not null and occurred_at>=as_of-interval '12 months' and occurred_at<=as_of$$;
create function public.safety_file(job uuid,candidate uuid,category_name text,description text,proof text,incident_time timestamptz) returns uuid language plpgsql security definer set search_path='' as $$declare j public.jobs;result uuid;begin
 perform 1 from public.profiles p join auth.users u on u.id=p.id where p.id=auth.uid() and u.email_confirmed_at is not null for update of p;if not found then raise exception 'unauthorized';end if;
 select * into j from public.jobs where id=job;
 if not found or incident_time is null or not isfinite(incident_time) or incident_time>clock_timestamp() then raise exception 'invalid incident';end if;
 if candidate is null then
 if not exists(select 1 from public.candidate_profiles where user_id=auth.uid()) or public.is_org_member(j.organization_id) then raise exception 'forbidden';end if;
 else
 if not public.is_org_member(j.organization_id) or not exists(select 1 from public.applications where job_id=job and candidate_id=candidate) or candidate=auth.uid() then raise exception 'forbidden';end if;
 end if;
 select id into result from public.safety_reports where reporter_id=auth.uid() and job_id=job and category=category_name;if found then return result;end if;
 if (select count(*) from public.safety_reports where reporter_id=auth.uid() and created_at>clock_timestamp()-interval '1 day')>=5 then raise exception 'rate limit';end if;
 insert into public.safety_reports(reporter_id,reporting_org,target_org,target_candidate,job_id,category,summary,evidence,occurred_at) values(auth.uid(),case when candidate is not null then j.organization_id end,case when candidate is null then j.organization_id end,candidate,job,category_name,description,proof,incident_time) returning id into result;
 insert into public.safety_audit(report_id,actor_id,event,reason) values(result,auth.uid(),'filed','Báo cáo riêng tư');return result;end $$;
create function public.safety_list(page_number integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$begin
 if auth.uid() is null or page_number not between 1 and 100000 then raise exception 'forbidden';end if;
 return jsonb_build_object('moderator',public.safety_is_mod(),'total',(select count(*) from public.safety_reports r where public.safety_allowed(r)),'items',coalesce((select jsonb_agg(to_jsonb(x)) from (select r.id,r.category,r.status,r.created_at from public.safety_reports r where public.safety_allowed(r) order by r.created_at desc,r.id limit 20 offset (page_number-1)*20)x),'[]'::jsonb));end $$;
create function public.safety_detail(report uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$declare r public.safety_reports;begin
 select * into r from public.safety_reports where id=report;if not found or not public.safety_allowed(r) then raise exception 'forbidden';end if;
 return jsonb_build_object('id',r.id,'status',r.status,'category',r.category,'summary',r.summary,'evidence',case when public.safety_is_mod() or r.reporter_id=auth.uid() then r.evidence else null end,'decision',r.decision,'occurred_at',r.occurred_at,'moderator',public.safety_is_mod(),'subject',coalesce(public.safety_subject(r),false),'partners',public.safety_count(r.target_org,r.target_candidate),'responses',coalesce((select jsonb_agg(jsonb_build_object('kind',kind,'body',body,'created_at',created_at) order by created_at) from public.safety_responses where report_id=report),'[]'::jsonb),'history',coalesce((select jsonb_agg(jsonb_build_object('event',event,'reason',reason,'created_at',created_at) order by created_at) from public.safety_audit where report_id=report),'[]'::jsonb));end $$;
create function public.safety_respond(report uuid,response_kind text,content text) returns void language plpgsql security definer set search_path='' as $$declare r public.safety_reports;begin
 select * into r from public.safety_reports where id=report for update;
 if not found or not coalesce(public.safety_subject(r),false) then raise exception 'forbidden';end if;
 if response_kind='appeal' then if r.status<>'qualified' then raise exception 'appeal unavailable';end if;update public.safety_reports set status='appealed' where id=report;end if;
 if (select count(*) from public.safety_responses where report_id=report and author_id=auth.uid() and created_at>clock_timestamp()-interval '1 day')>=5 then raise exception 'rate limit';end if;
 insert into public.safety_responses(report_id,author_id,kind,body) values(report,auth.uid(),response_kind,content);
 insert into public.safety_audit(report_id,actor_id,event,reason) values(report,auth.uid(),response_kind,'Đã tiếp nhận, chờ xem xét');end $$;
alter table public.jobs add column safety_hold boolean not null default false;
create function public.guard_safety_hold() returns trigger language plpgsql set search_path='' as $$begin if new.safety_hold and new.status='published' then raise exception 'job on safety hold';end if;return new;end $$;
create trigger safety_hold before update on public.jobs for each row execute function public.guard_safety_hold();
create function public.safety_decide(report uuid,target text,reason text,independent_group text default null,hold_job boolean default false) returns void language plpgsql security definer set search_path='' as $$declare r public.safety_reports;begin
 select * into r from public.safety_reports where id=report for update;
 if not found or not public.safety_is_mod() or r.reporter_id=auth.uid() or coalesce(public.safety_subject(r),false) or (r.reporting_org is not null and public.is_org_member(r.reporting_org)) then raise exception 'forbidden';end if;
 if target not in ('qualified','dismissed','cancelled') or target is null or reason is null or length(trim(reason)) not between 1 and 2000 then raise exception 'invalid decision';end if;
 if target='qualified' and (independent_group is null or length(trim(independent_group)) not between 1 and 200) then raise exception 'independence review required';end if;
 update public.safety_reports set status=target,decision=reason,independence_key=case when target='qualified' then independent_group end where id=report;
 if hold_job and r.target_org is not null then update public.jobs set status=case when status='published' then 'paused' else status end,safety_hold=true where id=r.job_id;end if;
 insert into public.safety_audit(report_id,actor_id,event,reason) values(report,auth.uid(),target,reason||case when hold_job then ' [Tạm giữ Job]' else '' end);
 perform public.notify_once(r.reporter_id,'report_result','report',report,'safety:'||report||':'||(select count(*) from public.safety_audit where report_id=report));
end $$;
revoke all on function public.safety_is_mod(),public.safety_subject(public.safety_reports),public.safety_allowed(public.safety_reports),public.safety_count(uuid,uuid,timestamptz),public.guard_safety_hold() from public,anon,authenticated;
revoke all on function public.safety_file(uuid,uuid,text,text,text,timestamptz),public.safety_list(integer),public.safety_detail(uuid),public.safety_respond(uuid,text,text),public.safety_decide(uuid,text,text,text,boolean) from public,anon;
grant execute on function public.safety_file(uuid,uuid,text,text,text,timestamptz),public.safety_list(integer),public.safety_detail(uuid),public.safety_respond(uuid,text,text),public.safety_decide(uuid,text,text,text,boolean) to authenticated;
alter function public.notification_target_allowed(public.notifications) rename to notification_target_allowed_before_safety;
create function public.notification_target_allowed(n public.notifications) returns boolean language plpgsql stable security definer set search_path='' as $$begin
 if n.recipient_id is distinct from auth.uid() then return false;end if;
 if n.target_kind='report' then return exists(select 1 from public.safety_reports r where r.id=n.target_id and public.safety_allowed(r));end if;
 return public.notification_target_allowed_before_safety(n);end $$;
revoke all on function public.notification_target_allowed(public.notifications) from public,anon,authenticated;
commit;
