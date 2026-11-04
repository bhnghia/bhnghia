alter table public.candidate_profiles
 add column full_name text,
 add column display_name text,
 add column school text not null default '',
 add column study_year text not null default '',
 add column district text,
 add column province text,
 add column desired_position text,
 add column work_mode text check (work_mode in ('onsite','remote','hybrid')),
 add column salary numeric check(salary >= 0 and salary <= 1000000000000),
 add column salary_unit text check(salary_unit in ('hour','shift','month')),
 add column skills text[];
alter table public.candidate_profiles add constraint candidate_bio_words check (bio is null or length(bio)<=3000 and cardinality(regexp_split_to_array(trim(bio),'\s+'))<=30);
alter table public.candidate_profiles add constraint candidate_skills_count check (skills is null or cardinality(skills) between 3 and 5);
create function public.validate_profile() returns trigger language plpgsql set search_path='' as $$
begin
 if new.skills is not null and (exists(select 1 from unnest(new.skills) s where s is null or length(trim(s)) not between 1 and 60) or (select count(distinct lower(trim(s))) from unnest(new.skills) s)<>cardinality(new.skills)) then raise exception 'invalid skills'; end if;
 if new.display_name is not null and length(trim(new.display_name)) not between 1 and 100 then raise exception 'invalid display name'; end if;
 if new.full_name is not null and length(trim(new.full_name)) not between 1 and 100 then raise exception 'invalid full name'; end if;
 if length(new.school)>200 or length(new.study_year)>50 or (new.district is not null and length(trim(new.district)) not between 1 and 100) or (new.province is not null and length(trim(new.province)) not between 1 and 100) or (new.desired_position is not null and length(trim(new.desired_position)) not between 1 and 150) then raise exception 'invalid fields'; end if;
 if new.discoverable and (new.display_name is null or new.skills is null or new.district is null or new.province is null or new.desired_position is null or new.work_mode is null or new.salary is null or new.salary_unit is null) then raise exception 'incomplete public card'; end if;
 return new;
end $$;
create trigger profile_validate before insert or update on public.candidate_profiles for each row execute function public.validate_profile();
create policy candidate_insert_self on public.candidate_profiles for insert to authenticated with check(user_id=auth.uid());
create policy candidate_update_self on public.candidate_profiles for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
grant insert,update on public.candidate_profiles to authenticated;
create function public.read_candidate_card(candidate uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('display_name',display_name,'school',school,'study_year',study_year,'district',district,'province',province,'desired_position',desired_position,'work_mode',work_mode,'salary',salary,'salary_unit',salary_unit,'skills',skills,'bio',bio,'avatar_visible',avatar_visible)
 from public.candidate_profiles p where p.user_id=candidate and p.discoverable
 and exists(select 1 from public.organization_members m where m.user_id=auth.uid())
$$;
revoke all on function public.read_candidate_card(uuid) from public,anon;
grant execute on function public.read_candidate_card(uuid) to authenticated;
create table public.candidate_cv_files(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id),
 object_path text not null unique, created_at timestamptz not null default now(),
 check(object_path like user_id::text || '/%')
);
alter table public.candidate_cv_files enable row level security;
create policy cv_owner_read on public.candidate_cv_files for select to authenticated using(user_id=auth.uid());
create policy cv_owner_insert on public.candidate_cv_files for insert to authenticated with check(user_id=auth.uid());
revoke all on public.candidate_cv_files from anon,authenticated;
grant select,insert on public.candidate_cv_files to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('candidate-cv','candidate-cv',false,5242880,array['application/pdf']);
create policy candidate_cv_storage_read on storage.objects for select to authenticated using(bucket_id='candidate-cv' and (storage.foldername(name))[1]=auth.uid()::text);
create policy candidate_cv_storage_upload on storage.objects for insert to authenticated with check(bucket_id='candidate-cv' and (storage.foldername(name))[1]=auth.uid()::text);
create policy candidate_cv_storage_delete on storage.objects for delete to authenticated using(bucket_id='candidate-cv' and (storage.foldername(name))[1]=auth.uid()::text);
