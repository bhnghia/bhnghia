begin;
create table public.test_banks(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,job_id uuid not null unique,
 version integer not null default 1,foreign key(organization_id,job_id) references public.jobs(organization_id,id),unique(organization_id,id)
);
create table public.test_questions(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,bank_id uuid not null,
 kind text not null check(kind in ('mcq','written')),prompt text not null check(length(trim(prompt)) between 1 and 2000),
 options jsonb not null default '[]',correct_index integer,min_seconds integer not null check(min_seconds>=0),max_seconds integer not null check(max_seconds between 1 and 1800 and max_seconds>=min_seconds),
 active boolean not null default true,
 foreign key(organization_id,bank_id) references public.test_banks(organization_id,id),
 check((kind='written' and options='[]' and correct_index is null) or (kind='mcq' and jsonb_typeof(options)='array' and jsonb_array_length(options) between 2 and 6 and correct_index is not null and correct_index between 1 and jsonb_array_length(options)))
);
create index test_questions_bank_idx on public.test_questions(bank_id,kind) where active;
alter table public.test_attempts drop constraint test_attempts_status_check;
alter table public.test_attempts add constraint test_attempts_status_check check(status in ('prepared','issued','submitted','expired'));
alter table public.test_attempts alter column issued_at drop not null,alter column deadline drop not null;
alter table public.test_attempts add column bank_version integer,add column total_seconds integer,add column submitted_at timestamptz,add column auto_submitted boolean not null default false;
alter table public.test_attempts add constraint one_attempt_per_application unique(application_id);
create table public.test_attempt_questions(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,attempt_id uuid not null,
 position integer not null check(position between 1 and 6),source_question_id uuid not null references public.test_questions(id),
 kind text not null check(kind in ('mcq','written')),prompt text not null,options jsonb not null,
 min_seconds integer not null,max_seconds integer not null,opens_at timestamptz,deadline timestamptz,
 foreign key(organization_id,attempt_id) references public.test_attempts(organization_id,id),unique(attempt_id,position),unique(attempt_id,source_question_id),unique(attempt_id,id)
);
create table public.test_attempt_keys(question_id uuid primary key references public.test_attempt_questions(id),correct_index integer not null);
create table public.test_answers(
 attempt_id uuid not null,question_id uuid not null,choice integer,written_text text,
 saved_at timestamptz not null default now(),primary key(attempt_id,question_id),
 foreign key(attempt_id,question_id) references public.test_attempt_questions(attempt_id,id),check(written_text is null or char_length(written_text)<=300)
);
create table public.test_written_grades(
 attempt_id uuid not null,question_id uuid not null,score integer not null check(score between 0 and 5),
 grader_id uuid not null references public.profiles(id),graded_at timestamptz not null default now(),
 primary key(attempt_id,question_id),foreign key(attempt_id,question_id) references public.test_attempt_questions(attempt_id,id)
);
alter table public.test_grades add constraint one_total_per_attempt unique(attempt_id);
create table public.test_audit_logs(id uuid primary key default gen_random_uuid(),attempt_id uuid not null references public.test_attempts(id),actor_id uuid references public.profiles(id),event text not null,created_at timestamptz not null default now());
create index test_due_attempts_idx on public.test_attempts(deadline) where status='issued';
create index test_audit_attempt_idx on public.test_audit_logs(attempt_id,created_at);
create function public.test_is_hr(attempt uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.test_attempts t where t.id=attempt and public.is_org_member(t.organization_id))
$$;
revoke all on function public.test_is_hr(uuid) from public,anon;grant execute on function public.test_is_hr(uuid) to authenticated;
alter table public.test_banks enable row level security;
alter table public.test_questions enable row level security;
alter table public.test_attempt_questions enable row level security;
alter table public.test_attempt_keys enable row level security;
alter table public.test_answers enable row level security;
alter table public.test_written_grades enable row level security;
alter table public.test_audit_logs enable row level security;
create policy banks_hr on public.test_banks for select to authenticated using(public.is_org_member(organization_id));
create policy questions_hr on public.test_questions for select to authenticated using(public.is_org_member(organization_id));
create policy snapshots_hr on public.test_attempt_questions for select to authenticated using(public.test_is_hr(attempt_id));
create policy answers_hr on public.test_answers for select to authenticated using(public.test_is_hr(attempt_id));
create policy written_grades_hr on public.test_written_grades for select to authenticated using(public.test_is_hr(attempt_id));
create policy test_audit_hr on public.test_audit_logs for select to authenticated using(public.test_is_hr(attempt_id));
revoke all on public.test_banks,public.test_questions,public.test_attempt_questions,public.test_attempt_keys,public.test_answers,public.test_written_grades,public.test_audit_logs from anon,authenticated;
grant select on public.test_banks,public.test_questions,public.test_attempt_questions,public.test_answers,public.test_written_grades,public.test_audit_logs to authenticated;
-- Tighten inherited score policies: membership must still be authorized.
drop policy grades_read_org on public.test_grades;
create policy grades_hr on public.test_grades for select to authenticated using(public.test_is_hr(attempt_id));

