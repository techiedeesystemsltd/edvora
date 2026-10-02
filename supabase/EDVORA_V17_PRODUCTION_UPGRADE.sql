-- EDVORA V17 production hardening
-- Apply after EDVORA_COMPLETE_SCHEMA_V16.sql.
-- Single tenant = one school. No campuses table.

-- Fix a teacher/student behaviour RLS reference from the V16 policy.
drop policy if exists student_behaviour_manage on public.student_behaviour_records;
create policy student_behaviour_manage on public.student_behaviour_records for all to authenticated
using(
  public.is_school_admin(student_behaviour_records.school_id)
  or (
    public.is_school_teacher(student_behaviour_records.school_id)
    and exists(
      select 1 from public.teacher_class_assignments a
      join public.students s on s.class_id=a.class_id
      where a.school_id=student_behaviour_records.school_id
        and a.teacher_user_id=auth.uid()
        and s.id=student_behaviour_records.student_id
    )
  )
)
with check(
  public.is_school_admin(student_behaviour_records.school_id)
  or public.is_school_teacher(student_behaviour_records.school_id)
);

-- Realtime for operational surfaces. Only add when not already published.
do $$ declare t text; begin
  foreach t in array array['notifications','messages','assignments','assignment_submissions','school_events','notification_deliveries','system_incidents','school_health_snapshots'] loop
    if to_regclass('public.'||t) is not null and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
      execute format('alter publication supabase_realtime add table public.%I',t);
    end if;
  end loop;
exception when undefined_object then null; end $$;

-- Operational indexes.
create index if not exists idx_notification_deliveries_retry on public.notification_deliveries(status,attempts,created_at);
create index if not exists idx_login_events_user_created on public.login_events(user_id,created_at desc);
create index if not exists idx_backup_operations_school_created on public.backup_operations(school_id,created_at desc);
create index if not exists idx_import_jobs_school_status on public.import_jobs(school_id,status,created_at desc);
create index if not exists idx_health_school_captured on public.school_health_snapshots(school_id,captured_at desc);

-- Safer notification retry metadata without breaking existing rows.
alter table public.notification_deliveries add column if not exists next_attempt_at timestamptz;
alter table public.notification_deliveries add column if not exists max_attempts integer not null default 5;
alter table public.notification_deliveries add column if not exists delivered_at timestamptz;

-- Backup/DR records capture verification and restore-test evidence.
alter table public.backup_operations add column if not exists checksum text;
alter table public.backup_operations add column if not exists verified_at timestamptz;
alter table public.backup_operations add column if not exists restore_tested_at timestamptz;
alter table public.backup_operations add column if not exists rpo_minutes integer;
alter table public.backup_operations add column if not exists rto_minutes integer;

-- School-level health snapshot helper for scheduled monitoring jobs.
create or replace function public.capture_school_health(target_school_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare result_id uuid; au integer; ar integer; rr integer; fi integer; ce integer; pa integer;
begin
  if not (public.is_platform_admin() or public.is_school_admin(target_school_id)) then raise exception 'Not allowed'; end if;
  select count(*) into au from school_memberships where school_id=target_school_id and status='active';
  select count(*) into ar from attendance_records where school_id=target_school_id;
  select count(*) into rr from results where school_id=target_school_id;
  select count(*) into fi from fee_invoices where school_id=target_school_id;
  select count(*) into ce from cbt_exams where school_id=target_school_id;
  select count(*) into pa from student_guardians where school_id=target_school_id and user_id is not null;
  insert into school_health_snapshots(school_id,active_users,attendance_usage,results_usage,fee_usage,cbt_usage,parent_activation)
  values(target_school_id,au,least(100,ar),least(100,rr),least(100,fi),least(100,ce),least(100,pa)) returning id into result_id;
  return result_id;
end $$;
revoke all on function public.capture_school_health(uuid) from public;
grant execute on function public.capture_school_health(uuid) to authenticated;

-- Static security assertions are kept in EDVORA_V17_SECURITY_TESTS.sql so CI can inspect
-- tenant predicates without bypassing RLS with a service role.
