begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('00000000-0000-4000-8000-000000000051','hr@example.test',now()),
 ('00000000-0000-4000-8000-000000000052','candidate@example.test',now()),
 ('00000000-0000-4000-8000-000000000053','outsider@example.test',now());
insert into public.organizations(id,name,verification_status) values('10000000-0000-4000-8000-000000000051','Org','verified');
insert into public.organization_members values('10000000-0000-4000-8000-000000000051','00000000-0000-4000-8000-000000000051','recruiter',now());
insert into public.candidate_profiles(user_id,display_name,district,province,desired_position,work_mode,salary,salary_unit,skills) values('00000000-0000-4000-8000-000000000052','Candidate','Q1','HCM','Work','onsite',100,'month',array['a','b','c']);
insert into public.jobs(id,organization_id,title,status,test_enabled) values
 ('20000000-0000-4000-8000-000000000051','10000000-0000-4000-8000-000000000051','No test','published',false),
 ('20000000-0000-4000-8000-000000000052','10000000-0000-4000-8000-000000000051','Test','published',false);
insert into public.test_banks(id,organization_id,job_id) values('60000000-0000-4000-8000-000000000052','10000000-0000-4000-8000-000000000051','20000000-0000-4000-8000-000000000052');
insert into public.test_questions(organization_id,bank_id,kind,prompt,options,correct_index,min_seconds,max_seconds) select '10000000-0000-4000-8000-000000000051','60000000-0000-4000-8000-000000000052','mcq','Question '||n,'["a","b"]',1,0,30 from generate_series(1,10)n;
update public.jobs set test_enabled=true where id='20000000-0000-4000-8000-000000000052';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000052',true);
select public.apply_to_job('20000000-0000-4000-8000-000000000051') as app \gset
select public.apply_to_job('20000000-0000-4000-8000-000000000052') as test_app \gset
select set_config('test.app',:'app',true);
select set_config('test.test_app',:'test_app',true);
do $$ begin
 if (select status from public.applications where id=current_setting('test.test_app')::uuid)<>'test_pending' then raise exception 'test bypass';end if;
 begin perform public.review_application(current_setting('test.app')::uuid,'submitted','under_review');raise exception 'candidate transitioned';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
 begin update public.applications set status='rejected';raise exception 'direct write allowed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000051',true);
do $$ begin
 begin perform public.review_application(current_setting('test.app')::uuid,'submitted','interview_invited');raise exception 'jump allowed';exception when raise_exception then if sqlerrm<>'invalid transition' then raise;end if;end;
end $$;
select public.review_application(:'app','submitted','under_review');
select public.review_application(:'app','submitted','under_review');
do $$ begin
 begin perform public.review_application(current_setting('test.app')::uuid,'submitted','rejected');raise exception 'stale decision allowed';exception when raise_exception then if sqlerrm<>'stale state' then raise;end if;end;
end $$;
select public.review_application(:'app','under_review','interview_invited','Mời phỏng vấn');
select public.transition_job('20000000-0000-4000-8000-000000000052','closed');
reset role;
insert into public.test_attempts(id,organization_id,application_id,status,deadline) values('30000000-0000-4000-8000-000000000052','10000000-0000-4000-8000-000000000051',:'test_app','submitted',now()+interval '1 hour');
select set_config('request.jwt.claim.sub','',true);
select public.application_test_event('30000000-0000-4000-8000-000000000052','submitted');
do $$ begin
 begin perform public.application_test_event('30000000-0000-4000-8000-000000000052','graded');raise exception 'ungraded advanced';exception when raise_exception then if sqlerrm<>'grading incomplete' then raise;end if;end;
end $$;
update public.test_attempts set review_ready_at=now() where id='30000000-0000-4000-8000-000000000052';
select public.application_test_event('30000000-0000-4000-8000-000000000052','graded');
select public.application_test_event('30000000-0000-4000-8000-000000000052','graded');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000051',true);
select public.review_application(:'test_app','under_review','rejected','Không phù hợp vị trí');
do $$ begin
 begin perform public.application_test_event('30000000-0000-4000-8000-000000000052','graded');raise exception 'client test hook';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000053',true);
do $$ begin
 if exists(select 1 from public.applications) or exists(select 1 from public.application_audit_logs) then raise exception 'tenant leak';end if;
 begin perform public.review_application(current_setting('test.app')::uuid,'interview_invited','rejected');raise exception 'outsider transitioned';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
 begin perform public.apply_to_job('20000000-0000-4000-8000-000000000052');raise exception 'closed job accepts new apply';exception when raise_exception then if sqlerrm<>'job unavailable' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000052',true);
select public.apply_to_job('20000000-0000-4000-8000-000000000052');
do $$ begin
 if (select count(*) from public.applications)<>2 then raise exception 'duplicate applications';end if;
 if (select count(*) from public.application_audit_logs)<>7 then raise exception 'audit missing or duplicated';end if;
end $$;
reset role;
-- Terminal states cannot be reopened even by a trusted writer using ordinary UPDATE.
do $$ begin
 begin update public.applications set status='under_review' where id=current_setting('test.app')::uuid;raise exception 'terminal reopened';exception when raise_exception then if sqlerrm<>'invalid transition' then raise;end if;end;
end $$;
rollback;
