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

update public.candidate_profiles set discoverable=true where user_id='00000000-0000-4000-8000-000000000062';
update public.jobs set status='published' where id='20000000-0000-4000-8000-000000000061';
update public.sourcing_limits set daily_per_org=1;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000061',true);
do $$ declare payload jsonb;i uuid;begin
 payload:=public.source_candidates('10000000-0000-4000-8000-000000000061','public');
 if (payload->>'total')::integer<>1 or payload::text like '%full_name%' or payload::text like '%cv%' or payload::text like '%score%' then raise exception 'privacy projection';end if;
 if (public.source_candidates('10000000-0000-4000-8000-000000000061','public','{"skill":"missing"}')->>'total')::integer<>0 then raise exception 'filter';end if;
 if jsonb_array_length(public.source_candidates('10000000-0000-4000-8000-000000000061','public','{}',2)->'items')<>0 then raise exception 'pagination';end if;
 i:=public.send_sourcing_invitation('10000000-0000-4000-8000-000000000061','20000000-0000-4000-8000-000000000061','00000000-0000-4000-8000-000000000062','apply');
 if i<>public.send_sourcing_invitation('10000000-0000-4000-8000-000000000061','20000000-0000-4000-8000-000000000061','00000000-0000-4000-8000-000000000062','apply') then raise exception 'duplicate invite';end if;
 begin perform public.send_sourcing_invitation('10000000-0000-4000-8000-000000000061','20000000-0000-4000-8000-000000000061','00000000-0000-4000-8000-000000000064','apply');raise exception 'private profile invited';exception when raise_exception then if sqlerrm<>'candidate unavailable' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000063',true);
do $$ begin
 begin perform public.recruiter_dashboard('10000000-0000-4000-8000-000000000061');raise exception 'cross dashboard';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
 begin perform public.source_candidates('10000000-0000-4000-8000-000000000061','public');raise exception 'cross source';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
 if exists(select 1 from public.sourcing_invitations) then raise exception 'cross invite read';end if;
end $$;
reset role;
update public.candidate_profiles set discoverable=true where user_id='00000000-0000-4000-8000-000000000064';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000061',true);
do $$ begin
 begin perform public.send_sourcing_invitation('10000000-0000-4000-8000-000000000061','20000000-0000-4000-8000-000000000061','00000000-0000-4000-8000-000000000064','apply');raise exception 'quota bypass';exception when raise_exception then if sqlerrm<>'invitation quota exceeded' then raise;end if;end;
end $$;
reset role;
delete from public.organization_members where user_id='00000000-0000-4000-8000-000000000061';
set local role authenticated;
do $$ begin
 begin perform public.source_candidates('10000000-0000-4000-8000-000000000061','public');raise exception 'revoked source';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000062',true);
do $$ begin if (select count(*) from public.sourcing_invitations)<>1 then raise exception 'recipient inbox';end if;end $$;
rollback;
