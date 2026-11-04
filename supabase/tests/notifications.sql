begin;
insert into auth.users(id,email,email_confirmed_at) values('00000000-0000-4000-8000-000000000081','candidate81@test.test',null),('00000000-0000-4000-8000-000000000082','candidate82@test.test',now());
update auth.users set email_confirmed_at=now() where id='00000000-0000-4000-8000-000000000081';
do $$ begin if (select count(*) from public.notifications where recipient_id='00000000-0000-4000-8000-000000000081')<>1 then raise exception 'verification notification';end if;end $$;
select public.notify_once('00000000-0000-4000-8000-000000000081','account_verified','account','00000000-0000-4000-8000-000000000081','auth:verified');
insert into public.notifications(recipient_id,event,target_kind,target_id,dedupe_key) values('00000000-0000-4000-8000-000000000081','community_reply','community','70000000-0000-4000-8000-000000000081','future-community');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000081',true);
do $$ declare p jsonb;begin
 p:=public.notification_inbox(1);
 if (p->>'total')::integer<>2 or (p->>'unread')::integer<>2 then raise exception 'duplicate notification';end if;
 if exists(select 1 from public.notifications where recipient_id='00000000-0000-4000-8000-000000000082') then raise exception 'owner RLS';end if;
 if exists(select 1 from jsonb_array_elements(p->'items') i where i->>'event'='community_reply' and i->>'target_id' is not null) then raise exception 'unauthorized link';end if;
 begin perform public.notify_once('00000000-0000-4000-8000-000000000081','account_verified','account','00000000-0000-4000-8000-000000000081','bypass');raise exception 'client emitted';exception when insufficient_privilege then null;end;
 begin perform public.run_due_notification_jobs(1);raise exception 'client ran queue';exception when insufficient_privilege then null;end;
 perform public.mark_notification_read((select id from public.notifications where dedupe_key='auth:verified'));
 perform public.mark_notification_read((select id from public.notifications where dedupe_key='auth:verified'));
 if (public.notification_inbox(1)->>'unread')::integer<>1 then raise exception 'read state';end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000082',true);
do $$ begin
 if (public.notification_inbox(1)->>'total')::integer<>0 then raise exception 'cross-user inbox';end if;
 perform public.mark_notification_read((select id from public.notifications limit 1));
 if exists(select 1 from public.notifications) then raise exception 'cross-user RLS';end if;
end $$;
rollback;
