begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('00000000-0000-4000-8000-000000000041','orga@example.test',now()),
 ('00000000-0000-4000-8000-000000000042','hra@example.test',now()),
 ('00000000-0000-4000-8000-000000000043','orgb@example.test',now()),
 ('00000000-0000-4000-8000-000000000044','candidate@example.test',now()),
 ('00000000-0000-4000-8000-000000000045','reviewer@example.test',now());
insert into public.platform_reviewers values('00000000-0000-4000-8000-000000000045');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000041',true);
select public.create_organization('Org A') as org_a \gset
select public.update_organization(:'org_a','Org A','MST-A','Địa chỉ A');
select public.add_branch(:'org_a','Chi nhánh A','Đường A','Hà Nội','Cầu Giấy') as branch_a \gset
select public.save_job(:'org_a',null,'{"title":"Nháp"}') as draft_id \gset
select set_config('test.org_a',:'org_a',true);
select set_config('test.draft',:'draft_id',true);
select set_config('test.branch_a',:'branch_a',true);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000043',true);
select public.create_organization('Org B') as org_b \gset
select public.add_branch(:'org_b','Chi nhánh B','Đường B','HCM','Q1') as branch_b \gset
select set_config('test.branch_b',:'branch_b',true);
do $$ begin
 begin perform public.save_job(current_setting('test.org_a')::uuid,null,'{"title":"Attack"}');raise exception 'cross-tenant create allowed';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
 begin perform public.transition_job(current_setting('test.draft')::uuid,'closed');raise exception 'cross-tenant update allowed';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
 begin perform public.review_organization(current_setting('test.org_a')::uuid,'verified','self-issued');raise exception 'self verification allowed';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000041',true);
do $$ begin
 begin perform public.save_job(current_setting('test.org_a')::uuid,null,jsonb_build_object('title','Bad FK','branch_id',current_setting('test.branch_b')));raise exception 'cross-tenant branch allowed';exception when foreign_key_violation then null;end;
 begin perform public.transition_job(current_setting('test.draft')::uuid,'published');raise exception 'unverified publish allowed';exception when raise_exception then if sqlerrm<>'organization not verified' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000045',true);
select public.review_organization(:'org_a','verified','Kiểm tra tài liệu MST/ĐKKD - fixture');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000041',true);
do $$ begin
 begin perform public.transition_job(current_setting('test.draft')::uuid,'published');raise exception 'incomplete publish allowed';exception when raise_exception then if sqlerrm<>'job incomplete' then raise;end if;end;
end $$;
select public.save_job(:'org_a',:'draft_id',jsonb_build_object('title','Kế toán','branch_id',:'branch_a','industry','Tài chính','salary_min',100,'salary_max',200,'salary_unit','month','salary_basis','gross','work_mode','onsite','description','JD','requirements','Yêu cầu','benefits','Quyền lợi','safety_commitment',true,'skills',jsonb_build_array('Excel','Kế toán','Giao tiếp')));
select public.transition_job(:'draft_id','published');
set local role anon;
do $$ begin if (select count(*) from public.public_jobs())<>1 then raise exception 'published projection missing';end if;end $$;
reset role;
insert into public.organization_members(organization_id,user_id,role) values(:'org_a','00000000-0000-4000-8000-000000000042','recruiter');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000044',true);
select public.set_saved_job(:'draft_id',true);
select public.set_saved_job(:'draft_id',true);
do $$ begin if (select count(*) from public.saved_jobs)<>1 then raise exception 'duplicate save';end if;if exists(select 1 from public.applications) then raise exception 'save created application';end if;end $$;
insert into public.candidate_profiles(user_id,full_name,display_name,district,province,desired_position,work_mode,salary,salary_unit,skills) values(auth.uid(),'Private legal name','Public name','Cầu Giấy','Hà Nội','Kế toán','onsite',100,'month',array['Excel','Kế toán','Giao tiếp']);
select public.apply_to_job(:'draft_id');
select public.apply_to_job(:'draft_id');
do $$ begin
 if (select count(*) from public.applications)<>1 then raise exception 'duplicate apply';end if;
 if exists(select 1 from public.applications where profile_snapshot ? 'full_name' or profile_snapshot ? 'cv_path') then raise exception 'private application snapshot';end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000042',true);
do $$ begin if exists(select 1 from public.saved_jobs) then raise exception 'HR sees private bookmarks';end if;end $$;
select public.transition_job(:'draft_id','paused');
reset role;
delete from public.organization_members where organization_id=:'org_a' and user_id='00000000-0000-4000-8000-000000000042';
set local role authenticated;
do $$ begin
 begin perform public.save_job(current_setting('test.org_a')::uuid,current_setting('test.draft')::uuid,'{"title":"Revoked edit"}');raise exception 'revoked HR edit allowed';exception when raise_exception then if sqlerrm<>'forbidden' then raise;end if;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000041',true);
select public.transition_job(:'draft_id','closed');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000044',true);
select public.set_saved_job(:'draft_id',false);
do $$ begin if exists(select 1 from public.saved_jobs) then raise exception 'unsave failed';end if;end $$;
select set_config('request.jwt.claim.sub','',true);
do $$ begin
 begin perform public.set_saved_job(current_setting('test.draft')::uuid,true);raise exception 'anonymous save allowed';exception when raise_exception then if sqlerrm<>'unauthorized' then raise;end if;end;
end $$;
rollback;
