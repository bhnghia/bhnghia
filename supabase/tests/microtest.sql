begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('00000000-0000-4000-8000-000000000061','hr@example.test',now()),
 ('00000000-0000-4000-8000-000000000062','candidate@example.test',now()),
 ('00000000-0000-4000-8000-000000000063','otherhr@example.test',now()),
 ('00000000-0000-4000-8000-000000000064','candidate2@example.test',now());
insert into public.organizations(id,name,verification_status) values
 ('10000000-0000-4000-8000-000000000061','A','verified'),('10000000-0000-4000-8000-000000000063','B','verified');
insert into public.organization_members(organization_id,user_id,role) values
 ('10000000-0000-4000-8000-000000000061','00000000-0000-4000-8000-000000000061','org_admin'),
 ('10000000-0000-4000-8000-000000000063','00000000-0000-4000-8000-000000000063','org_admin');
insert into public.candidate_profiles(user_id,display_name,district,province,desired_position,work_mode,salary,salary_unit,skills) select id,'Candidate','Q','TP','Job','onsite',100,'month',array['a','b','c'] from auth.users where id in ('00000000-0000-4000-8000-000000000062','00000000-0000-4000-8000-000000000064');
insert into public.jobs(id,organization_id,title) values('20000000-0000-4000-8000-000000000061','10000000-0000-4000-8000-000000000061','Test job');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000061',true);
do $$ begin
 begin perform public.configure_microtest('20000000-0000-4000-8000-000000000061',true,0);raise exception 'enabled without bank';exception when raise_exception then if sqlerrm<>'test bank incomplete' then raise;end if;end;
end $$;
select public.edit_test_question('20000000-0000-4000-8000-000000000061',null,jsonb_build_object('kind','mcq','prompt','Case '||n,'options',jsonb_build_array('A','B'),'correct_index',1,'min_seconds',0,'max_seconds',120)) from generate_series(1,10)n;
select public.edit_test_question('20000000-0000-4000-8000-000000000061',null,'{"kind":"written","prompt":"Viết ngắn","options":[],"min_seconds":0,"max_seconds":120}') as written_source \gset
select public.configure_microtest('20000000-0000-4000-8000-000000000061',true,1);
reset role;
update public.jobs set status='published' where id='20000000-0000-4000-8000-000000000061';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000062',true);
select public.apply_to_job('20000000-0000-4000-8000-000000000061') as application \gset
select public.prepare_microtest(:'application') as attempt \gset
select set_config('test.attempt',:'attempt',true);
select set_config('test.application',:'application',true);
select public.prepare_microtest(:'application');
do $$ declare payload jsonb; begin
 payload:=public.get_test_player(current_setting('test.application')::uuid);
 if payload->'attempt'->>'status'<>'prepared' or (payload->'attempt'->>'total_seconds')::integer<>480 then raise exception 'bad preflight';end if;
 if payload::text like '%correct_index%' or payload::text like '%"score"%' then raise exception 'secret in payload';end if;
 if exists(select 1 from public.test_attempt_questions) or exists(select 1 from public.test_grades) then raise exception 'candidate raw read';end if;
 begin perform * from public.test_attempt_keys;raise exception 'candidate sees key';exception when insufficient_privilege then null;end;
 begin update public.test_attempts set deadline=now()+interval '1 day';raise exception 'client changed timer';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$ begin
 if (select count(*) from public.test_attempts where id=current_setting('test.attempt')::uuid)<>1 then raise exception 'repeat attempt';end if;
 if (select count(distinct source_question_id) from public.test_attempt_questions where attempt_id=current_setting('test.attempt')::uuid and kind='mcq')<>3 then raise exception 'random selection not 3 distinct MCQs';end if;
 if (select count(*) from public.test_attempt_questions where attempt_id=current_setting('test.attempt')::uuid and kind='written')<>1 then raise exception 'written count';end if;
end $$;
select id as q1 from public.test_attempt_questions where attempt_id=:'attempt' and position=1 \gset
select id as qw from public.test_attempt_questions where attempt_id=:'attempt' and kind='written' \gset
select set_config('test.q1',:'q1',true);
select set_config('test.qw',:'qw',true);
-- Mutate source after preparation; snapshot and private key must retain original values.
update public.test_questions set prompt='Changed after snapshot',correct_index=2 where kind='mcq';
do $$ begin
 if exists(select 1 from public.test_attempt_questions where attempt_id=current_setting('test.attempt')::uuid and prompt='Changed after snapshot') then raise exception 'snapshot changed';end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000062',true);
select public.start_microtest(:'attempt');
reset role;
select deadline as original_deadline from public.test_attempts where id=:'attempt' \gset
set local role authenticated;
select public.start_microtest(:'attempt');
select public.store_test_answer(:'attempt',:'q1',1,null);
do $$ declare payload jsonb; begin
 payload:=public.get_test_player(current_setting('test.application')::uuid);
 if payload::text like '%correct_index%' or payload::text like '%"score"%' then raise exception 'issued secret leak';end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000064',true);
do $$ begin
 begin perform public.start_microtest(current_setting('test.attempt')::uuid);raise exception 'other candidate start';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
 begin perform public.get_test_player(current_setting('test.application')::uuid);raise exception 'other candidate read';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
 begin perform public.submit_microtest(current_setting('test.attempt')::uuid);raise exception 'other candidate submit';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000062',true);

