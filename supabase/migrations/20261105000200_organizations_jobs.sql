-- Tenant writes use explicit RPCs. No client grants for badge, membership or job state.
create function public.is_org_member(org uuid, admin_only boolean default false) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.organization_members m join auth.users u on u.id=m.user_id where m.organization_id=org and m.user_id=auth.uid() and u.email_confirmed_at is not null and (not admin_only or m.role='org_admin'))
$$;
revoke all on function public.is_org_member(uuid,boolean) from public,anon;
grant execute on function public.is_org_member(uuid,boolean) to authenticated;
alter table public.organizations add column tax_id text, add column address text, add column logo_path text;
alter table public.organizations add constraint logo_owned check(logo_path is null or (logo_path like id::text||'/%' and logo_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}$'));
create table public.organization_verifications(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),
 decision text not null check(decision in ('verified','rejected','suspended')),reviewed_by uuid not null references public.profiles(id),
 evidence_reference text not null check(length(trim(evidence_reference))>0),reviewed_at timestamptz not null default now()
);
create table public.platform_reviewers(user_id uuid primary key references public.profiles(id));
alter table public.platform_reviewers enable row level security;
alter table public.organization_verifications enable row level security;
create policy verification_org_read on public.organization_verifications for select to authenticated using(public.is_org_member(organization_id,true));
revoke all on public.platform_reviewers,public.organization_verifications from anon,authenticated;
grant select on public.organization_verifications to authenticated;
create table public.branches(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),
 name text not null check(length(trim(name)) between 1 and 200),address text not null check(length(trim(address)) between 1 and 500),
 province text not null check(length(trim(province)) between 1 and 100),district text not null check(length(trim(district)) between 1 and 100),
 region_code text,created_at timestamptz not null default now(),unique(organization_id,id)
);
alter table public.branches enable row level security;
create policy branches_read_member on public.branches for select to authenticated using(public.is_org_member(organization_id));
revoke all on public.branches from anon,authenticated;
grant select on public.branches to authenticated;
create function public.update_organization(org uuid, company_name text, company_tax_id text, company_address text, company_logo text default null) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.is_org_member(org,true) then raise exception 'forbidden';end if;
 if length(trim(company_name)) not between 1 and 200 or length(trim(company_tax_id)) not between 1 and 30 or length(trim(company_address)) not between 1 and 500 or company_name is null or company_tax_id is null or company_address is null then raise exception 'invalid organization';end if;
 update public.organizations set verification_status=case when name is distinct from trim(company_name) or tax_id is distinct from trim(company_tax_id) or address is distinct from trim(company_address) then 'pending' else verification_status end,
 name=trim(company_name),tax_id=trim(company_tax_id),address=trim(company_address),logo_path=company_logo,updated_at=now() where id=org;
end $$;
create function public.review_organization(org uuid, decision text, evidence text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.platform_reviewers where user_id=auth.uid()) then raise exception 'forbidden';end if;
 perform 1 from public.organizations where id=org and tax_id is not null and address is not null for update;
 if not found then raise exception 'organization incomplete';end if;
 insert into public.organization_verifications(organization_id,decision,reviewed_by,evidence_reference) values(org,decision,auth.uid(),evidence);
 update public.organizations set verification_status=decision,updated_at=now() where id=org;
end $$;
create function public.add_branch(org uuid, branch_name text, branch_address text, province text, district text, region text default null) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not public.is_org_member(org,true) then raise exception 'forbidden';end if;
 insert into public.branches(organization_id,name,address,province,district,region_code) values(org,branch_name,branch_address,province,district,region) returning id into result;
 return result;
end $$;
create function public.list_org_members(org uuid) returns table(user_id uuid,role text,display_name text) language sql stable security definer set search_path='' as $$
 select m.user_id,m.role,p.display_name from public.organization_members m join public.profiles p on p.id=m.user_id where m.organization_id=org and public.is_org_member(org,true)
$$;

alter table public.jobs add column branch_id uuid, add column industry text not null default '',
 add column salary_min numeric,add column salary_max numeric,add column salary_unit text check(salary_unit in ('hour','shift','month')),
 add column salary_basis text check(salary_basis in ('gross','net')),add column currency text not null default 'VND' check(currency='VND'),
 add column work_mode text check(work_mode in ('onsite','remote','hybrid')),
 add column description text not null default '',add column requirements text not null default '',add column benefits text not null default '',
 add column safety_commitment boolean not null default false,
 add column test_written_count integer not null default 0 check(test_written_count between 0 and 3),
 add column published_at timestamptz,
 add constraint job_branch_tenant foreign key(organization_id,branch_id) references public.branches(organization_id,id),
 add constraint salary_range check(salary_min>=0 and salary_max>=salary_min and salary_max<=1000000000000);
