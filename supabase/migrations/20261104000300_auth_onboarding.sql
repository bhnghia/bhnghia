alter table public.profiles add column persona text check (persona in ('candidate','recruiter'));
create function public.sync_auth_profile() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.profiles(id,display_name) values(new.id,'Thành viên') on conflict(id) do nothing;
 return new;
end $$;
revoke all on function public.sync_auth_profile() from public, anon, authenticated;
create trigger auth_profile_created after insert on auth.users for each row execute function public.sync_auth_profile();
insert into public.profiles(id,display_name) select id,'Thành viên' from auth.users on conflict(id) do nothing;
create function public.set_persona(choice text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null) then raise exception 'unauthorized'; end if;
 if choice not in ('candidate','recruiter') or choice is null then raise exception 'invalid persona'; end if;
 update public.profiles set persona=choice,updated_at=now() where id=auth.uid();
 if choice='candidate' then insert into public.candidate_profiles(user_id) values(auth.uid()) on conflict do nothing; end if;
end $$;
create function public.create_organization(org_name text) returns uuid language plpgsql security definer set search_path='' as $$
declare org uuid;
begin
 if not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null) then raise exception 'unauthorized'; end if;
 if length(trim(org_name)) not between 1 and 200 or org_name is null then raise exception 'invalid name'; end if;
 insert into public.organizations(name) values(trim(org_name)) returning id into org;
 insert into public.organization_members(organization_id,user_id,role) values(org,auth.uid(),'org_admin');
 return org;
end $$;
create table public.organization_join_requests(
 organization_id uuid references public.organizations(id), user_id uuid references public.profiles(id),
 created_at timestamptz not null default now(), primary key(organization_id,user_id)
);
alter table public.organization_join_requests enable row level security;
create policy join_requests_read on public.organization_join_requests for select to authenticated using
 (user_id=auth.uid() or exists(select 1 from public.organization_members m where m.organization_id=organization_join_requests.organization_id and m.user_id=auth.uid() and m.role='org_admin'));
revoke all on public.organization_join_requests from anon,authenticated;
grant select on public.organization_join_requests to authenticated;
create function public.request_membership(org uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null) then raise exception 'unauthorized'; end if;
 insert into public.organization_join_requests(organization_id,user_id) values(org,auth.uid()) on conflict do nothing;
end $$;
create function public.decide_membership(org uuid, member uuid, approve boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.organization_members where organization_id=org and user_id=auth.uid() and role='org_admin' for update;
 if not found then raise exception 'forbidden'; end if;
 delete from public.organization_join_requests where organization_id=org and user_id=member;
 if not found then raise exception 'request missing'; end if;
 if approve then insert into public.organization_members(organization_id,user_id,role) values(org,member,'recruiter') on conflict do nothing; end if;
end $$;
revoke all on function public.set_persona(text),public.create_organization(text),public.request_membership(uuid),public.decide_membership(uuid,uuid,boolean) from public,anon;
grant execute on function public.set_persona(text),public.create_organization(text),public.request_membership(uuid),public.decide_membership(uuid,uuid,boolean) to authenticated;
create function public.revoke_membership(org uuid, member uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.organization_members where organization_id=org and user_id=auth.uid() and role='org_admin' for update;
 if not found then raise exception 'forbidden'; end if;
 delete from public.organization_members where organization_id=org and user_id=member and role='recruiter';
end $$;
revoke all on function public.revoke_membership(uuid,uuid) from public,anon;
grant execute on function public.revoke_membership(uuid,uuid) to authenticated;
