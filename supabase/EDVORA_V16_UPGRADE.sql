-- EDVORA V16 PRODUCTION UPGRADE
-- Apply after EDVORA_COMPLETE_SCHEMA_V15.sql.

-- Incident records must be tenant-scoped.
alter table public.system_incidents add column if not exists school_id uuid references public.schools(id) on delete cascade;
create index if not exists idx_system_incidents_school on public.system_incidents(school_id,created_at desc);

-- Message read receipts / delivery metadata.
alter table public.messages add column if not exists read_at timestamptz;
alter table public.messages add column if not exists attachment_urls jsonb not null default '[]'::jsonb;

-- Import preview / validation fields.
alter table public.import_jobs add column if not exists preview jsonb not null default '{}'::jsonb;
alter table public.import_jobs add column if not exists mapping jsonb not null default '{}'::jsonb;

-- Backups need verification and restore-test state.
alter table public.backup_operations add column if not exists verification_status text not null default 'pending';
alter table public.backup_operations add column if not exists restore_tested_at timestamptz;
alter table public.backup_operations add column if not exists retention_until timestamptz;

-- Notification delivery queue needs retry scheduling.
alter table public.notification_deliveries add column if not exists next_attempt_at timestamptz;
alter table public.notification_deliveries add column if not exists delivered_payload jsonb;
create index if not exists idx_notification_queue on public.notification_deliveries(status,next_attempt_at,created_at);

-- Provider connection health.
alter table public.integration_connections add column if not exists capabilities jsonb not null default '[]'::jsonb;
alter table public.integration_connections add column if not exists last_test_result jsonb;

-- Tenant-safe assignment and event policies.
drop policy if exists assignments_school_access on public.assignments;
drop policy if exists assignments_school_read on public.assignments;
drop policy if exists assignments_school_manage on public.assignments;
create policy assignments_school_read on public.assignments for select to authenticated using(public.is_school_member(school_id));
create policy assignments_school_manage on public.assignments for insert to authenticated with check(public.is_school_admin(school_id) or (public.is_school_teacher(school_id) and teacher_id=auth.uid()));
create policy assignments_school_update on public.assignments for update to authenticated using(public.is_school_admin(school_id) or (public.is_school_teacher(school_id) and teacher_id=auth.uid())) with check(public.is_school_admin(school_id) or (public.is_school_teacher(school_id) and teacher_id=auth.uid()));
create policy assignments_school_delete on public.assignments for delete to authenticated using(public.is_school_admin(school_id) or (public.is_school_teacher(school_id) and teacher_id=auth.uid()));

drop policy if exists school_events_school_access on public.school_events;
drop policy if exists school_events_read on public.school_events;
drop policy if exists school_events_manage on public.school_events;
create policy school_events_read on public.school_events for select to authenticated using(public.is_school_member(school_id));
create policy school_events_manage on public.school_events for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));

-- Correct the teacher/student behaviour policy so school_id is never ambiguous.
drop policy if exists student_behaviour_manage on public.student_behaviour_records;
create policy student_behaviour_manage on public.student_behaviour_records for all to authenticated
using(public.is_school_admin(student_behaviour_records.school_id) or (public.is_school_teacher(student_behaviour_records.school_id) and exists(
  select 1 from public.teacher_class_assignments a join public.students s on s.class_id=a.class_id
  where a.school_id=student_behaviour_records.school_id and a.teacher_id=auth.uid() and s.id=student_behaviour_records.student_id
)))
with check(public.is_school_admin(student_behaviour_records.school_id) or public.is_school_teacher(student_behaviour_records.school_id));

-- Operational RLS.
alter table public.system_incidents enable row level security;
drop policy if exists system_incidents_read on public.system_incidents;
drop policy if exists system_incidents_manage on public.system_incidents;
create policy system_incidents_read on public.system_incidents for select to authenticated using(public.is_platform_admin() or (school_id is not null and public.is_school_member(school_id)));
create policy system_incidents_manage on public.system_incidents for all to authenticated using(public.is_platform_admin() or (school_id is not null and public.is_school_admin(school_id))) with check(public.is_platform_admin() or (school_id is not null and public.is_school_admin(school_id)));

-- Notification queue is created by authenticated school staff; users can read their own in-app notifications.
drop policy if exists notification_delivery_insert on public.notification_deliveries;
create policy notification_delivery_insert on public.notification_deliveries for insert to authenticated with check(public.is_school_admin(school_id));

-- Backups are operational records, never directly writable by ordinary members.
alter table public.backup_operations enable row level security;
drop policy if exists backup_operations_access on public.backup_operations;
create policy backup_operations_access on public.backup_operations for select to authenticated using(public.is_platform_admin() or (school_id is not null and public.is_school_admin(school_id)));
drop policy if exists backup_operations_admin on public.backup_operations;
create policy backup_operations_admin on public.backup_operations for all to authenticated using(public.is_platform_admin() or (school_id is not null and public.is_school_admin(school_id))) with check(public.is_platform_admin() or (school_id is not null and public.is_school_admin(school_id)));

-- Security device and MFA records are user-owned; platform admins may investigate without changing them.
drop policy if exists security_devices_own on public.security_devices;
create policy security_devices_own on public.security_devices for all to authenticated using(user_id=auth.uid() or public.is_platform_admin()) with check(user_id=auth.uid() or public.is_platform_admin());
alter table public.mfa_enrollments enable row level security;
drop policy if exists mfa_own on public.mfa_enrollments;
create policy mfa_own on public.mfa_enrollments for all to authenticated using(user_id=auth.uid() or public.is_platform_admin()) with check(user_id=auth.uid() or public.is_platform_admin());

-- Rate-limit helper used by public APIs.
create or replace function public.allow_public_request(request_key text, action_name text, window_seconds integer default 300, max_requests integer default 10)
returns boolean language plpgsql security definer set search_path=public as $$
declare n integer;
begin
  delete from public.rate_limit_events where created_at < now() - make_interval(secs=>greatest(window_seconds,1)*4);
  select count(*) into n from public.rate_limit_events where key_hash=encode(digest(coalesce(request_key,'unknown'),'sha256'),'hex') and action=action_name and created_at >= now() - make_interval(secs=>greatest(window_seconds,1));
  if n >= greatest(max_requests,1) then return false; end if;
  insert into public.rate_limit_events(key_hash,action) values(encode(digest(coalesce(request_key,'unknown'),'sha256'),'hex'),action_name);
  return true;
end; $$;
revoke all on function public.allow_public_request(text,text,integer,integer) from public;
grant execute on function public.allow_public_request(text,text,integer,integer) to service_role;

-- Useful indexes for search / reporting.
create index if not exists idx_students_search on public.students(school_id,last_name,first_name);
create index if not exists idx_assignments_school_due on public.assignments(school_id,due_date desc);
create index if not exists idx_messages_school_created on public.messages(school_id,created_at desc);
create index if not exists idx_events_school_start on public.school_events(school_id,starts_at);

-- Default RTO/RPO documentation lives in configuration metadata instead of pretending a backup provider exists.
insert into public.platform_feature_flags(feature_key,enabled,description) values
('production_backup_verification',true,'Track backup verification and restore-test status.'),
('notification_delivery_queue',true,'Use notification_deliveries as the unified delivery queue.'),
('realtime_operations',true,'Realtime operational signals for school-scoped events.')
on conflict(feature_key) do update set enabled=excluded.enabled,description=excluded.description;