create table public.job_skills(job_id uuid not null references public.jobs(id) on delete cascade,position integer not null check(position between 1 and 3),name text not null check(length(trim(name)) between 1 and 60),primary key(job_id,position),unique(job_id,name));
alter table public.job_skills enable row level security;
create policy job_skills_member_read on public.job_skills for select to authenticated using(exists(select 1 from public.jobs j where j.id=job_id and public.is_org_member(j.organization_id)));
revoke all on public.job_skills from anon,authenticated;grant select on public.job_skills to authenticated;
create index jobs_public_filter_idx on public.jobs(industry,work_mode,salary_unit,salary_max) where status='published';
create index branches_area_idx on public.branches(province,district);
create index job_skills_name_idx on public.job_skills(lower(name));
create unique index job_skills_unique_lower_idx on public.job_skills(job_id,lower(name));

create function public.save_job(org uuid, job uuid, payload jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid; skill text; ordinal integer:=0;
begin
 if not public.is_org_member(org) then raise exception 'forbidden';end if;
 if job is not null then
  perform 1 from public.jobs where id=job and organization_id=org and status in ('draft','pending_review','paused') for update;
  if not found then raise exception 'job missing or not editable';end if;
 end if;
 if length(trim(payload->>'title')) not between 1 and 200 or payload->>'title' is null then raise exception 'title required';end if;
 if length(payload->>'industry')>100 or length(payload->>'description')>20000 or length(payload->>'requirements')>10000 or length(payload->>'benefits')>10000 then raise exception 'text too long';end if;
 if jsonb_array_length(payload->'skills')>3 then raise exception 'max 3 skills';end if;
 if job is null then insert into public.jobs(organization_id,title) values(org,trim(payload->>'title')) returning id into result;else result:=job;end if;
 update public.jobs set title=trim(payload->>'title'),branch_id=nullif(payload->>'branch_id','')::uuid,industry=coalesce(payload->>'industry',''),
 salary_min=nullif(payload->>'salary_min','')::numeric,salary_max=nullif(payload->>'salary_max','')::numeric,salary_unit=nullif(payload->>'salary_unit',''),salary_basis=nullif(payload->>'salary_basis',''),
 work_mode=nullif(payload->>'work_mode',''),description=coalesce(payload->>'description',''),requirements=coalesce(payload->>'requirements',''),benefits=coalesce(payload->>'benefits',''),
 safety_commitment=coalesce((payload->>'safety_commitment')::boolean,false),test_enabled=coalesce((payload->>'test_enabled')::boolean,false),test_written_count=coalesce((payload->>'test_written_count')::integer,0),updated_at=now() where id=result;
 delete from public.job_skills where job_id=result;
 for skill in select jsonb_array_elements_text(payload->'skills') loop ordinal:=ordinal+1;insert into public.job_skills values(result,ordinal,trim(skill));end loop;
 return result;
end $$;
create function public.transition_job(job uuid, target text) returns void language plpgsql security definer set search_path='' as $$
declare j public.jobs;
begin
 select * into j from public.jobs where id=job for update;
 if not found or not public.is_org_member(j.organization_id) then raise exception 'forbidden';end if;
 if target='published' then
  perform 1 from public.organizations o where o.id=j.organization_id and o.verification_status='verified' and exists(select 1 from public.organization_verifications v where v.organization_id=o.id and v.decision='verified') for share;
  if not found then raise exception 'organization not verified';end if;
  if j.status not in ('draft','pending_review','paused') or j.branch_id is null or length(trim(j.industry))=0 or j.salary_min is null or j.salary_max is null or j.salary_unit is null or j.salary_basis is null or j.work_mode is null or length(trim(j.description))=0 or length(trim(j.requirements))=0 or length(trim(j.benefits))=0 or not j.safety_commitment or (select count(*) from public.job_skills where job_id=job)<>3 then raise exception 'job incomplete';end if;
  -- Micro-test publication remains gated until the bank/attempt module exists.
  if j.test_enabled then raise exception 'test bank not ready';end if;
 elsif target='paused' then if j.status<>'published' then raise exception 'invalid transition';end if;
 elsif target='closed' then if j.status not in ('draft','pending_review','paused','published') then raise exception 'invalid transition';end if;
 else raise exception 'invalid transition';end if;
 update public.jobs set status=target,published_at=case when target='published' then now() else published_at end,updated_at=now() where id=job;
end $$;

-- Public projection excludes members, tax documents and any applicant/test data.
create function public.public_jobs() returns setof jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',j.id,'organization_id',o.id,'company_name',o.name,'logo_path',o.logo_path,'verified',true,'title',j.title,'industry',j.industry,'salary_min',j.salary_min,'salary_max',j.salary_max,'salary_unit',j.salary_unit,'salary_basis',j.salary_basis,'work_mode',j.work_mode,'province',b.province,'district',b.district,'branch_address',b.address,'description',j.description,'requirements',j.requirements,'benefits',j.benefits,'safety_commitment',j.safety_commitment,'test_enabled',j.test_enabled,'test_written_count',j.test_written_count,'skills',(select jsonb_agg(s.name order by s.position) from public.job_skills s where s.job_id=j.id))
 from public.jobs j join public.organizations o on o.id=j.organization_id join public.branches b on b.id=j.branch_id and b.organization_id=j.organization_id
 where j.status='published' and o.verification_status='verified' and exists(select 1 from public.organization_verifications v where v.organization_id=o.id and v.decision='verified')
$$;
create table public.saved_jobs(candidate_id uuid not null references public.profiles(id) on delete cascade,job_id uuid not null references public.jobs(id) on delete cascade,created_at timestamptz not null default now(),primary key(candidate_id,job_id));
alter table public.saved_jobs enable row level security;
create policy saved_jobs_owner on public.saved_jobs for select to authenticated using(candidate_id=auth.uid());
revoke all on public.saved_jobs from anon,authenticated;grant select on public.saved_jobs to authenticated;
create function public.set_saved_job(job uuid, saved boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null) then raise exception 'unauthorized';end if;
 if saved then
  perform 1 from public.jobs j join public.organizations o on o.id=j.organization_id where j.id=job and j.status='published' and o.verification_status='verified' for share of j,o;
  if not found then raise exception 'job unavailable';end if;
  insert into public.saved_jobs(candidate_id,job_id) values(auth.uid(),job) on conflict do nothing;
 else delete from public.saved_jobs where candidate_id=auth.uid() and job_id=job;end if;
end $$;
-- Versioned minimum-wage configuration. No legal amounts are seeded.
create table public.minimum_wage_rules(id uuid primary key default gen_random_uuid(),region_code text not null,valid_from date not null,valid_until date,unit text not null check(unit in ('hour','shift','month')),basis text not null check(basis in ('gross','net')),amount numeric not null check(amount>0),currency text not null default 'VND' check(currency='VND'),source_reference text not null check(length(trim(source_reference))>0),check(valid_until is null or valid_until>valid_from),unique(region_code,valid_from,unit,basis));
alter table public.minimum_wage_rules enable row level security;
create policy wage_rules_read on public.minimum_wage_rules for select to authenticated using(true);
revoke all on public.minimum_wage_rules from anon,authenticated;grant select on public.minimum_wage_rules to authenticated;
-- Rules are curated via controlled database administration until admin settings exists.
revoke all on function public.update_organization(uuid,text,text,text,text), public.review_organization(uuid,text,text),public.add_branch(uuid,text,text,text,text,text),public.list_org_members(uuid),public.save_job(uuid,uuid,jsonb),public.transition_job(uuid,text),public.set_saved_job(uuid,boolean) from public,anon;
grant execute on function public.update_organization(uuid,text,text,text,text), public.review_organization(uuid,text,text),public.add_branch(uuid,text,text,text,text,text),public.list_org_members(uuid),public.save_job(uuid,uuid,jsonb),public.transition_job(uuid,text),public.set_saved_job(uuid,boolean) to authenticated;
revoke all on function public.public_jobs() from public;
grant execute on function public.public_jobs() to anon,authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('organization-logos','organization-logos',true,2097152,array['image/png','image/jpeg','image/webp']);
create policy org_logo_owner_read on storage.objects for select to authenticated using(bucket_id='organization-logos' and public.is_org_member(((storage.foldername(name))[1])::uuid,true));
create policy org_logo_insert on storage.objects for insert to authenticated with check(bucket_id='organization-logos' and public.is_org_member(((storage.foldername(name))[1])::uuid,true));
create policy org_logo_delete on storage.objects for delete to authenticated using(bucket_id='organization-logos' and public.is_org_member(((storage.foldername(name))[1])::uuid,true));
create function public.set_organization_logo(org uuid, path text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.is_org_member(org,true) then raise exception 'forbidden';end if;
 update public.organizations set logo_path=path where id=org;
end $$;
revoke all on function public.set_organization_logo(uuid,text) from public,anon;
grant execute on function public.set_organization_logo(uuid,text) to authenticated;
create function public.apply_to_job(job uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare j public.jobs;p public.candidate_profiles;result uuid;
begin
 if not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null) then raise exception 'unauthorized';end if;
 select * into j from public.jobs where id=job for share;
 if not found or j.status<>'published' or j.test_enabled then raise exception 'job unavailable';end if;
 perform 1 from public.organizations o where o.id=j.organization_id and o.verification_status='verified' for share;
 if not found then raise exception 'organization unavailable';end if;
 select * into p from public.candidate_profiles where user_id=auth.uid();
 if not found or p.display_name is null or p.skills is null or p.district is null or p.province is null or p.desired_position is null or p.work_mode is null or p.salary is null or p.salary_unit is null then raise exception 'profile incomplete';end if;
 insert into public.applications(organization_id,job_id,candidate_id,status,profile_snapshot)
 values(j.organization_id,j.id,auth.uid(),'submitted',jsonb_build_object('display_name',p.display_name,'school',p.school,'study_year',p.study_year,'district',p.district,'province',p.province,'desired_position',p.desired_position,'work_mode',p.work_mode,'salary',p.salary,'salary_unit',p.salary_unit,'skills',p.skills,'bio',p.bio,'avatar_visible',p.avatar_visible)) on conflict(job_id,candidate_id) do nothing;
 select id into result from public.applications where job_id=job and candidate_id=auth.uid();return result;
end $$;
revoke all on function public.apply_to_job(uuid) from public,anon;
grant execute on function public.apply_to_job(uuid) to authenticated;
