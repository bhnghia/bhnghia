begin;
create table public.community_moderators(user_id uuid primary key references public.profiles(id));
create table public.community_items(id uuid primary key default gen_random_uuid(),author_id uuid not null references public.profiles(id),parent_id uuid references public.community_items(id),title text not null default '',body text not null check(length(trim(body)) between 1 and 5000),anonymous boolean not null default true,official_org uuid references public.organizations(id),company_tag text not null default '' check(length(company_tag)<=200),position_tag text not null default '' check(length(position_tag)<=150),status text not null default 'pending' check(status in ('pending','visible','hidden','removed')),created_at timestamptz not null default now(),check(length(title)<=200));
create index community_parent_time on public.community_items(parent_id,created_at,id);
create index community_tags on public.community_items(company_tag,position_tag) where status='visible';
create table public.community_votes(item_id uuid references public.community_items(id),user_id uuid references public.profiles(id),value integer not null check(value in (-1,1)),primary key(item_id,user_id));
create table public.community_saves(item_id uuid references public.community_items(id),user_id uuid references public.profiles(id),primary key(item_id,user_id));
create table public.community_reports(id uuid primary key default gen_random_uuid(),item_id uuid references public.community_items(id),reporter_id uuid references public.profiles(id),reason text not null check(length(trim(reason)) between 1 and 1000),created_at timestamptz not null default now(),unique(item_id,reporter_id));
create table public.community_audit(id uuid primary key default gen_random_uuid(),item_id uuid references public.community_items(id),actor_id uuid references public.profiles(id),old_status text,new_status text,reason text not null,created_at timestamptz not null default now());
alter table public.community_moderators enable row level security;
alter table public.community_items enable row level security;
alter table public.community_votes enable row level security;
alter table public.community_saves enable row level security;
alter table public.community_reports enable row level security;
alter table public.community_audit enable row level security;
revoke all on public.community_moderators,public.community_items,public.community_votes,public.community_saves,public.community_reports,public.community_audit from public,anon,authenticated;
create function public.community_is_mod() returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.community_moderators where user_id=auth.uid()) $$;
create function public.community_readable(item uuid) returns boolean language sql stable security definer set search_path='' as $$ with recursive chain as (select id,parent_id,status from public.community_items where id=item union all select p.id,p.parent_id,p.status from public.community_items p join chain c on c.parent_id=p.id) select exists(select 1 from chain) and not exists(select 1 from chain where status<>'visible') $$;
create function public.community_create(parent uuid,heading text,content text,hide_name boolean,company text,position_name text,official uuid default null) returns uuid language plpgsql security definer set search_path='' as $$ declare result uuid;begin
 perform 1 from public.profiles p join auth.users u on u.id=p.id where p.id=auth.uid() and u.email_confirmed_at is not null for update of p;
 if not found then raise exception 'unauthorized';end if;
 if parent is not null and not public.community_readable(parent) then raise exception 'parent unavailable';end if;
 if parent is null and (heading is null or length(trim(heading))=0) then raise exception 'title required';end if;
 if (select count(*) from public.community_items where author_id=auth.uid() and created_at>clock_timestamp()-interval '1 hour')>=10 then raise exception 'rate limit';end if;
 if official is not null and (hide_name or not public.is_org_member(official) or not exists(select 1 from public.organizations where id=official and verification_status='verified')) then raise exception 'official forbidden';end if;
 insert into public.community_items(author_id,parent_id,title,body,anonymous,official_org,company_tag,position_tag) values(auth.uid(),parent,coalesce(heading,''),content,hide_name,official,coalesce(company,''),coalesce(position_name,'')) returning id into result;return result;