create function public.test_bank_ready(job uuid,written_count integer) returns boolean language sql stable security definer set search_path='' as $$
 select written_count between 0 and 3 and
 (select count(*) from public.test_questions q join public.test_banks b on b.id=q.bank_id where b.job_id=job and q.active and q.kind='mcq')>=10 and
 (select count(*) from public.test_questions q join public.test_banks b on b.id=q.bank_id where b.job_id=job and q.active and q.kind='written')>=written_count
$$;
revoke all on function public.test_bank_ready(uuid,integer) from public,anon,authenticated;
create function public.edit_test_question(job uuid,question uuid,payload jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare j public.jobs;b public.test_banks;result uuid;opt jsonb;
begin
 select * into j from public.jobs where id=job for update;
 if not found or not public.is_org_member(j.organization_id) then raise exception 'forbidden';end if;
 if j.status not in ('draft','paused','pending_review') then raise exception 'pause job first';end if;
 insert into public.test_banks(organization_id,job_id) values(j.organization_id,job) on conflict(job_id) do nothing;
 select * into b from public.test_banks where job_id=job for update;
 if payload->>'kind'='mcq' then
  if jsonb_typeof(payload->'options')<>'array' then raise exception 'options required';end if;
  for opt in select jsonb_array_elements(payload->'options') loop if jsonb_typeof(opt)<>'string' or length(trim(opt#>>'{}')) not between 1 and 500 then raise exception 'invalid option';end if;end loop;
 end if;
 if question is null then
  insert into public.test_questions(organization_id,bank_id,kind,prompt,options,correct_index,min_seconds,max_seconds,active) values(j.organization_id,b.id,payload->>'kind',payload->>'prompt',coalesce(payload->'options','[]'),(payload->>'correct_index')::integer,(payload->>'min_seconds')::integer,(payload->>'max_seconds')::integer,coalesce((payload->>'active')::boolean,true)) returning id into result;
 else
  update public.test_questions set kind=payload->>'kind',prompt=payload->>'prompt',options=coalesce(payload->'options','[]'),correct_index=(payload->>'correct_index')::integer,min_seconds=(payload->>'min_seconds')::integer,max_seconds=(payload->>'max_seconds')::integer,active=coalesce((payload->>'active')::boolean,true) where id=question and bank_id=b.id returning id into result;
  if not found then raise exception 'question not found';end if;
 end if;
 if j.test_enabled and not public.test_bank_ready(job,j.test_written_count) then raise exception 'enabled bank needs 10 MCQ and configured written questions';end if;
 update public.test_banks set version=version+1 where id=b.id;return result;
end $$;
-- Lock bank changes and configuration with the job. Existing snapshots remain untouched.
create function public.check_enabled_test() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.test_enabled and (tg_op='INSERT' or not old.test_enabled or new.test_written_count is distinct from old.test_written_count) and not public.test_bank_ready(new.id,new.test_written_count) then raise exception 'test bank incomplete';end if;
 return new;
end $$;
create trigger enabled_test_guard before insert or update of test_enabled,test_written_count on public.jobs for each row execute function public.check_enabled_test();

create function public.prepare_microtest(application uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare a public.applications;j public.jobs;b public.test_banks;t uuid;q public.test_questions;pos integer:=0;snapshot_id uuid;total integer:=0;
begin
 -- Lock order: job -> bank -> application, same as bank editing and application creation.
 select * into a from public.applications where id=application and candidate_id=auth.uid();
 if not found or not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null) then raise exception 'forbidden';end if;
 select * into j from public.jobs where id=a.job_id for share;
 select * into b from public.test_banks where job_id=j.id for share;
 perform 1 from public.applications where id=application for update;
 select id into t from public.test_attempts where application_id=application;
 if found then return t;end if;
 if a.status<>'test_pending' or b.id is null or not public.test_bank_ready(j.id,j.test_written_count) then raise exception 'test unavailable';end if;
 insert into public.test_attempts(organization_id,application_id,status,issued_at,deadline,bank_version) values(a.organization_id,a.id,'prepared',null,null,b.version) returning id into t;
 for q in select * from ( (select * from public.test_questions where bank_id=b.id and active and kind='mcq' order by random() limit 3) union all (select * from public.test_questions where bank_id=b.id and active and kind='written' order by random() limit j.test_written_count) ) picked loop
  pos:=pos+1;total:=total+q.max_seconds;
  insert into public.test_attempt_questions(organization_id,attempt_id,position,source_question_id,kind,prompt,options,min_seconds,max_seconds) values(a.organization_id,t,pos,q.id,q.kind,q.prompt,q.options,q.min_seconds,q.max_seconds) returning id into snapshot_id;
  if q.kind='mcq' then insert into public.test_attempt_keys values(snapshot_id,q.correct_index);end if;
 end loop;
 update public.test_attempts set total_seconds=total where id=t;
 insert into public.test_audit_logs(attempt_id,actor_id,event) values(t,auth.uid(),'prepared');return t;
end $$;
create function public.start_microtest(attempt uuid) returns void language plpgsql security definer set search_path='' as $$
declare t public.test_attempts;q record;cursor_time timestamptz;start_time timestamptz:=clock_timestamp();
begin
 select * into t from public.test_attempts where id=attempt for update;
 if not found or not exists(select 1 from public.applications where id=t.application_id and candidate_id=auth.uid()) then raise exception 'forbidden';end if;
 if t.status<>'prepared' then return;end if;
 cursor_time:=start_time;
 for q in select * from public.test_attempt_questions where attempt_id=attempt order by position loop
  update public.test_attempt_questions set opens_at=cursor_time,deadline=cursor_time+make_interval(secs=>q.max_seconds) where id=q.id;
  cursor_time:=cursor_time+make_interval(secs=>q.max_seconds);
 end loop;
 update public.test_attempts set status='issued',issued_at=start_time,deadline=cursor_time where id=attempt;
 insert into public.test_audit_logs(attempt_id,actor_id,event) values(attempt,auth.uid(),'started');
end $$;
create function public.store_test_answer(attempt uuid,question uuid,choice integer default null,written text default null) returns void language plpgsql security definer set search_path='' as $$
declare t public.test_attempts;q public.test_attempt_questions;now_at timestamptz;
begin
 select * into t from public.test_attempts where id=attempt for update;
 if not found or not exists(select 1 from public.applications where id=t.application_id and candidate_id=auth.uid()) then raise exception 'forbidden';end if;
 select * into q from public.test_attempt_questions where id=question and attempt_id=attempt;
 now_at:=clock_timestamp();
 if not found or t.status<>'issued' or now_at>=t.deadline or now_at<q.opens_at or now_at>=q.deadline then raise exception 'answer window closed';end if;
 if (q.kind='mcq' and (choice is null or choice<1 or choice>jsonb_array_length(q.options) or written is not null)) or (q.kind='written' and (choice is not null or written is null or char_length(written)>300)) then raise exception 'invalid answer';end if;
 insert into public.test_answers(attempt_id,question_id,choice,written_text) values(attempt,question,choice,written) on conflict(attempt_id,question_id) do update set choice=excluded.choice,written_text=excluded.written_text,saved_at=clock_timestamp();
end $$;
create function public.finalize_microtest(attempt uuid,force_submit boolean default false) returns void language plpgsql security definer set search_path='' as $$
declare t public.test_attempts;mcq integer;now_at timestamptz;
begin
 select * into t from public.test_attempts where id=attempt for update;
 now_at:=clock_timestamp();
 if not found or t.status<>'issued' or t.bank_version is null then return;end if;
 if now_at<t.deadline and not force_submit then return;end if;
 if force_submit and now_at<(select max(opens_at) from public.test_attempt_questions where attempt_id=attempt) then raise exception 'questions not all open';end if;
 select count(*) into mcq from public.test_answers a join public.test_attempt_keys k on k.question_id=a.question_id where a.attempt_id=attempt and a.choice=k.correct_index;
 update public.test_attempts set status='submitted',submitted_at=now_at,auto_submitted=(now_at>=deadline) where id=attempt;
 insert into public.test_grades(organization_id,attempt_id,score) values(t.organization_id,attempt,mcq) on conflict(attempt_id) do nothing;
 perform public.application_test_event(attempt,'submitted');
 if not exists(select 1 from public.test_attempt_questions where attempt_id=attempt and kind='written') then
  update public.test_attempts set review_ready_at=now_at where id=attempt;
  perform public.application_test_event(attempt,'graded');
 end if;
 insert into public.test_audit_logs(attempt_id,actor_id,event) values(attempt,auth.uid(),case when now_at>=t.deadline then 'auto_submitted' else 'submitted' end);
end $$;
create function public.submit_microtest(attempt uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.test_attempts t join public.applications a on a.id=t.application_id where t.id=attempt and a.candidate_id=auth.uid()) then raise exception 'forbidden';end if;
 perform public.finalize_microtest(attempt,true);
end $$;
create function public.get_test_player(application uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare t public.test_attempts;state text;
begin
 select status into state from public.applications where id=application and candidate_id=auth.uid();if not found then raise exception 'forbidden';end if;
 select * into t from public.test_attempts where application_id=application;
 if not found then return jsonb_build_object('application_status',state,'attempt',null);end if;
 perform public.finalize_microtest(t.id);
 select * into t from public.test_attempts where id=t.id;
 select status into state from public.applications where id=application;
 return jsonb_build_object('application_status',state,'attempt',jsonb_build_object('id',t.id,'status',t.status,'total_seconds',t.total_seconds,'deadline',t.deadline,'server_now',clock_timestamp(),'auto_submitted',t.auto_submitted,'ready',t.review_ready_at is not null,
 'questions',case when t.status in ('prepared','issued') then (select jsonb_agg(jsonb_build_object('id',q.id,'position',q.position,'kind',q.kind,'prompt',case when t.status='issued' then q.prompt else null end,'options',case when t.status='issued' then q.options else '[]'::jsonb end,'min_seconds',q.min_seconds,'max_seconds',q.max_seconds,'opens_at',q.opens_at,'deadline',q.deadline,'choice',a.choice,'written',a.written_text) order by q.position) from public.test_attempt_questions q left join public.test_answers a on a.attempt_id=q.attempt_id and a.question_id=q.id where q.attempt_id=t.id) else '[]'::jsonb end));
end $$;
create function public.grade_written_answer(attempt uuid,question uuid,points integer) returns void language plpgsql security definer set search_path='' as $$
declare t public.test_attempts;mcq integer;total integer;
begin
 select * into t from public.test_attempts where id=attempt for update;
 if not found or not public.is_org_member(t.organization_id) then raise exception 'forbidden';end if;
 perform public.finalize_microtest(attempt);
 select * into t from public.test_attempts where id=attempt;
 if t.review_ready_at is not null and exists(select 1 from public.test_written_grades where attempt_id=attempt and question_id=question and score=points) then return;end if;
 if t.status<>'submitted' or t.review_ready_at is not null then raise exception 'grading not open';end if;
 if not exists(select 1 from public.test_attempt_questions where id=question and attempt_id=attempt and kind='written') then raise exception 'not a written question';end if;
 insert into public.test_written_grades(attempt_id,question_id,score,grader_id) values(attempt,question,points,auth.uid()) on conflict(attempt_id,question_id) do update set score=excluded.score,grader_id=excluded.grader_id,graded_at=clock_timestamp();
 select count(*) into mcq from public.test_answers a join public.test_attempt_keys k on k.question_id=a.question_id where a.attempt_id=attempt and a.choice=k.correct_index;
 select mcq+coalesce(sum(score),0) into total from public.test_written_grades where attempt_id=attempt;
 update public.test_grades set score=total,graded_at=clock_timestamp() where attempt_id=attempt;
 if (select count(*) from public.test_written_grades where attempt_id=attempt)=(select count(*) from public.test_attempt_questions where attempt_id=attempt and kind='written') then
  update public.test_attempts set review_ready_at=clock_timestamp() where id=attempt;perform public.application_test_event(attempt,'graded');
 end if;
 insert into public.test_audit_logs(attempt_id,actor_id,event) values(attempt,auth.uid(),'written_graded');
end $$;
create function public.refresh_hr_test(attempt uuid) returns void language plpgsql security definer set search_path='' as $$
begin if not public.test_is_hr(attempt) then raise exception 'forbidden';end if;perform public.finalize_microtest(attempt);end $$;
create function public.finish_due_microtests() returns void language plpgsql security definer set search_path='' as $$
declare t record;
begin for t in select id from public.test_attempts where status='issued' and deadline<=clock_timestamp() loop perform public.finalize_microtest(t.id);end loop;end $$;
create function public.configure_microtest(job uuid,enabled boolean,written_count integer) returns void language plpgsql security definer set search_path='' as $$
declare j public.jobs;
begin
 select * into j from public.jobs where id=job for update;
 if not found or not public.is_org_member(j.organization_id) then raise exception 'forbidden';end if;
 if j.status not in ('draft','paused','pending_review') then raise exception 'pause job first';end if;
 update public.jobs set test_enabled=enabled,test_written_count=written_count,updated_at=now() where id=job;
end $$;
revoke all on function public.configure_microtest(uuid,boolean,integer) from public,anon;
grant execute on function public.configure_microtest(uuid,boolean,integer) to authenticated;
revoke all on function public.finalize_microtest(uuid,boolean),public.finish_due_microtests(),public.check_enabled_test() from public,anon,authenticated;
revoke all on function public.edit_test_question(uuid,uuid,jsonb),public.prepare_microtest(uuid),public.start_microtest(uuid),public.store_test_answer(uuid,uuid,integer,text),public.submit_microtest(uuid),public.get_test_player(uuid),public.grade_written_answer(uuid,uuid,integer),public.refresh_hr_test(uuid) from public,anon;
grant execute on function public.edit_test_question(uuid,uuid,jsonb),public.prepare_microtest(uuid),public.start_microtest(uuid),public.store_test_answer(uuid,uuid,integer,text),public.submit_microtest(uuid),public.get_test_player(uuid),public.grade_written_answer(uuid,uuid,integer),public.refresh_hr_test(uuid) to authenticated;
create or replace function public.transition_job(job uuid, target text) returns void language plpgsql security definer set search_path='' as $$
declare j public.jobs;
begin
 select * into j from public.jobs where id=job for update;
 if not found or not public.is_org_member(j.organization_id) then raise exception 'forbidden';end if;
 if target='published' then
  perform 1 from public.organizations o where o.id=j.organization_id and o.verification_status='verified' and exists(select 1 from public.organization_verifications v where v.organization_id=o.id and v.decision='verified') for share;
  if not found then raise exception 'organization not verified';end if;
  if j.status not in ('draft','pending_review','paused') or j.branch_id is null or length(trim(j.industry))=0 or j.salary_min is null or j.salary_max is null or j.salary_unit is null or j.salary_basis is null or j.work_mode is null or length(trim(j.description))=0 or length(trim(j.requirements))=0 or length(trim(j.benefits))=0 or not j.safety_commitment or (select count(*) from public.job_skills where job_id=job)<>3 then raise exception 'job incomplete';end if;
  -- Publish only with a complete active question bank.
  if j.test_enabled and not public.test_bank_ready(j.id,j.test_written_count) then raise exception 'test bank not ready';end if;
 elsif target='paused' then if j.status<>'published' then raise exception 'invalid transition';end if;
 elsif target='closed' then if j.status not in ('draft','pending_review','paused','published') then raise exception 'invalid transition';end if;
 else raise exception 'invalid transition';end if;
 update public.jobs set status=target,published_at=case when target='published' then now() else published_at end,updated_at=now() where id=job;
end $$;


commit;
