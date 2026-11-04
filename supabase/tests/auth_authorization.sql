begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('00000000-0000-4000-8000-000000000021','admin@example.test',now()),
 ('00000000-0000-4000-8000-000000000022','recruiter@example.test',now());
set local role authenticated;
do $$ begin
 begin perform public.create_organization('unauthenticated'); raise exception 'anonymous allowed'; exception when raise_exception then if sqlerrm <> 'unauthorized' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000021',true);
select public.create_organization('A') as org_a \gset
select public.create_organization('B') as org_b \gset
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000022',true);
select public.request_membership(:'org_a');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000021',true);
select public.decide_membership(:'org_a','00000000-0000-4000-8000-000000000022',true);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000022',true);
do $$ begin
 if (select count(*) from public.organizations)<>1 then raise exception 'tenant isolation failed'; end if;
 begin perform public.decide_membership((select organization_id from public.organization_members limit 1),'00000000-0000-4000-8000-000000000021',true); raise exception 'recruiter escalation'; exception when raise_exception then if sqlerrm <> 'forbidden' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000021',true);
select public.revoke_membership(:'org_a','00000000-0000-4000-8000-000000000022');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000022',true);
do $$ begin if exists(select 1 from public.organizations) then raise exception 'revocation failed'; end if; end $$;
rollback;