end $$;
create function public.community_feed(parent uuid default null,query text default '',company text default '',position_name text default '',mode text default 'feed',page_number integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$ declare result jsonb;begin
 if page_number not between 1 and 100000 or mode not in ('feed','mine','saved','moderation') then raise exception 'invalid query';end if;
 if mode='moderation' and not public.community_is_mod() then raise exception 'forbidden';end if;
 with filtered as (select i.* from public.community_items i where
 (mode='moderation' and (i.status<>'visible' or exists(select 1 from public.community_reports r where r.item_id=i.id)) or mode='mine' and i.author_id=auth.uid() or mode='saved' and public.community_readable(i.id) and exists(select 1 from public.community_saves s where s.item_id=i.id and s.user_id=auth.uid()) or mode='feed' and public.community_readable(i.id) and (parent is null and i.parent_id is null or i.id=parent or i.parent_id=parent))
 and (query='' or concat(i.title,' ',i.body) ilike '%'||left(query,200)||'%') and (company='' or i.company_tag ilike '%'||left(company,200)||'%') and (position_name='' or i.position_tag ilike '%'||left(position_name,150)||'%')),
 projected as (select i.id,i.parent_id,i.title,i.body,i.status,i.company_tag,i.position_tag,i.created_at,case when i.anonymous then 'Ẩn danh' else p.display_name end display_name,
 case when o.verification_status='verified' and exists(select 1 from public.organization_members m where m.organization_id=o.id and m.user_id=i.author_id) then o.name else null end official_name,
 (select coalesce(sum(value),0) from public.community_votes where item_id=i.id) votes,
 (select value from public.community_votes where item_id=i.id and user_id=auth.uid()) my_vote,
 exists(select 1 from public.community_saves where item_id=i.id and user_id=auth.uid()) saved,
 case when mode='moderation' then (select count(*) from public.community_reports where item_id=i.id) else null end reports
 from filtered i join public.profiles p on p.id=i.author_id left join public.organizations o on o.id=i.official_org order by i.created_at desc,i.id limit 20 offset (page_number-1)*20)
 select jsonb_build_object('total',(select count(*) from filtered),'moderator',public.community_is_mod(),'items',coalesce((select jsonb_agg(to_jsonb(p)) from projected p),'[]'::jsonb)) into result;return result;end $$;
create function public.community_interact(item uuid,operation text,value integer default null,reason text default '') returns void language plpgsql security definer set search_path='' as $$ begin
 if not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null) then raise exception 'unauthorized';end if;
 if not public.community_readable(item) then raise exception 'unavailable';end if;
 if operation='vote' then if value=0 then delete from public.community_votes where item_id=item and user_id=auth.uid();else insert into public.community_votes values(item,auth.uid(),value) on conflict(item_id,user_id) do update set value=excluded.value;end if;
 elsif operation='save' then insert into public.community_saves values(item,auth.uid()) on conflict do nothing;
 elsif operation='unsave' then delete from public.community_saves where item_id=item and user_id=auth.uid();
 elsif operation='report' then
 perform 1 from public.profiles where id=auth.uid() for update;
 if (select count(*) from public.community_reports where reporter_id=auth.uid() and created_at>clock_timestamp()-interval '1 hour')>=10 then raise exception 'rate limit';end if;
 insert into public.community_reports(item_id,reporter_id,reason) values(item,auth.uid(),reason) on conflict(item_id,reporter_id) do nothing;
 else raise exception 'invalid operation';end if;end $$;
create function public.community_moderate(item uuid,target text,reason text) returns void language plpgsql security definer set search_path='' as $$ declare old_state text;parent_owner uuid;begin
 if not public.community_is_mod() or target not in ('visible','hidden','removed') or target is null or length(trim(reason))<1 or reason is null then raise exception 'forbidden';end if;
 select status into old_state from public.community_items where id=item for update;if not found then raise exception 'missing';end if;
 if old_state=target then return;end if;
 update public.community_items set status=target where id=item;
 insert into public.community_audit(item_id,actor_id,old_status,new_status,reason) values(item,auth.uid(),old_state,target,reason);
 if target='visible' then select p.author_id into parent_owner from public.community_items c join public.community_items p on p.id=c.parent_id where c.id=item;
 if parent_owner is not null then perform public.notify_once(parent_owner,'community_reply','community',item,'community-reply:'||item);end if;end if;
end $$;
revoke all on function public.community_is_mod(),public.community_readable(uuid) from public,anon,authenticated;
revoke all on function public.community_create(uuid,text,text,boolean,text,text,uuid),public.community_feed(uuid,text,text,text,text,integer),public.community_interact(uuid,text,integer,text),public.community_moderate(uuid,text,text) from public,anon;
grant execute on function public.community_create(uuid,text,text,boolean,text,text,uuid),public.community_feed(uuid,text,text,text,text,integer),public.community_interact(uuid,text,integer,text),public.community_moderate(uuid,text,text) to authenticated;
create or replace function public.notification_target_allowed(n public.notifications) returns boolean language plpgsql stable security definer set search_path='' as $$ begin
 if n.recipient_id<>auth.uid() then return false;end if;
 if n.target_kind='community' then return public.community_readable(n.target_id);end if;
 if n.target_kind='account' then return n.target_id=auth.uid();end if;
 if n.target_kind='invitation' then return exists(select 1 from public.sourcing_invitations i where i.id=n.target_id and i.candidate_id=auth.uid());end if;
 if n.target_kind='application' then return exists(select 1 from public.applications a where a.id=n.target_id and (a.candidate_id=auth.uid() or public.is_org_member(a.organization_id)));end if;
 if n.target_kind='interview' then return exists(select 1 from public.interview_appointments i join public.applications a on a.id=i.application_id where i.id=n.target_id and (a.candidate_id=auth.uid() or public.is_org_member(i.organization_id)));end if;
 return false;end $$;
commit;
