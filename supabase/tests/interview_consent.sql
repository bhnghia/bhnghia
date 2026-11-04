begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('00000000-0000-4000-8000-000000000071','hr71@test.test',now()),
 ('00000000-0000-4000-8000-000000000072','candidate72@test.test',now()),
 ('00000000-0000-4000-8000-000000000073','hr73@test.test',now());
insert into public.organizations(id,name) values('10000000-0000-4000-8000-000000000071','A'),('10000000-0000-4000-8000-000000000073','B');
insert into public.organization_members(organization_id,user_id,role) values('10000000-0000-4000-8000-000000000071','00000000-0000-4000-8000-000000000071','org_admin'),('10000000-0000-4000-8000-000000000073','00000000-0000-4000-8000-000000000073','org_admin');
insert into public.candidate_profiles(user_id) values('00000000-0000-4000-8000-000000000072');
insert into public.jobs(id,organization_id,title) values('20000000-0000-4000-8000-000000000071','10000000-0000-4000-8000-000000000071','Job');
insert into public.applications(id,organization_id,job_id,candidate_id,status,profile_snapshot) values('30000000-0000-4000-8000-000000000071','10000000-0000-4000-8000-000000000071','20000000-0000-4000-8000-000000000071','00000000-0000-4000-8000-000000000072','submitted','{}');
insert into public.candidate_cv_files(id,user_id,object_path) values('40000000-0000-4000-8000-000000000071','00000000-0000-4000-8000-000000000072','00000000-0000-4000-8000-000000000072/cv.pdf');
update public.applications set status='under_review';
update public.applications set status='interview_invited';
select set_config('test.app','30000000-0000-4000-8000-000000000071',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000071',true);
select set_config('test.interview',public.propose_interview(current_setting('test.app')::uuid,now()+interval '2 days','Asia/Ho_Chi_Minh','Văn phòng')::text,true);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000072',true);
do $$ begin
 begin perform public.respond_interview(current_setting('test.interview')::uuid,1,'confirmed');raise exception 'implicit consent';exception when raise_exception then if sqlerrm<>'explicit consent required' then raise;end if;end;
 perform public.respond_interview(current_setting('test.interview')::uuid,1,'reschedule_requested',null,null,'Ngày khác');
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000071',true);
select public.propose_interview(current_setting('test.app')::uuid,now()+interval '3 days','Asia/Ho_Chi_Minh','Văn phòng mới');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000072',true);
select public.respond_interview(current_setting('test.interview')::uuid,3,'confirmed',false);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000071',true);
do $$ begin
 begin perform public.authorize_interview_cv(current_setting('test.app')::uuid);raise exception 'no consent bypass';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
end $$;
-- A separate proposal after a completed interview exercises affirmative consent.
reset role;
update public.interview_appointments set status='completed' where id=current_setting('test.interview')::uuid;
set local role authenticated;
select set_config('test.interview',public.propose_interview(current_setting('test.app')::uuid,now()+interval '4 days','Asia/Ho_Chi_Minh','Vòng 2')::text,true);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000072',true);
select public.respond_interview(current_setting('test.interview')::uuid,1,'confirmed',true,'40000000-0000-4000-8000-000000000071');
select set_config('test.consent',(select id::text from public.cv_consents where decision),true);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000071',true);
select public.authorize_interview_cv(current_setting('test.app')::uuid);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000073',true);
do $$ begin
 if exists(select 1 from public.cv_consents) or exists(select 1 from public.interview_appointments) then raise exception 'tenant read leak';end if;
 begin perform public.authorize_interview_cv(current_setting('test.app')::uuid);raise exception 'tenant CV leak';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
end $$;
reset role;
update public.cv_consents set expires_at=now()-interval '1 second' where decision;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000071',true);
do $$ begin
 begin perform public.authorize_interview_cv(current_setting('test.app')::uuid);raise exception 'expired CV';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
end $$;
reset role;
update public.cv_consents set expires_at=now()+interval '1 day' where decision;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000072',true);
select public.revoke_cv_consent(current_setting('test.consent')::uuid);
select public.revoke_cv_consent(current_setting('test.consent')::uuid);
do $$ begin if (select count(*) from public.cv_consent_audit where event='revoked')<>1 then raise exception 'duplicate revocation';end if;end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000071',true);
do $$ begin
 begin perform public.authorize_interview_cv(current_setting('test.app')::uuid);raise exception 'revoked CV';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
end $$;
rollback;
