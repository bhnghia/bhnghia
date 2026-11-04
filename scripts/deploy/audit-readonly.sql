\set ON_ERROR_STOP on
begin transaction read only;
-- Run against the explicitly selected staging/production connection; never include its URL in logs.
do $$ begin
 if to_regclass('public.notifications') is null or to_regclass('public.safety_reports') is null then raise exception 'Required migrations missing';end if;
 if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and not c.relrowsecurity) then raise exception 'Public table without RLS: inspect table inventory';end if;
 if not exists(select 1 from storage.buckets where id='candidate-cv' and not public and file_size_limit=5242880 and allowed_mime_types=array['application/pdf']) then raise exception 'CV bucket privacy or limits mismatch';end if;
 if has_table_privilege('authenticated','public.test_attempt_keys','SELECT') or has_table_privilege('anon','public.candidate_cv_files','SELECT') or has_table_privilege('authenticated','public.community_items','SELECT') or has_table_privilege('authenticated','public.safety_reports','SELECT') then raise exception 'Unexpected private table grants';end if;
 if has_function_privilege('authenticated','public.run_due_notification_jobs(integer)','EXECUTE') or has_function_privilege('authenticated','public.finish_due_microtests()','EXECUTE') then raise exception 'Scheduler callable from client';end if;
end $$;
select schemaname,tablename,policyname,roles,cmd from pg_policies where schemaname in ('public','storage') order by schemaname,tablename,policyname;
select id,public,file_size_limit,allowed_mime_types from storage.buckets order by id;
select status,count(*) from public.notification_jobs group by status;
select count(*) as overdue_test_attempts from public.test_attempts where status='issued' and deadline<now();
rollback;