do $$ begin
 begin perform public.store_test_answer(current_setting('test.attempt')::uuid,current_setting('test.qw')::uuid,null,'Early');raise exception 'future window allowed';exception when raise_exception then if sqlerrm<>'answer window closed' then raise;end if;end;
 begin perform public.submit_microtest(current_setting('test.attempt')::uuid);raise exception 'early submit allowed';exception when raise_exception then if sqlerrm<>'questions not all open' then raise;end if;end;
end $$;
reset role;
select set_config('test.original_deadline',:'original_deadline',true);
do $$ begin if (select deadline from public.test_attempts where id=current_setting('test.attempt')::uuid)<>current_setting('test.original_deadline')::timestamptz then raise exception 'timer reset';end if;end $$;
-- Deterministic clock boundary simulation in the test harness (no sleeps/client clock).
update public.test_attempt_questions set deadline=clock_timestamp()-interval '1 second' where id=:'q1';
update public.test_attempt_questions set opens_at=clock_timestamp()-interval '1 second' where id=:'qw';
set local role authenticated;
do $$ begin
 begin perform public.store_test_answer(current_setting('test.attempt')::uuid,current_setting('test.q1')::uuid,2,null);raise exception 'late answer allowed';exception when raise_exception then if sqlerrm<>'answer window closed' then raise;end if;end;
 begin perform public.store_test_answer(current_setting('test.attempt')::uuid,current_setting('test.qw')::uuid,null,repeat('x',301));raise exception 'long written allowed';exception when raise_exception then if sqlerrm<>'invalid answer' then raise;end if;end;
end $$;
select public.store_test_answer(:'attempt',:'qw',null,'Câu trả lời');
reset role;
update public.test_attempt_questions set opens_at=clock_timestamp()-interval '1 second' where attempt_id=:'attempt';
set local role authenticated;
select public.submit_microtest(:'attempt');
select public.submit_microtest(:'attempt');
do $$ declare payload jsonb; begin
 payload:=public.get_test_player(current_setting('test.application')::uuid);
 if payload->>'application_status'<>'test_submitted' or payload::text like '%"score"%' then raise exception 'candidate status/leak';end if;
 begin perform public.grade_written_answer(current_setting('test.attempt')::uuid,current_setting('test.qw')::uuid,5);raise exception 'candidate grading allowed';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000063',true);
do $$ begin
 if exists(select 1 from public.test_grades) or exists(select 1 from public.test_answers) then raise exception 'cross-tenant score leak';end if;
 begin perform public.grade_written_answer(current_setting('test.attempt')::uuid,current_setting('test.qw')::uuid,5);raise exception 'other HR grading allowed';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000061',true);
do $$ begin
 if (select score from public.test_grades where attempt_id=current_setting('test.attempt')::uuid)<>1 then raise exception 'MCQ score did not use immutable key';end if;
 begin perform public.grade_written_answer(current_setting('test.attempt')::uuid,current_setting('test.qw')::uuid,6);raise exception 'invalid manual score';exception when check_violation then null;end;
end $$;
reset role;
delete from public.organization_members where organization_id='10000000-0000-4000-8000-000000000061' and user_id='00000000-0000-4000-8000-000000000061';
set local role authenticated;
do $$ begin
 if exists(select 1 from public.test_grades where attempt_id=current_setting('test.attempt')::uuid) then raise exception 'revoked HR score leak';end if;
 begin perform public.grade_written_answer(current_setting('test.attempt')::uuid,current_setting('test.qw')::uuid,4);raise exception 'revoked HR grading';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
end $$;
reset role;
insert into public.organization_members(organization_id,user_id,role) values('10000000-0000-4000-8000-000000000061','00000000-0000-4000-8000-000000000061','org_admin');
set local role authenticated;
select public.grade_written_answer(:'attempt',:'qw',4);
select public.grade_written_answer(:'attempt',:'qw',4);
do $$ begin
 if (select score from public.test_grades where attempt_id=current_setting('test.attempt')::uuid)<>5 then raise exception 'manual total incorrect';end if;
 if (select status from public.applications where id=current_setting('test.application')::uuid)<>'under_review' then raise exception 'grading transition missing';end if;
 if (select count(*) from public.test_audit_logs where attempt_id=current_setting('test.attempt')::uuid and event='submitted')<>1 then raise exception 'duplicate submit audit';end if;
end $$;
select public.transition_job('20000000-0000-4000-8000-000000000061','paused');
select public.configure_microtest('20000000-0000-4000-8000-000000000061',true,0);
reset role;
update public.jobs set status='published' where id='20000000-0000-4000-8000-000000000061';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000064',true);
select public.apply_to_job('20000000-0000-4000-8000-000000000061') as app2 \gset
select public.prepare_microtest(:'app2') as attempt2 \gset
select public.start_microtest(:'attempt2');
reset role;
update public.jobs set status='closed' where id='20000000-0000-4000-8000-000000000061';
update public.test_attempts set deadline=clock_timestamp()-interval '1 second',issued_at=clock_timestamp()-interval '1 hour' where id=:'attempt2';
set local role authenticated;
select public.get_test_player(:'app2');
reset role;
select set_config('test.attempt2',:'attempt2',true);
do $$ begin
 if not exists(select 1 from public.test_attempts where id=current_setting('test.attempt2')::uuid and status='submitted' and auto_submitted and review_ready_at is not null) then raise exception 'timeout not finalized';end if;
 if (select score from public.test_grades where attempt_id=current_setting('test.attempt2')::uuid)<>0 then raise exception 'empty MCQ score';end if;
end $$;
rollback;
