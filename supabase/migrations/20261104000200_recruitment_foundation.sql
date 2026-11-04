-- Chỉ dựng cấu trúc đọc tối thiểu; các thao tác ghi nghiệp vụ chưa được cấp quyền.
create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  title text not null check (length(trim(title)) between 1 and 200),
  status text not null default 'draft' check (status in ('draft','pending_review','published','paused','closed','expired')),
  test_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id)
);
create index jobs_org_status_idx on public.jobs (organization_id, status);

create table public.applications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  job_id uuid not null,
  candidate_id uuid not null references public.candidate_profiles(user_id),
  status text not null check (status in ('submitted','test_pending','test_submitted','under_review')),
  profile_snapshot jsonb not null,
  created_at timestamptz not null default now(),
  unique (job_id, candidate_id),
  unique (organization_id, id),
  foreign key (organization_id, job_id) references public.jobs(organization_id, id)
);
create index applications_candidate_idx on public.applications (candidate_id, created_at desc);
create index applications_org_job_idx on public.applications (organization_id, job_id);

create table public.test_attempts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  application_id uuid not null,
  status text not null check (status in ('issued','submitted','expired')),
  issued_at timestamptz not null default now(),
  deadline timestamptz not null,
  unique (organization_id, id),
  foreign key (organization_id, application_id) references public.applications (organization_id, id),
  check (deadline > issued_at)
);
create index test_attempts_application_idx on public.test_attempts (organization_id, application_id);

create table public.test_grades (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  attempt_id uuid not null,
  score numeric not null check (score >= 0),
  graded_at timestamptz not null default now(),
  foreign key (organization_id, attempt_id) references public.test_attempts (organization_id, id)
);
create index test_grades_attempt_idx on public.test_grades (organization_id, attempt_id);

alter table public.jobs enable row level security;
alter table public.applications enable row level security;
alter table public.test_attempts enable row level security;
alter table public.test_grades enable row level security;

create policy jobs_read_member on public.jobs for select to authenticated using
  (exists (select 1 from public.organization_members m where m.organization_id = jobs.organization_id and m.user_id = (select auth.uid())));
create policy applications_read_related on public.applications for select to authenticated using
  (candidate_id = (select auth.uid()) or exists (select 1 from public.organization_members m where m.organization_id = applications.organization_id and m.user_id = (select auth.uid())));
create policy attempts_read_org on public.test_attempts for select to authenticated using
  (exists (select 1 from public.organization_members m where m.organization_id = test_attempts.organization_id and m.user_id = (select auth.uid())));
create policy grades_read_org on public.test_grades for select to authenticated using
  (exists (select 1 from public.organization_members m where m.organization_id = test_grades.organization_id and m.user_id = (select auth.uid())));

revoke all on public.jobs, public.applications, public.test_attempts, public.test_grades from anon, authenticated;
grant select on public.jobs, public.applications, public.test_attempts, public.test_grades to authenticated;
