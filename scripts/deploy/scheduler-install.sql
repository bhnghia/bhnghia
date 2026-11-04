-- MUTATING TEMPLATE: staging first; production requires explicit approval.
-- Requires pg_cron already enabled; do not activate paid services automatically.
begin;
do $$ begin if not exists(select 1 from pg_extension where extname='pg_cron') then raise exception 'Review/enable pg_cron first';end if;end $$;
select cron.schedule('vett-notifications','* * * * *','select public.run_due_notification_jobs(100);');
select cron.schedule('vett-microtest-timeout','* * * * *','select public.finish_due_microtests();');
commit;
