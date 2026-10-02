-- EDVORA V18 PRODUCTION UPGRADE
-- Canonical results engine, production CBT, finance idempotency,
-- security/observability events, and operational hardening.
-- Apply after EDVORA_COMPLETE_SCHEMA_V16.sql + V17 upgrades.

create extension if not exists pgcrypto;

-- ============================================================
-- 1. CANONICAL RESULTS ENGINE
-- ============================================================
create table if not exists public.result_configurations (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  session_id uuid references public.academic_sessions(id) on delete cascade,
  term_id uuid references public.academic_terms(id) on delete cascade,
  ca_weight numeric(5,2) not null default 40 check(ca_weight >= 0 and ca_weight <= 100),
  exam_weight numeric(5,2) not null default 60 check(exam_weight >= 0 and exam_weight <= 100),
  ranking_enabled boolean not null default true,
  ranking_method text not null default 'total' check(ranking_method in ('total','average','grade_point')),
  publication_policy text not null default 'admin_publish' check(publication_policy in ('admin_publish','approval_then_publish')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(school_id,session_id,term_id),
  check(abs((ca_weight + exam_weight) - 100) < 0.01)
);

create table if not exists public.student_term_results (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  session_id uuid not null references public.academic_sessions(id) on delete cascade,
  term_id uuid not null references public.academic_terms(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  ca_raw numeric(10,2),
  ca_percent numeric(10,2),
  exam_raw numeric(10,2),
  exam_percent numeric(10,2),
  total numeric(10,2),
  grade text,
  remark text,
  grade_point numeric(8,2),
  position integer,
  status text not null default 'draft' check(status in ('draft','submitted','review','approved','published','locked')),
  published_at timestamptz,
  locked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(school_id,student_id,session_id,term_id,subject_id)
);

create table if not exists public.result_correction_requests (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  result_id uuid not null references public.student_term_results(id) on delete cascade,
  requested_by uuid references auth.users(id) on delete set null,
  reason text not null,
  status text not null default 'requested' check(status in ('requested','authorized','rejected','completed')),
  authorized_by uuid references auth.users(id) on delete set null,
  completed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.result_access_pins (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  session_id uuid not null references public.academic_sessions(id) on delete cascade,
  term_id uuid not null references public.academic_terms(id) on delete cascade,
  pin_hash text not null,
  prefix text not null,
  expires_at timestamptz,
  used_at timestamptz,
  created_at timestamptz not null default now(),
  unique(school_id,student_id,session_id,term_id)
);

alter table public.report_cards add column if not exists locked_at timestamptz;
alter table public.report_cards add column if not exists approved_by uuid references auth.users(id) on delete set null;
alter table public.report_cards add column if not exists approved_at timestamptz;
alter table public.report_cards drop constraint if exists report_cards_status_check;
alter table public.report_cards drop constraint if exists report_cards_status_check_v18;
alter table public.report_cards add constraint report_cards_status_check_v18 check(status in ('draft','review','approved','published','locked'));

create index if not exists idx_student_term_results_lookup on public.student_term_results(school_id,session_id,term_id,student_id);
create index if not exists idx_student_term_results_subject on public.student_term_results(school_id,session_id,term_id,subject_id,total desc);

create or replace function public.recalculate_term_results(target_school uuid,target_session uuid,target_term uuid)
returns integer language plpgsql security definer set search_path=public as $$
declare
  cfg record; n integer:=0; r record; g jsonb;
begin
  if not public.is_school_admin(target_school) then raise exception 'Not authorized'; end if;
  select * into cfg from public.result_configurations where school_id=target_school and session_id=target_session and term_id=target_term;
  if not found then
    insert into public.result_configurations(school_id,session_id,term_id) values(target_school,target_session,target_term)
    returning * into cfg;
  end if;
  if abs((cfg.ca_weight + cfg.exam_weight)-100) >= .01 then raise exception 'CA and exam weights must total 100'; end if;

  for r in
    select distinct e.student_id, a.subject_id,
      coalesce((select avg((s.score/nullif(a2.max_score,0))*100) from public.assessment_scores s join public.assessments a2 on a2.id=s.assessment_id where s.school_id=target_school and s.student_id=e.student_id and a2.subject_id=a.subject_id and a2.session_id=target_session and a2.term_id=target_term and lower(a2.assessment_type) in ('ca','test','assignment')),0) ca_pct,
      coalesce((select avg((s.score/nullif(a2.max_score,0))*100) from public.assessment_scores s join public.assessments a2 on a2.id=s.assessment_id where s.school_id=target_school and s.student_id=e.student_id and a2.subject_id=a.subject_id and a2.session_id=target_session and a2.term_id=target_term and lower(a2.assessment_type) in ('exam','final')),0) exam_pct
    from public.student_enrollments e
    join public.assessments a on a.school_id=target_school and a.class_id=e.class_id and a.session_id=target_session and a.term_id=target_term
    where e.school_id=target_school and e.session_id=target_session and e.is_current=true
  loop
    g:=public.grade_for_score(target_school,round((r.ca_pct*cfg.ca_weight/100)+(r.exam_pct*cfg.exam_weight/100),2));
    insert into public.student_term_results(school_id,student_id,session_id,term_id,subject_id,ca_percent,exam_percent,total,grade,remark,grade_point,status,updated_at)
    values(target_school,r.student_id,target_session,target_term,r.subject_id,r.ca_pct,r.exam_pct,round((r.ca_pct*cfg.ca_weight/100)+(r.exam_pct*cfg.exam_weight/100),2),g->>'grade',g->>'remark',(g->>'grade_point')::numeric,'draft',now())
    on conflict(school_id,student_id,session_id,term_id,subject_id) do update set ca_percent=excluded.ca_percent,exam_percent=excluded.exam_percent,total=excluded.total,grade=excluded.grade,remark=excluded.remark,grade_point=excluded.grade_point,updated_at=now();
    n:=n+1;
  end loop;

  update public.student_term_results x set position=r.pos
  from (
    select id,row_number() over(partition by school_id,session_id,term_id,subject_id order by total desc nulls last) pos
    from public.student_term_results where school_id=target_school and session_id=target_session and term_id=target_term
  ) r where x.id=r.id;
  return n;
end;
$$;
revoke all on function public.recalculate_term_results(uuid,uuid,uuid) from public;
grant execute on function public.recalculate_term_results(uuid,uuid,uuid) to authenticated;

create or replace function public.publish_term_results(target_school uuid,target_session uuid,target_term uuid)
returns integer language plpgsql security definer set search_path=public as $$
declare n integer;
begin
  if not public.is_school_admin(target_school) then raise exception 'Not authorized'; end if;
  update public.student_term_results set status='published',published_at=coalesce(published_at,now()),updated_at=now() where school_id=target_school and session_id=target_session and term_id=target_term and status in ('draft','submitted','review','approved');
  get diagnostics n=row_count;
  update public.report_cards set status='published',published_at=coalesce(published_at,now()),updated_at=now() where school_id=target_school and session_id=target_session and term_id=target_term and status in ('draft','review','approved');
  return n;
end;
$$;
revoke all on function public.publish_term_results(uuid,uuid,uuid) from public;
grant execute on function public.publish_term_results(uuid,uuid,uuid) to authenticated;

create or replace function public.lock_term_results(target_school uuid,target_session uuid,target_term uuid)
returns integer language plpgsql security definer set search_path=public as $$
declare n integer;
begin
  if not public.is_school_admin(target_school) then raise exception 'Not authorized'; end if;
  update public.student_term_results set status='locked',locked_at=now(),updated_at=now() where school_id=target_school and session_id=target_session and term_id=target_term and status='published';
  get diagnostics n=row_count;
  update public.report_cards set status='locked',locked_at=now(),updated_at=now() where school_id=target_school and session_id=target_session and term_id=target_term and status='published';
  return n;
end;
$$;
revoke all on function public.lock_term_results(uuid,uuid,uuid) from public;
grant execute on function public.lock_term_results(uuid,uuid,uuid) to authenticated;

-- ============================================================
-- 2. CBT PRODUCTION ENGINE
-- ============================================================
alter table public.cbt_exams add column if not exists instructions text;
alter table public.cbt_exams add column if not exists settings jsonb not null default '{}'::jsonb;
alter table public.cbt_exams add column if not exists result_visibility text not null default 'after_publication' check(result_visibility in ('immediate','after_publication','never'));
alter table public.cbt_exams add column if not exists attempt_limit integer not null default 1;
alter table public.cbt_exams add column if not exists randomize_questions boolean not null default false;
alter table public.cbt_exams add column if not exists randomize_options boolean not null default false;
alter table public.cbt_exams add column if not exists require_fullscreen boolean not null default true;
alter table public.cbt_exams add column if not exists integrity_monitoring boolean not null default true;
alter table public.cbt_questions add column if not exists answer_schema jsonb not null default '{}'::jsonb;
alter table public.cbt_questions add column if not exists media_url text;
alter table public.cbt_attempts add column if not exists last_activity_at timestamptz;
alter table public.cbt_attempts add column if not exists integrity_count integer not null default 0;
alter table public.cbt_attempts add column if not exists client_state_hash text;

create table if not exists public.cbt_integrity_events (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  attempt_id uuid not null references public.cbt_attempts(id) on delete cascade,
  event_type text not null check(event_type in ('fullscreen_exit','fullscreen_enter','visibility_hidden','visibility_visible','blur','focus','offline','online','navigation_attempt','time_expired','submit_attempt')),
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create table if not exists public.cbt_sync_events (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  attempt_id uuid not null references public.cbt_attempts(id) on delete cascade,
  client_event_id text not null, event_type text not null, payload jsonb not null default '{}'::jsonb,
  status text not null default 'synced' check(status in ('queued','synced','failed')), created_at timestamptz not null default now(), synced_at timestamptz,
  unique(attempt_id,client_event_id)
);
create index if not exists idx_cbt_integrity_attempt on public.cbt_integrity_events(attempt_id,created_at desc);

create or replace function public.record_cbt_integrity_event(target_attempt uuid,target_event text,target_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare a public.cbt_attempts; id uuid;
begin
  select * into a from public.cbt_attempts where id=target_attempt;
  if a.id is null then raise exception 'Attempt not found'; end if;
  if not exists(select 1 from public.student_accounts where user_id=auth.uid() and student_id=a.student_id and status='active') then raise exception 'Not authorized'; end if;
  insert into public.cbt_integrity_events(school_id,attempt_id,event_type,metadata) values(a.school_id,a.id,target_event,target_metadata) returning id into id;
  update public.cbt_attempts set integrity_count=integrity_count+1,last_activity_at=now() where id=a.id;
  return id;
end;
$$;
revoke all on function public.record_cbt_integrity_event(uuid,text,jsonb) from public;
grant execute on function public.record_cbt_integrity_event(uuid,text,jsonb) to authenticated;

-- Never expose scores from the student exam endpoint unless visibility permits it.
create or replace function public.get_student_cbt_result(target_attempt_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.cbt_attempts; e public.cbt_exams; sid uuid;
begin
  select * into a from public.cbt_attempts where id=target_attempt_id;
  if a.id is null then raise exception 'Attempt not found'; end if;
  select student_id into sid from public.student_accounts where user_id=auth.uid() and student_id=a.student_id and status='active';
  if sid is null then raise exception 'Not authorized'; end if;
  select * into e from public.cbt_exams where id=a.exam_id;
  if e.result_visibility<>'immediate' then
    return jsonb_build_object('status',a.status,'available',false,'message','Your result will be available when your school publishes it.');
  end if;
  return jsonb_build_object('status',a.status,'available',true,'score',a.score,'max_score',a.max_score,'percentage',case when coalesce(a.max_score,0)>0 then round(a.score/a.max_score*100,2) else 0 end);
end;
$$;
revoke all on function public.get_student_cbt_result(uuid) from public;
grant execute on function public.get_student_cbt_result(uuid) to authenticated;

-- ============================================================
-- 3. FINANCE PRODUCTION CONTROLS
-- ============================================================
create table if not exists public.payment_idempotency_keys (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  idempotency_key text not null, provider text, request_hash text, payment_id uuid references public.payments(id) on delete set null,
  status text not null default 'processing' check(status in ('processing','completed','failed')), response jsonb,
  created_at timestamptz not null default now(), completed_at timestamptz, unique(school_id,idempotency_key)
);
create table if not exists public.finance_reconciliations (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  period_start date not null, period_end date not null, status text not null default 'open' check(status in ('open','review','reconciled','locked')),
  expected_amount numeric(14,2) not null default 0, actual_amount numeric(14,2) not null default 0, variance numeric(14,2) not null default 0,
  reconciled_by uuid references auth.users(id) on delete set null, reconciled_at timestamptz, reconciliation_date date not null default current_date, created_at timestamptz not null default now()
);
create unique index if not exists uq_payments_provider_reference on public.payments(provider,provider_reference) where provider_reference is not null;
create index if not exists idx_ledger_school_date on public.finance_ledger_entries(school_id,entry_date desc);

-- ============================================================
-- 4. SECURITY / OBSERVABILITY
-- ============================================================
create table if not exists public.security_events (
  id uuid primary key default gen_random_uuid(), school_id uuid references public.schools(id) on delete set null,
  user_id uuid references auth.users(id) on delete set null, event_type text not null, severity text not null default 'info' check(severity in ('info','warning','critical')),
  ip_hash text, user_agent text, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create table if not exists public.session_devices (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  device_hash text not null, label text, last_seen_at timestamptz not null default now(), revoked_at timestamptz, created_at timestamptz not null default now(), unique(user_id,device_hash)
);
create table if not exists public.integration_health (
  id uuid primary key default gen_random_uuid(), school_id uuid references public.schools(id) on delete cascade,
  provider text not null, status text not null default 'unknown' check(status in ('healthy','degraded','failed','unknown')),
  last_checked_at timestamptz, latency_ms integer, error_message text, metadata jsonb not null default '{}'::jsonb, unique(school_id,provider)
);
create table if not exists public.observability_events (
  id uuid primary key default gen_random_uuid(), school_id uuid references public.schools(id) on delete set null,
  event_type text not null, level text not null default 'info' check(level in ('debug','info','warning','error','critical')),
  route text, correlation_id text, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

-- RLS hardening for V18 tables.
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['result_configurations','student_term_results','result_correction_requests','result_access_pins','cbt_integrity_events','cbt_sync_events','payment_idempotency_keys','finance_reconciliations','security_events','session_devices','integration_health','observability_events'] LOOP
    EXECUTE format('alter table public.%I enable row level security',t);
  END LOOP;
END $$;

drop policy if exists v18_result_config_access on public.result_configurations;
create policy v18_result_config_access on public.result_configurations for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
drop policy if exists v18_results_read on public.student_term_results;
create policy v18_results_read on public.student_term_results for select to authenticated using(public.is_school_member(school_id) or public.is_linked_student(school_id,student_id) or public.is_linked_guardian(school_id,student_id));
drop policy if exists v18_results_admin on public.student_term_results;
create policy v18_results_admin on public.student_term_results for update to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
drop policy if exists v18_correction_admin on public.result_correction_requests;
create policy v18_correction_admin on public.result_correction_requests for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
drop policy if exists v18_cbt_integrity_admin on public.cbt_integrity_events;
create policy v18_cbt_integrity_admin on public.cbt_integrity_events for select to authenticated using(public.is_school_admin(school_id) or exists(select 1 from public.cbt_attempts a where a.id=attempt_id and a.student_id in(select student_id from public.student_accounts where user_id=auth.uid())));
drop policy if exists v18_cbt_sync_student on public.cbt_sync_events;
create policy v18_cbt_sync_student on public.cbt_sync_events for all to authenticated using(exists(select 1 from public.cbt_attempts a where a.id=attempt_id and a.student_id in(select student_id from public.student_accounts where user_id=auth.uid()))) with check(exists(select 1 from public.cbt_attempts a where a.id=attempt_id and a.student_id in(select student_id from public.student_accounts where user_id=auth.uid())));
drop policy if exists v18_finance_admin on public.payment_idempotency_keys;
create policy v18_finance_admin on public.payment_idempotency_keys for all to authenticated using(public.is_school_finance_staff(school_id)) with check(public.is_school_finance_staff(school_id));
drop policy if exists v18_reconciliation_admin on public.finance_reconciliations;
create policy v18_reconciliation_admin on public.finance_reconciliations for all to authenticated using(public.is_school_finance_staff(school_id)) with check(public.is_school_finance_staff(school_id));
drop policy if exists v18_security_admin on public.security_events;
create policy v18_security_admin on public.security_events for select to authenticated using(public.is_platform_admin() or (school_id is not null and public.is_school_admin(school_id)));
drop policy if exists v18_device_self on public.session_devices;
create policy v18_device_self on public.session_devices for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists v18_integration_health_admin on public.integration_health;
create policy v18_integration_health_admin on public.integration_health for select to authenticated using(public.is_platform_admin() or (school_id is not null and public.is_school_admin(school_id)));
drop policy if exists v18_observability_admin on public.observability_events;
create policy v18_observability_admin on public.observability_events for select to authenticated using(public.is_platform_admin() or (school_id is not null and public.is_school_admin(school_id)));

-- Helpful tenant indexes.
create index if not exists idx_security_events_school_created on public.security_events(school_id,created_at desc);
create index if not exists idx_observability_events_created on public.observability_events(created_at desc);

-- Seed a default result configuration for every existing school/current academic context where possible.
insert into public.result_configurations(school_id,session_id,term_id)
select s.id, ses.id, ter.id from public.schools s
join lateral (select id from public.academic_sessions x where x.school_id=s.id and x.is_current=true order by x.starts_on desc limit 1) ses on true
join lateral (select id from public.academic_terms x where x.school_id=s.id and x.is_current=true order by x.starts_on desc limit 1) ter on true
on conflict do nothing;

-- V18 complete.
