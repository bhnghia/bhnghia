begin;
create table public.notifications(id uuid primary key default gen_random_uuid(),recipient_id uuid not null references public.profiles(id),event text not null check(event in ('account_verified','application_invitation','microtest_completed','interview_invited','interview_changed','cv_consent','interview_reminder','report_result','community_reply')),target_kind text not null check(target_kind in ('account','invitation','application','interview','report','community')),target_id uuid not null,dedupe_key text not null,created_at timestamptz not null default now(),read_at timestamptz,unique(recipient_id,dedupe_key));
create index notifications_inbox_idx on public.notifications(recipient_id,created_at desc,id desc);
create table public.notification_jobs(id uuid primary key default gen_random_uuid(),recipient_id uuid not null references public.profiles(id),event text not null,target_kind text not null,target_id uuid not null,dedupe_key text not null unique,run_at timestamptz not null,attempts integer not null default 0,status text not null default 'pending' check(status in ('pending','delivered','cancelled','failed')),last_error text,created_at timestamptz not null default now());
create index notification_jobs_due_idx on public.notification_jobs(run_at,id) where status='pending';
alter table public.notifications enable row level security;
alter table public.notification_jobs enable row level security;
create policy notification_owner on public.notifications for select to authenticated using(recipient_id=auth.uid());
revoke all on public.notifications,public.notification_jobs from public,anon,authenticated;
grant select on public.notifications to authenticated;
create function public.notify_once(recipient uuid,kind text,target text,target_uuid uuid,key text) returns void language plpgsql security definer set search_path='' as $$ begin
 insert into public.notifications(recipient_id,event,target_kind,target_id,dedupe_key) values(recipient,kind,target,target_uuid,key) on conflict(recipient_id,dedupe_key) do nothing;
end $$;
revoke all on function public.notify_once(uuid,text,text,uuid,text) from public,anon,authenticated;
create function public.notification_target_allowed(n public.notifications) returns boolean language plpgsql stable security definer set search_path='' as $$ begin
 if n.recipient_id<>auth.uid() then return false;end if;
 if n.target_kind='account' then return n.target_id=auth.uid();end if;
 if n.target_kind='invitation' then return exists(select 1 from public.sourcing_invitations i where i.id=n.target_id and i.candidate_id=auth.uid());end if;
 if n.target_kind='application' then return exists(select 1 from public.applications a where a.id=n.target_id and (a.candidate_id=auth.uid() or public.is_org_member(a.organization_id)));end if;
 if n.target_kind='interview' then return exists(select 1 from public.interview_appointments i join public.applications a on a.id=i.application_id where i.id=n.target_id and (a.candidate_id=auth.uid() or public.is_org_member(i.organization_id)));end if;
 return false; -- report/community adapters must add their own authorization before a link is exposed.
