begin;
-- Ambiguous partner/group assignments must never increase the review threshold.
create or replace function public.safety_count(org uuid,candidate uuid,as_of timestamptz default now()) returns integer language sql stable security definer set search_path='' as $$
 with eligible as (select coalesce(reporting_org,reporter_id) partner,independence_key from public.safety_reports where target_org is not distinct from org and target_candidate is not distinct from candidate and status='qualified' and independence_key is not null and occurred_at>=as_of-interval '12 months' and occurred_at<=as_of),
 consistent as (select partner,min(independence_key) group_key from eligible group by partner having count(distinct independence_key)=1)
 select count(distinct group_key)::integer from consistent
$$;
-- Keep the older single-card RPC aligned with verified membership checks.
create or replace function public.read_candidate_card(candidate uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('display_name',display_name,'school',school,'study_year',study_year,'district',district,'province',province,'desired_position',desired_position,'work_mode',work_mode,'salary',salary,'salary_unit',salary_unit,'skills',skills,'bio',bio,'avatar_visible',avatar_visible)
 from public.candidate_profiles p where p.user_id=candidate and p.discoverable and exists(select 1 from public.organization_members m where m.user_id=auth.uid() and public.is_org_member(m.organization_id))
$$;
create index if not exists community_author_time_idx on public.community_items(author_id,created_at);
create index if not exists community_reports_item_idx on public.community_reports(item_id);
create index if not exists safety_responses_report_time_idx on public.safety_responses(report_id,created_at);
create index if not exists safety_audit_report_time_idx on public.safety_audit(report_id,created_at);
commit;
