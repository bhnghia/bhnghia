-- Phần nền fail-closed. Chưa có policy ghi công khai hoặc bootstrap membership.
-- Không triển khai production cho đến khi có migrations còn lại và kiểm thử RLS.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (length(trim(display_name)) between 1 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.candidate_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  discoverable boolean not null default false,
  avatar_visible boolean not null default false,
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 200),
  verification_status text not null default 'pending'
    check (verification_status in ('pending', 'verified', 'rejected', 'suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('recruiter', 'org_admin')),
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);
create index organization_members_user_idx on public.organization_members (user_id, organization_id);

alter table public.profiles enable row level security;
alter table public.candidate_profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;

-- Mặc định chỉ được xem thông tin chính mình và các org mình thuộc về.
-- Không cho client sửa quyền, membership hoặc verification_status.
create policy profiles_select_self on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy candidate_profiles_select_self on public.candidate_profiles for select to authenticated
  using (user_id = (select auth.uid()));
create policy organization_members_select_self on public.organization_members for select to authenticated
  using (user_id = (select auth.uid()));
create policy organizations_select_member on public.organizations for select to authenticated
  using (exists (select 1 from public.organization_members m
    where m.organization_id = organizations.id and m.user_id = (select auth.uid())));

revoke all on public.profiles, public.candidate_profiles, public.organizations, public.organization_members from anon, authenticated;
grant select on public.profiles, public.candidate_profiles, public.organizations, public.organization_members to authenticated;
