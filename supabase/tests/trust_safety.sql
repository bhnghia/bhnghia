begin;
insert into auth.users(id,email,email_confirmed_at) select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'safety'||n||'@test.test',now() from generate_series(101,105)n;
insert into public.candidate_profiles(user_id) select id from auth.users where email like 'safety%';
insert into public.organizations(id,name) values('10000000-0000-4000-8000-000000000101','Test');
insert into public.organization_members values('10000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000104','org_admin',now());
insert into public.safety_moderators values('00000000-0000-4000-8000-000000000105');
insert into public.jobs(id,organization_id,title) values('20000000-0000-4000-8000-000000000101','10000000-0000-4000-8000-000000000101','Job');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',true);
select set_config('safety.report',public.safety_file('20000000-0000-4000-8000-000000000101',null,'fees','Summary','Private proof',now())::text,true);
do $$ begin
 if public.safety_file('20000000-0000-4000-8000-000000000101',null,'fees','Summary','Private proof',now())<>current_setting('safety.report')::uuid then raise exception 'duplicate report';end if;
 begin perform public.safety_decide(current_setting('safety.report')::uuid,'qualified','Fake','group');raise exception 'moderation bypass';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000102',true);
do $$ begin
 begin perform public.safety_detail(current_setting('safety.report')::uuid);raise exception 'unrelated access';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000105',true);
select public.safety_decide(current_setting('safety.report')::uuid,'qualified','Evidence reviewed','partner101',true);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000104',true);
do $$ begin if public.safety_detail(current_setting('safety.report')::uuid)->>'evidence' is not null then raise exception 'evidence disclosed';end if;end $$;
select public.safety_respond(current_setting('safety.report')::uuid,'appeal','Please review');
reset role;
do $$ begin if public.safety_count('10000000-0000-4000-8000-000000000101',null)<>0 then raise exception 'appeal counted';end if;end $$;
update public.safety_reports set status='qualified';
insert into public.safety_reports(reporter_id,target_org,job_id,category,summary,evidence,occurred_at,status,independence_key)
select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'10000000-0000-4000-8000-000000000101','20000000-0000-4000-8000-000000000101','fees','Summary','Proof',now()-interval '12 months','qualified','partner'||n from generate_series(102,103)n;
do $$ begin if public.safety_count('10000000-0000-4000-8000-000000000101',null)<>3 then raise exception '12 month boundary';end if;end $$;
update public.safety_reports set occurred_at=now()-interval '12 months'-interval '1 second' where reporter_id='00000000-0000-4000-8000-000000000103';
do $$ begin if public.safety_count('10000000-0000-4000-8000-000000000101',null)<>2 then raise exception 'rolling window';end if;end $$;
update public.safety_reports set independence_key='partner101';
do $$ begin if public.safety_count('10000000-0000-4000-8000-000000000101',null)<>1 then raise exception 'collusion grouping';end if;end $$;
update public.safety_reports set status='cancelled';
do $$ begin if public.safety_count('10000000-0000-4000-8000-000000000101',null)<>0 then raise exception 'cancelled counted';end if;end $$;
-- QA regression: one partner assigned several groups must not manufacture a third independent partner.
update public.safety_reports set status='qualified',occurred_at=now(),independence_key='shared';
insert into public.safety_reports(reporter_id,target_org,job_id,category,summary,evidence,occurred_at,status,independence_key)
select '00000000-0000-4000-8000-000000000101','10000000-0000-4000-8000-000000000101','20000000-0000-4000-8000-000000000101',category,'Summary','Proof',now(),'qualified',category from unnest(array['documents','fake_location'])category;
do $$ begin
 if (select least(count(distinct independence_key),count(distinct reporter_id)) from public.safety_reports)<>3 then raise exception 'fixture does not reproduce old overcount';end if;
 if public.safety_count('10000000-0000-4000-8000-000000000101',null)<>1 then raise exception 'ambiguous partner falsely qualified';end if;
end $$;
rollback;