end $$;
revoke all on function public.notification_target_allowed(public.notifications) from public,anon,authenticated;
create function public.notification_inbox(page_number integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$ begin
 if auth.uid() is null or page_number not between 1 and 100000 then raise exception 'forbidden';end if;
 return jsonb_build_object('total',(select count(*) from public.notifications where recipient_id=auth.uid()),'unread',(select count(*) from public.notifications where recipient_id=auth.uid() and read_at is null),'items',coalesce((select jsonb_agg(to_jsonb(x)) from (select n.id,n.event,n.target_kind,n.created_at,n.read_at,case when public.notification_target_allowed(n) then n.target_id else null end target_id from public.notifications n where n.recipient_id=auth.uid() order by n.created_at desc,n.id desc limit 20 offset (page_number-1)*20)x),'[]'::jsonb));end $$;
create function public.mark_notification_read(notification uuid) returns void language plpgsql security definer set search_path='' as $$ begin
 update public.notifications set read_at=coalesce(read_at,clock_timestamp()) where id=notification and recipient_id=auth.uid();
end $$;
revoke all on function public.notification_inbox(integer),public.mark_notification_read(uuid) from public,anon;
grant execute on function public.notification_inbox(integer),public.mark_notification_read(uuid) to authenticated;
create function public.emit_auth_notification() returns trigger language plpgsql security definer set search_path='' as $$ begin
 if old.email_confirmed_at is null and new.email_confirmed_at is not null then perform public.notify_once(new.id,'account_verified','account',new.id,'auth:verified');end if;return new;end $$;
create trigger notify_auth_verified after update of email_confirmed_at on auth.users for each row execute function public.emit_auth_notification();
create function public.emit_invitation_notification() returns trigger language plpgsql security definer set search_path='' as $$ begin perform public.notify_once(new.candidate_id,'application_invitation','invitation',new.id,'invite:'||new.id);return new;end $$;
create trigger notify_invitation after insert on public.sourcing_invitations for each row execute function public.emit_invitation_notification();
create function public.emit_application_notification() returns trigger language plpgsql security definer set search_path='' as $$ begin
 if old.status is distinct from new.status and new.status='interview_invited' then perform public.notify_once(new.candidate_id,'interview_invited','application',new.id,'interview-invited:'||new.id);end if;return new;end $$;
create trigger notify_application after update of status on public.applications for each row execute function public.emit_application_notification();
create function public.emit_test_notification() returns trigger language plpgsql security definer set search_path='' as $$ declare candidate uuid;begin
 if old.status is distinct from new.status and new.status='submitted' then select candidate_id into candidate from public.applications where id=new.application_id;perform public.notify_once(candidate,'microtest_completed','application',new.application_id,'test-completed:'||new.id);end if;return new;end $$;
create trigger notify_test after update of status on public.test_attempts for each row execute function public.emit_test_notification();
create function public.emit_interview_notification() returns trigger language plpgsql security definer set search_path='' as $$ declare candidate uuid;begin
 select candidate_id into candidate from public.applications where id=new.application_id;
 if tg_op='INSERT' or old.revision is distinct from new.revision then
  perform public.notify_once(candidate,'interview_changed','interview',new.id,'interview:'||new.id||':'||new.revision);
 end if;
 if new.status='confirmed' then
  insert into public.notification_jobs(recipient_id,event,target_kind,target_id,dedupe_key,run_at) values(candidate,'interview_reminder','interview',new.id,'reminder:'||new.id||':'||new.revision,greatest(clock_timestamp(),new.starts_at-interval '1 day')) on conflict(dedupe_key) do nothing;
 elsif tg_op='UPDATE' and old.status='confirmed' then update public.notification_jobs set status='cancelled' where target_id=new.id and event='interview_reminder' and status='pending';end if;
 return new;end $$;
create trigger notify_interview_insert after insert on public.interview_appointments for each row execute function public.emit_interview_notification();
create trigger notify_interview_update after update of status,revision on public.interview_appointments for each row execute function public.emit_interview_notification();
create function public.emit_consent_notification() returns trigger language plpgsql security definer set search_path='' as $$ begin
 if tg_op='INSERT' then perform public.notify_once(new.candidate_id,'cv_consent','interview',new.appointment_id,'consent:'||new.id);
 elsif old.revoked_at is null and new.revoked_at is not null then perform public.notify_once(new.candidate_id,'cv_consent','interview',new.appointment_id,'consent-revoked:'||new.id);end if;return new;end $$;
create trigger notify_consent_insert after insert on public.cv_consents for each row execute function public.emit_consent_notification();
create trigger notify_consent_update after update of revoked_at on public.cv_consents for each row execute function public.emit_consent_notification();
create function public.run_due_notification_jobs(batch_size integer default 100) returns integer language plpgsql security definer set search_path='' as $$ declare task record;processed integer:=0;valid_target boolean;begin
 if batch_size not between 1 and 500 then raise exception 'invalid batch';end if;
 for task in select * from public.notification_jobs where status='pending' and run_at<=clock_timestamp() order by run_at,id limit batch_size for update skip locked loop
  begin
   valid_target:=task.event='interview_reminder' and exists(select 1 from public.interview_appointments i join public.applications a on a.id=i.application_id where i.id=task.target_id and a.candidate_id=task.recipient_id and i.status='confirmed' and i.starts_at>clock_timestamp());
   if valid_target then perform public.notify_once(task.recipient_id,task.event,task.target_kind,task.target_id,task.dedupe_key);end if;
   update public.notification_jobs set status=case when valid_target then 'delivered' else 'cancelled' end,attempts=attempts+1 where id=task.id;
  exception when others then update public.notification_jobs set attempts=attempts+1,status=case when attempts>=4 then 'failed' else 'pending' end,run_at=clock_timestamp()+make_interval(secs=>power(2,least(attempts+1,8))::integer*60),last_error=sqlerrm where id=task.id;end;
  processed:=processed+1;
 end loop;return processed;end $$;
revoke all on function public.run_due_notification_jobs(integer) from public,anon,authenticated;
commit;
