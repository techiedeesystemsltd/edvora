-- EDVORA V10 FEATURE COMPLETION / UPGRADE MIGRATION
-- Run AFTER EDVORA_COMPLETE_SCHEMA.sql on an existing database.
-- Also included at the end of the complete schema build.

-- ============================================================
-- 1-3 ASSIGNMENTS + CALENDAR + AI WORKFLOW DATA
-- ============================================================
create table if not exists public.assignments (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 class_id uuid references public.classes(id) on delete set null, subject_id uuid references public.subjects(id) on delete set null,
 teacher_id uuid references auth.users(id) on delete set null, title text not null, description text, instructions text,
 due_at timestamptz, max_score numeric(8,2), status text not null default 'draft' check(status in ('draft','published','closed')),
 attachments jsonb not null default '[]'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.assignment_submissions (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 assignment_id uuid not null references public.assignments(id) on delete cascade, student_id uuid not null references public.students(id) on delete cascade,
 submitted_at timestamptz, status text not null default 'draft' check(status in ('draft','submitted','late','returned')),
 content text, attachments jsonb not null default '[]'::jsonb, score numeric(8,2), feedback text, graded_by uuid references auth.users(id) on delete set null,
 graded_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(assignment_id,student_id)
);
create table if not exists public.school_events (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 title text not null, description text, event_type text not null default 'event' check(event_type in ('event','holiday','exam','meeting','pta','deadline','term_start','term_end')),
 starts_at timestamptz not null, ends_at timestamptz, all_day boolean not null default false, location text, audience text[] not null default array['all'], created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.ai_generation_jobs (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 requested_by uuid references auth.users(id) on delete set null, job_type text not null, input jsonb not null default '{}'::jsonb,
 output jsonb, status text not null default 'queued' check(status in ('queued','running','completed','failed')), error text, created_at timestamptz not null default now(), completed_at timestamptz
);

-- ============================================================
-- 4-8 DELIVERY / INTEGRATIONS
-- ============================================================
create table if not exists public.notification_deliveries (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 notification_id uuid references public.notifications(id) on delete cascade, channel text not null check(channel in ('in_app','email','sms','push','whatsapp')),
 provider text, destination text, status text not null default 'queued' check(status in ('queued','sent','delivered','failed','cancelled')),
 provider_message_id text, attempts integer not null default 0, last_error text, sent_at timestamptz, delivered_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.integration_connections (
 id uuid primary key default gen_random_uuid(), school_id uuid references public.schools(id) on delete cascade,
 provider text not null, label text, config jsonb not null default '{}'::jsonb, secret_ref text, status text not null default 'disconnected' check(status in ('connected','disconnected','error','testing')),
 last_tested_at timestamptz, last_error text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(school_id,provider)
);
create table if not exists public.webhook_events (
 id uuid primary key default gen_random_uuid(), school_id uuid references public.schools(id) on delete set null, provider text not null, event_key text not null,
 payload jsonb not null default '{}'::jsonb, status text not null default 'received' check(status in ('received','processed','failed','ignored')), attempts integer not null default 0,
 error text, received_at timestamptz not null default now(), processed_at timestamptz, unique(provider,event_key)
);
create table if not exists public.push_subscriptions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, school_id uuid references public.schools(id) on delete cascade,
 endpoint text not null unique, p256dh text, auth_key text, user_agent text, created_at timestamptz not null default now(), last_seen_at timestamptz not null default now()
);

-- ============================================================
-- 9-10 SEARCH + PROFILES + DOCUMENTS
-- ============================================================
create table if not exists public.student_documents (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, student_id uuid not null references public.students(id) on delete cascade,
 name text not null, storage_path text not null, document_type text, mime_type text, size_bytes bigint, uploaded_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now()
);
create table if not exists public.teacher_documents (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, teacher_id uuid not null references public.staff_profiles(id) on delete cascade,
 name text not null, storage_path text not null, document_type text, mime_type text, size_bytes bigint, uploaded_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.media_assets (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, storage_path text not null, file_name text not null,
 mime_type text, size_bytes bigint, alt_text text, width integer, height integer, folder text default 'general', uploaded_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);

-- ============================================================
-- 11-13 ADMISSIONS / PROMOTION / GRADING / REPORTS
-- ============================================================
create table if not exists public.admission_reviews (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, application_id uuid not null references public.admission_applications(id) on delete cascade,
 reviewer_id uuid references auth.users(id) on delete set null, stage text not null default 'review' check(stage in ('review','interview','assessment','decision','completed')),
 decision text check(decision in ('pending','accepted','waitlisted','rejected')), notes text, scheduled_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.promotion_runs (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, from_session_id uuid references public.academic_sessions(id) on delete set null,
 to_session_id uuid references public.academic_sessions(id) on delete set null, from_class_id uuid references public.classes(id) on delete set null, to_class_id uuid references public.classes(id) on delete set null,
 status text not null default 'draft' check(status in ('draft','previewed','approved','applied','rolled_back')), approved_by uuid references auth.users(id) on delete set null, applied_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.grading_rules (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, grading_scale_id uuid references public.grading_scales(id) on delete cascade,
 min_score numeric(6,2) not null, max_score numeric(6,2) not null, grade text not null, remark text, grade_point numeric(6,2), unique(grading_scale_id,grade)
);
create table if not exists public.report_card_templates (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, name text not null, is_default boolean not null default false,
 layout jsonb not null default '{}'::jsonb, show_position boolean not null default true, show_attendance boolean not null default true, show_comments boolean not null default true, created_at timestamptz not null default now()
);

-- ============================================================
-- 14-18 FINANCE / BILLING / LEDGER
-- ============================================================
create table if not exists public.fee_adjustments (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, invoice_id uuid not null references public.fee_invoices(id) on delete cascade,
 adjustment_type text not null check(adjustment_type in ('discount','scholarship','waiver','credit','penalty')), amount numeric(12,2) not null check(amount>=0), reason text, approved_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.payment_refunds (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, payment_id uuid not null references public.payments(id) on delete cascade,
 amount numeric(12,2) not null check(amount>0), reason text, provider_reference text, status text not null default 'pending' check(status in ('pending','processing','successful','failed')), created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.finance_ledger_entries (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, entry_type text not null, reference_type text, reference_id uuid, description text,
 debit numeric(12,2) not null default 0, credit numeric(12,2) not null default 0, entry_date timestamptz not null default now(), created_by uuid references auth.users(id) on delete set null
);
create table if not exists public.subscription_plan_changes (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, from_plan text, to_plan text not null, effective_at timestamptz, reason text, provider_reference text, created_at timestamptz not null default now()
);

-- ============================================================
-- 19-24 PLATFORM / GOVERNANCE / BACKUPS / SUPPORT
-- ============================================================
create table if not exists public.platform_feature_flags (
 id uuid primary key default gen_random_uuid(), feature_key text unique not null, description text, enabled boolean not null default false, rollout jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now()
);
create table if not exists public.platform_support_tickets (
 id uuid primary key default gen_random_uuid(), school_id uuid references public.schools(id) on delete set null, user_id uuid references auth.users(id) on delete set null,
 subject text not null, description text not null, priority text not null default 'normal' check(priority in ('low','normal','high','urgent')), status text not null default 'open' check(status in ('open','in_progress','waiting','resolved','closed')),
 assigned_to uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.support_ticket_messages (
 id uuid primary key default gen_random_uuid(), ticket_id uuid not null references public.platform_support_tickets(id) on delete cascade, user_id uuid references auth.users(id) on delete set null,
 body text not null, internal boolean not null default false, created_at timestamptz not null default now()
);
create table if not exists public.data_exports (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, requested_by uuid references auth.users(id) on delete set null,
 export_type text not null, status text not null default 'queued' check(status in ('queued','processing','ready','failed','expired')), storage_path text, expires_at timestamptz, created_at timestamptz not null default now(), completed_at timestamptz
);
create table if not exists public.deletion_requests (
 id uuid primary key default gen_random_uuid(), school_id uuid references public.schools(id) on delete cascade, requested_by uuid references auth.users(id) on delete set null,
 subject_type text not null, subject_id uuid, reason text, status text not null default 'requested' check(status in ('requested','reviewing','approved','rejected','completed')), legal_hold boolean not null default false,
 reviewed_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), completed_at timestamptz
);
create table if not exists public.consent_records (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, student_id uuid references public.students(id) on delete cascade,
 guardian_user_id uuid references auth.users(id) on delete set null, consent_type text not null, status text not null check(status in ('granted','withdrawn','pending')), evidence jsonb not null default '{}'::jsonb, granted_at timestamptz, withdrawn_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.retention_policies (
 id uuid primary key default gen_random_uuid(), school_id uuid references public.schools(id) on delete cascade, data_type text not null, retention_days integer not null check(retention_days>=0), legal_basis text, enabled boolean not null default true, created_at timestamptz not null default now(), unique(school_id,data_type)
);
create table if not exists public.backup_operations (
 id uuid primary key default gen_random_uuid(), school_id uuid references public.schools(id) on delete cascade, backup_type text not null, status text not null default 'planned', provider text, external_reference text, started_at timestamptz, completed_at timestamptz, error text, created_at timestamptz not null default now()
);
create table if not exists public.login_events (
 id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete cascade, ip_hash text, user_agent text, success boolean not null, failure_reason text, created_at timestamptz not null default now()
);

-- ============================================================
-- 25-36 IMPORTS / AUDIT / HEALTH / ACCESSIBILITY SUPPORT
-- ============================================================
create table if not exists public.import_jobs (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, requested_by uuid references auth.users(id) on delete set null,
 entity_type text not null, file_name text, storage_path text, status text not null default 'queued' check(status in ('queued','processing','completed','failed','cancelled')),
 total_rows integer default 0, processed_rows integer default 0, failed_rows integer default 0, errors jsonb not null default '[]'::jsonb, created_at timestamptz not null default now(), completed_at timestamptz
);
create table if not exists public.school_health_snapshots (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, active_users integer default 0, attendance_usage numeric(5,2) default 0,
 results_usage numeric(5,2) default 0, fee_usage numeric(5,2) default 0, cbt_usage numeric(5,2) default 0, parent_activation numeric(5,2) default 0, support_open integer default 0, captured_at timestamptz not null default now()
);
create table if not exists public.accessibility_preferences (
 user_id uuid primary key references auth.users(id) on delete cascade, reduced_motion boolean not null default false, high_contrast boolean not null default false, text_scale numeric(4,2) not null default 1.0, updated_at timestamptz not null default now()
);
create table if not exists public.school_domains (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade, hostname text unique not null, status text not null default 'pending' check(status in ('pending','verified','active','disabled')), verification_token text, verified_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.system_incidents (
 id uuid primary key default gen_random_uuid(), title text not null, description text, severity text not null default 'minor' check(severity in ('minor','major','critical')), status text not null default 'investigating' check(status in ('investigating','identified','monitoring','resolved')),
 started_at timestamptz not null default now(), resolved_at timestamptz, created_at timestamptz not null default now()
);

-- ============================================================
-- COMMON SECURITY HELPERS / RLS
-- ============================================================
create or replace function public.is_platform_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.platform_admins where user_id=auth.uid()); $$;
revoke all on function public.is_platform_admin() from public,anon; grant execute on function public.is_platform_admin() to authenticated;

do $$
declare t text; arr text[] := array['assignments','assignment_submissions','school_events','ai_generation_jobs','notification_deliveries','integration_connections','webhook_events','push_subscriptions','student_documents','teacher_documents','media_assets','admission_reviews','promotion_runs','grading_rules','report_card_templates','fee_adjustments','payment_refunds','finance_ledger_entries','subscription_plan_changes','platform_support_tickets','support_ticket_messages','data_exports','deletion_requests','consent_records','retention_policies','backup_operations','import_jobs','school_health_snapshots','school_domains'];
begin
 foreach t in array arr loop execute format('alter table public.%I enable row level security',t); end loop;
end $$;

-- Tenant-scoped policies are intentionally role-aware. Parent/student rows are read-only where applicable.
drop policy if exists assignments_school_access on public.assignments; create policy assignments_school_access on public.assignments for all to authenticated using(public.is_school_member(school_id)) with check(public.is_school_member(school_id));
drop policy if exists assignment_submissions_school_access on public.assignment_submissions; create policy assignment_submissions_school_access on public.assignment_submissions for all to authenticated using(public.is_school_member(school_id) or public.is_linked_student(school_id,student_id) or public.is_linked_guardian(school_id,student_id)) with check(public.is_school_member(school_id) or public.is_linked_student(school_id,student_id));
drop policy if exists school_events_access on public.school_events; create policy school_events_access on public.school_events for all to authenticated using(public.is_school_member(school_id)) with check(public.is_school_member(school_id));
drop policy if exists ai_jobs_access on public.ai_generation_jobs; create policy ai_jobs_access on public.ai_generation_jobs for all to authenticated using(public.is_school_member(school_id)) with check(public.is_school_member(school_id));
drop policy if exists notification_delivery_access on public.notification_deliveries; create policy notification_delivery_access on public.notification_deliveries for select to authenticated using(public.is_school_member(school_id));
drop policy if exists integration_admin_access on public.integration_connections; create policy integration_admin_access on public.integration_connections for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
drop policy if exists webhook_admin_access on public.webhook_events; create policy webhook_admin_access on public.webhook_events for select to authenticated using(school_id is null or public.is_school_admin(school_id));
drop policy if exists push_self_access on public.push_subscriptions; create policy push_self_access on public.push_subscriptions for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists student_docs_access on public.student_documents; create policy student_docs_access on public.student_documents for all to authenticated using(public.is_school_member(school_id) or public.is_linked_student(school_id,student_id) or public.is_linked_guardian(school_id,student_id)) with check(public.is_school_member(school_id));
drop policy if exists teacher_docs_access on public.teacher_documents; create policy teacher_docs_access on public.teacher_documents for all to authenticated using(public.is_school_member(school_id)) with check(public.is_school_member(school_id));
drop policy if exists media_assets_access on public.media_assets; create policy media_assets_access on public.media_assets for all to authenticated using(public.is_school_member(school_id)) with check(public.is_school_member(school_id));
drop policy if exists admissions_review_admin on public.admission_reviews; create policy admissions_review_admin on public.admission_reviews for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
drop policy if exists promotion_runs_admin on public.promotion_runs; create policy promotion_runs_admin on public.promotion_runs for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
drop policy if exists grading_rules_admin on public.grading_rules; create policy grading_rules_admin on public.grading_rules for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
drop policy if exists report_templates_admin on public.report_card_templates; create policy report_templates_admin on public.report_card_templates for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
drop policy if exists fee_adjustments_finance on public.fee_adjustments; create policy fee_adjustments_finance on public.fee_adjustments for all to authenticated using(public.is_school_finance_staff(school_id)) with check(public.is_school_finance_staff(school_id));
drop policy if exists refunds_finance on public.payment_refunds; create policy refunds_finance on public.payment_refunds for all to authenticated using(public.is_school_finance_staff(school_id)) with check(public.is_school_finance_staff(school_id));
drop policy if exists ledger_finance on public.finance_ledger_entries; create policy ledger_finance on public.finance_ledger_entries for all to authenticated using(public.is_school_finance_staff(school_id)) with check(public.is_school_finance_staff(school_id));
drop policy if exists plan_changes_admin on public.subscription_plan_changes; create policy plan_changes_admin on public.subscription_plan_changes for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
drop policy if exists support_access on public.platform_support_tickets; create policy support_access on public.platform_support_tickets for all to authenticated using(school_id is null or public.is_school_member(school_id) or user_id=auth.uid() or public.is_platform_admin()) with check(school_id is null or public.is_school_member(school_id) or public.is_platform_admin());
drop policy if exists support_messages_access on public.support_ticket_messages; create policy support_messages_access on public.support_ticket_messages for all to authenticated using(exists(select 1 from public.platform_support_tickets t where t.id=ticket_id and (t.user_id=auth.uid() or public.is_school_member(t.school_id) or public.is_platform_admin()))) with check(user_id=auth.uid());
drop policy if exists exports_admin on public.data_exports; create policy exports_admin on public.data_exports for all to authenticated using(public.is_school_admin(school_id) or requested_by=auth.uid()) with check(public.is_school_admin(school_id) or requested_by=auth.uid());
drop policy if exists deletion_admin on public.deletion_requests; create policy deletion_admin on public.deletion_requests for all to authenticated using(public.is_school_admin(school_id) or requested_by=auth.uid()) with check(public.is_school_admin(school_id) or requested_by=auth.uid());
drop policy if exists consent_access on public.consent_records; create policy consent_access on public.consent_records for all to authenticated using(public.is_school_member(school_id) or guardian_user_id=auth.uid()) with check(public.is_school_member(school_id) or guardian_user_id=auth.uid());
drop policy if exists retention_admin on public.retention_policies; create policy retention_admin on public.retention_policies for all to authenticated using(school_id is null or public.is_school_admin(school_id)) with check(school_id is null or public.is_school_admin(school_id));
drop policy if exists backup_admin on public.backup_operations; create policy backup_admin on public.backup_operations for all to authenticated using(school_id is null or public.is_platform_admin() or public.is_school_admin(school_id)) with check(school_id is null or public.is_platform_admin() or public.is_school_admin(school_id));
drop policy if exists imports_admin on public.import_jobs; create policy imports_admin on public.import_jobs for all to authenticated using(public.is_school_admin(school_id) or requested_by=auth.uid()) with check(public.is_school_admin(school_id) or requested_by=auth.uid());
drop policy if exists health_admin on public.school_health_snapshots; create policy health_admin on public.school_health_snapshots for select to authenticated using(public.is_school_admin(school_id) or public.is_platform_admin());
drop policy if exists domains_admin on public.school_domains; create policy domains_admin on public.school_domains for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));

-- Platform-only tables
alter table public.platform_feature_flags enable row level security;
drop policy if exists platform_flags_admin on public.platform_feature_flags; create policy platform_flags_admin on public.platform_feature_flags for all to authenticated using(public.is_platform_admin()) with check(public.is_platform_admin());
alter table public.system_incidents enable row level security;
drop policy if exists incidents_read on public.system_incidents; create policy incidents_read on public.system_incidents for select to authenticated using(true);

-- Indexes
create index if not exists idx_assignments_school_due on public.assignments(school_id,due_at desc);
create index if not exists idx_submissions_student on public.assignment_submissions(school_id,student_id,submitted_at desc);
create index if not exists idx_events_school_time on public.school_events(school_id,starts_at);
create index if not exists idx_delivery_status on public.notification_deliveries(school_id,status,created_at desc);
create index if not exists idx_import_status on public.import_jobs(school_id,status,created_at desc);
create index if not exists idx_support_school_status on public.platform_support_tickets(school_id,status,created_at desc);

-- Updated-at helper for new mutable tables
create or replace function public.touch_edvora_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;
do $$ declare t text; begin foreach t in array array['assignments','assignment_submissions','school_events','integration_connections','platform_support_tickets'] loop execute format('drop trigger if exists %I_touch on public.%I',t,t); execute format('create trigger %I_touch before update on public.%I for each row execute function public.touch_edvora_updated_at()',t,t); end loop; end $$;

-- Parent-link and crypto functions are independent of pgcrypto's gen_random_bytes().
-- gen_random_uuid() is already used throughout this schema and is supported by Supabase Postgres.

-- V12 security hardening: separate read access from write access for assignments/events.
alter table public.assignments enable row level security;
drop policy if exists assignments_school_access on public.assignments;
drop policy if exists assignments_read on public.assignments;
drop policy if exists assignments_manage on public.assignments;
create policy assignments_read on public.assignments for select to authenticated
  using(public.is_school_member(school_id));
create policy assignments_manage on public.assignments for insert to authenticated
  with check(public.is_school_admin(school_id) or (public.is_school_teacher(school_id) and teacher_id=auth.uid()));
create policy assignments_update on public.assignments for update to authenticated
  using(public.is_school_admin(school_id) or (public.is_school_teacher(school_id) and teacher_id=auth.uid()))
  with check(public.is_school_admin(school_id) or (public.is_school_teacher(school_id) and teacher_id=auth.uid()));
create policy assignments_delete on public.assignments for delete to authenticated
  using(public.is_school_admin(school_id) or (public.is_school_teacher(school_id) and teacher_id=auth.uid()));

alter table public.school_events enable row level security;
drop policy if exists school_events_access on public.school_events;
create policy school_events_read on public.school_events for select to authenticated using(public.is_school_member(school_id));
create policy school_events_manage on public.school_events for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
