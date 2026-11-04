begin;
insert into auth.users(id,email,email_confirmed_at) values('00000000-0000-4000-8000-000000000031','profile@example.test',now()),('00000000-0000-4000-8000-000000000032','other@example.test',now());
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000031',true);
insert into public.candidate_profiles(user_id,full_name,display_name,skills) values(auth.uid(),'Private','Public',array['A','B','C']);
do $$ begin
 if exists(select 1 from public.candidate_profiles where discoverable or avatar_visible) then raise exception 'unsafe defaults'; end if;
 begin update public.candidate_profiles set skills=array['A'];raise exception 'invalid skills allowed';exception when check_violation then null;end;
end $$;
insert into public.candidate_cv_files(user_id,object_path) values(auth.uid(),auth.uid()::text||'/cv.pdf');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000032',true);
do $$ begin
 if exists(select 1 from public.candidate_profiles) or exists(select 1 from public.candidate_cv_files) then raise exception 'owner leak'; end if;
 if public.read_candidate_card('00000000-0000-4000-8000-000000000031') is not null then raise exception 'hidden profile leaked';end if;
 update public.candidate_profiles set display_name='Attack' where user_id='00000000-0000-4000-8000-000000000031';
 if found then raise exception 'cross-owner update';end if;
 begin insert into public.candidate_profiles(user_id) values('00000000-0000-4000-8000-000000000031');raise exception 'cross-owner insert';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000031',true);
update public.candidate_profiles set district='Q1',province='HCM',desired_position='Kế toán',work_mode='onsite',salary=100,salary_unit='hour',discoverable=true where user_id=auth.uid();
insert into storage.objects(bucket_id,name) values('candidate-cv',auth.uid()::text||'/cv.pdf');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000032',true);
select public.create_organization('HR');
do $$ declare card jsonb; begin
 card:=public.read_candidate_card('00000000-0000-4000-8000-000000000031');
 if card is null or card ? 'full_name' or card ? 'cv_path' or card ? 'score' then raise exception 'unsafe projection';end if;
 if exists(select 1 from storage.objects where bucket_id='candidate-cv') then raise exception 'CV storage leak';end if;
 begin insert into storage.objects(bucket_id,name) values('candidate-cv','00000000-0000-4000-8000-000000000031/attack.pdf');raise exception 'foreign CV upload allowed';exception when insufficient_privilege then null;end;
end $$;
rollback;
