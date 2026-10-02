-- EDVORA COMPLETE DATABASE
-- Single install file for a fresh Supabase project.
-- Tenant model: one school = one tenant = one campus.
-- Run this entire file once in Supabase SQL Editor.

-- V2 CORE
-- EDVORA MULTI-TENANT ARCHITECTURE V2
-- Tenant model:
--   1 school = 1 tenant = 1 campus
-- There is deliberately NO campus table and NO multi-campus hierarchy.
-- Each school has its own subscription/billing lifecycle.

create extension if not exists pgcrypto;

-- ============================================================
-- IDENTITY
-- ============================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- A school is the tenant boundary.
create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  school_type text not null default 'private_school',
  slug text unique,
  logo_path text,
  timezone text not null default 'Africa/Lagos',
  currency text not null default 'NGN',
  status text not null default 'active'
    check (status in ('active','trialing','suspended','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- A user may belong to more than one independent school,
-- but every membership belongs to exactly one school.
create table if not exists public.school_memberships (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null
    check (role in ('owner','admin','bursar','teacher','staff')),
  status text not null default 'active'
    check (status in ('invited','active','suspended')),
  created_at timestamptz not null default now(),
  unique (school_id, user_id)
);

create table if not exists public.school_invitations (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  email text not null,
  role text not null
    check (role in ('admin','bursar','teacher','staff')),
  token_hash text unique not null,
  invited_by uuid references auth.users(id) on delete set null,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  created_at timestamptz not null default now()
);

-- ============================================================
-- SCHOOL CONFIGURATION
-- ============================================================

create table if not exists public.school_settings (
  school_id uuid primary key references public.schools(id) on delete cascade,
  current_session text,
  current_term text,
  grading_scale jsonb not null default '[]'::jsonb,
  settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- ============================================================
-- ACADEMICS
-- ============================================================

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  level text,
  created_at timestamptz not null default now(),
  unique (school_id, name)
);

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  code text,
  created_at timestamptz not null default now(),
  unique (school_id, name)
);

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  class_id uuid references public.classes(id) on delete set null,
  admission_number text,
  first_name text not null,
  last_name text not null,
  gender text,
  date_of_birth date,
  status text not null default 'active'
    check (status in ('active','graduated','withdrawn','inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, admission_number)
);

-- Automatically assign a school-scoped admission number when one is not supplied.
-- Format: ADM-YYYY-0001, ADM-YYYY-0002, ...
create or replace function public.assign_admission_number()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  target_year integer := extract(year from current_date)::integer;
  next_number bigint;
  prefix text := 'ADM-' || target_year::text || '-';
begin
  if nullif(trim(new.admission_number), '') is not null then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtextextended(new.school_id::text, 0));
  select coalesce(max((substring(admission_number from '^ADM-[0-9]{4}-([0-9]+)$'))::bigint),0) + 1
    into next_number
    from public.students
   where school_id=new.school_id
     and admission_number like prefix || '%';
  new.admission_number := prefix || lpad(next_number::text,4,'0');
  return new;
end;
$$;

if not exists(select 1 from pg_trigger where tgname='students_admission_number') then
  create trigger students_admission_number before insert on public.students
  for each row execute function public.assign_admission_number();
end if;

create table if not exists public.student_guardians (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  full_name text,
  email text,
  phone text,
  relationship text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.academic_sessions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  starts_on date,
  ends_on date,
  is_current boolean not null default false,
  created_at timestamptz not null default now(),
  unique (school_id, name)
);

create table if not exists public.academic_terms (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  session_id uuid not null references public.academic_sessions(id) on delete cascade,
  name text not null,
  starts_on date,
  ends_on date,
  is_current boolean not null default false,
  created_at timestamptz not null default now()
);

-- ============================================================
-- ATTENDANCE / RESULTS / CBT
-- ============================================================

create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  class_id uuid references public.classes(id) on delete set null,
  attendance_date date not null,
  status text not null check (status in ('present','absent','late','excused')),
  marked_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (school_id, student_id, attendance_date)
);

create table if not exists public.assessments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  session_id uuid references public.academic_sessions(id) on delete set null,
  term_id uuid references public.academic_terms(id) on delete set null,
  class_id uuid references public.classes(id) on delete set null,
  subject_id uuid references public.subjects(id) on delete set null,
  title text not null,
  assessment_type text not null default 'exam',
  max_score numeric(8,2) not null default 100,
  created_at timestamptz not null default now()
);

create table if not exists public.assessment_scores (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  score numeric(8,2),
  teacher_comment text,
  created_at timestamptz not null default now(),
  unique (school_id, assessment_id, student_id)
);

create table if not exists public.cbt_exams (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  class_id uuid references public.classes(id) on delete set null,
  subject_id uuid references public.subjects(id) on delete set null,
  title text not null,
  duration_minutes integer not null,
  starts_at timestamptz,
  ends_at timestamptz,
  status text not null default 'draft'
    check (status in ('draft','scheduled','live','closed')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.cbt_questions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  exam_id uuid not null references public.cbt_exams(id) on delete cascade,
  question_text text not null,
  question_type text not null default 'multiple_choice',
  options jsonb not null default '[]'::jsonb,
  correct_answer text,
  points numeric(8,2) not null default 1,
  position integer not null default 1,
  created_at timestamptz not null default now()
);

-- ============================================================
-- FINANCE
-- ============================================================

create table if not exists public.fee_structures (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  amount numeric(14,2) not null check (amount >= 0),
  session_id uuid references public.academic_sessions(id) on delete set null,
  term_id uuid references public.academic_terms(id) on delete set null,
  class_id uuid references public.classes(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.fee_invoices (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  title text not null default 'School fees',
  amount numeric(14,2) not null check (amount >= 0),
  amount_paid numeric(14,2) not null default 0 check (amount_paid >= 0),
  due_date date,
  status text not null default 'outstanding'
    check (status in ('draft','outstanding','partially_paid','paid','void')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid references public.students(id) on delete set null,
  invoice_id uuid references public.fee_invoices(id) on delete set null,
  amount numeric(14,2) not null check (amount > 0),
  provider text,
  provider_reference text,
  status text not null default 'pending'
    check (status in ('pending','successful','failed','refunded')),
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

-- One subscription per school/tenant.
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  plan_code text not null,
  status text not null
    check (status in ('trialing','active','past_due','cancelled','expired')),
  provider text,
  provider_customer_id text,
  provider_subscription_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id)
);

create table if not exists public.subscription_events (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  provider text,
  event_type text not null,
  provider_event_id text unique,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ============================================================
-- COMMUNICATION / AUDIT
-- ============================================================

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  title text not null,
  body text not null,
  audience text not null default 'all',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ============================================================
-- PLATFORM ADMIN
-- ============================================================

-- Platform admins are NOT school memberships.
create table if not exists public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- ============================================================
-- TENANT SECURITY HELPERS
-- ============================================================

create or replace function public.is_school_member(target_school_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.school_memberships sm
    where sm.school_id = target_school_id
      and sm.user_id = auth.uid()
      and sm.status = 'active'
  );
$$;

create or replace function public.school_role(target_school_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select sm.role
  from public.school_memberships sm
  where sm.school_id = target_school_id
    and sm.user_id = auth.uid()
    and sm.status = 'active'
  limit 1;
$$;

create or replace function public.is_school_admin(target_school_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.school_role(target_school_id) in ('owner','admin');
$$;

create or replace function public.is_school_finance_staff(target_school_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.school_role(target_school_id) in ('owner','admin','bursar');
$$;

-- ============================================================
-- SCHOOL CREATION
-- ============================================================

create or replace function public.create_school(
  school_name text,
  school_type text default 'private_school'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_school_id uuid;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in';
  end if;

  if trim(coalesce(school_name,'')) = '' then
    raise exception 'School name is required';
  end if;

  insert into public.schools(name, school_type)
  values (trim(school_name), coalesce(school_type,'private_school'))
  returning id into new_school_id;

  insert into public.school_memberships(school_id,user_id,role,status)
  values (new_school_id, auth.uid(), 'owner', 'active');

  insert into public.school_settings(school_id)
  values (new_school_id);

  return new_school_id;
end;
$$;

revoke all on function public.create_school(text,text) from public;
grant execute on function public.create_school(text,text) to authenticated;

-- ============================================================
-- RLS
-- ============================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'schools','school_memberships','school_invitations','school_settings',
    'classes','subjects','students','student_guardians',
    'academic_sessions','academic_terms','attendance_records',
    'assessments','assessment_scores','cbt_exams','cbt_questions',
    'fee_structures','fee_invoices','payments',
    'subscriptions','subscription_events','announcements','audit_logs'
  ] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- The following policies use the tenant boundary directly.
-- Platform admins are handled separately and should use server-side/admin tooling
-- for platform-wide operations rather than bypassing tenant RLS in browser code.

create policy "school members read school"
on public.schools for select to authenticated
using (public.is_school_member(id));

create policy "school admins update school"
on public.schools for update to authenticated
using (public.is_school_admin(id))
with check (public.is_school_admin(id));

create policy "users read own memberships"
on public.school_memberships for select to authenticated
using (user_id = auth.uid());

create policy "members read own school memberships"
on public.school_memberships for select to authenticated
using (public.is_school_member(school_id));

-- Generic school-scoped policies for operational tables.
create policy "members manage classes"
on public.classes for all to authenticated
using (public.is_school_member(school_id))
with check (public.is_school_member(school_id));

create policy "members manage subjects"
on public.subjects for all to authenticated
using (public.is_school_member(school_id))
with check (public.is_school_member(school_id));

create policy "members manage students"
on public.students for all to authenticated
using (public.is_school_member(school_id))
with check (public.is_school_member(school_id));

create policy "members manage guardians"
on public.student_guardians for all to authenticated
using (public.is_school_member(school_id))
with check (public.is_school_member(school_id));

create policy "members manage sessions"
on public.academic_sessions for all to authenticated
using (public.is_school_member(school_id))
with check (public.is_school_member(school_id));

create policy "members manage terms"
on public.academic_terms for all to authenticated
using (public.is_school_member(school_id))
with check (public.is_school_member(school_id));

create policy "members manage attendance"
on public.attendance_records for all to authenticated
using (public.is_school_member(school_id))
with check (public.is_school_member(school_id));

create policy "members manage assessments"
on public.assessments for all to authenticated
using (public.is_school_member(school_id))
with check (public.is_school_member(school_id));

create policy "members manage scores"
on public.assessment_scores for all to authenticated
using (public.is_school_member(school_id))
with check (public.is_school_member(school_id));

create policy "members manage cbt exams"
on public.cbt_exams for all to authenticated
using (public.is_school_member(school_id))
with check (public.is_school_member(school_id));

create policy "members manage cbt questions"
on public.cbt_questions for all to authenticated
using (public.is_school_member(school_id))
with check (public.is_school_member(school_id));

create policy "members read settings"
on public.school_settings for select to authenticated
using (public.is_school_member(school_id));

create policy "admins update settings"
on public.school_settings for update to authenticated
using (public.is_school_admin(school_id))
with check (public.is_school_admin(school_id));

create policy "finance staff manage fee structures"
on public.fee_structures for all to authenticated
using (public.is_school_finance_staff(school_id))
with check (public.is_school_finance_staff(school_id));

create policy "finance staff manage invoices"
on public.fee_invoices for all to authenticated
using (public.is_school_finance_staff(school_id))
with check (public.is_school_finance_staff(school_id));

create policy "finance staff manage payments"
on public.payments for all to authenticated
using (public.is_school_finance_staff(school_id))
with check (public.is_school_finance_staff(school_id));

create policy "members read subscriptions"
on public.subscriptions for select to authenticated
using (public.is_school_member(school_id));

create policy "members read subscription events"
on public.subscription_events for select to authenticated
using (public.is_school_member(school_id));

create policy "members manage announcements"
on public.announcements for all to authenticated
using (public.is_school_member(school_id))
with check (public.is_school_member(school_id));

create policy "members read audit logs"
on public.audit_logs for select to authenticated
using (public.is_school_member(school_id));

-- Indexes for tenant isolation and common queries.
create index if not exists idx_memberships_user_school
  on public.school_memberships(user_id, school_id);

create index if not exists idx_students_school_class
  on public.students(school_id, class_id);

create index if not exists idx_classes_school
  on public.classes(school_id);

create index if not exists idx_subjects_school
  on public.subjects(school_id);

create index if not exists idx_invoices_school_student
  on public.fee_invoices(school_id, student_id);

create index if not exists idx_payments_school
  on public.payments(school_id);

create index if not exists idx_subscriptions_school
  on public.subscriptions(school_id);

create index if not exists idx_audit_school_created
  on public.audit_logs(school_id, created_at desc);


-- V3 PRODUCTION
-- EDVORA V3 PRODUCTION EXTENSION
-- Single-school tenant model. One school = one tenant = one campus.
-- Run after schema-v2-single-campus.sql.

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- Staff and teaching assignments
-- ------------------------------------------------------------
create table if not exists public.staff_profiles (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  full_name text not null,
  email text,
  phone text,
  staff_type text not null default 'teacher' check (staff_type in ('teacher','admin','bursar','staff')),
  employee_number text,
  department text,
  status text not null default 'active' check (status in ('active','inactive','invited')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, employee_number)
);

create table if not exists public.teacher_class_assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  teacher_user_id uuid not null references auth.users(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (school_id, teacher_user_id, class_id)
);

create table if not exists public.teacher_subject_assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  teacher_user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  class_id uuid references public.classes(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (school_id, teacher_user_id, subject_id, class_id)
);

create table if not exists public.student_enrollments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  session_id uuid references public.academic_sessions(id) on delete set null,
  enrolled_on date not null default current_date,
  ended_on date,
  is_current boolean not null default true,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- Parent / student account linking
-- ------------------------------------------------------------
create table if not exists public.student_accounts (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active' check (status in ('active','suspended')),
  created_at timestamptz not null default now(),
  unique (school_id, student_id),
  unique (school_id, user_id)
);

-- ------------------------------------------------------------
-- Results and report cards
-- ------------------------------------------------------------
create table if not exists public.report_cards (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  session_id uuid references public.academic_sessions(id) on delete set null,
  term_id uuid references public.academic_terms(id) on delete set null,
  teacher_comment text,
  principal_comment text,
  status text not null default 'draft' check (status in ('draft','review','published')),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- CBT attempts and answers
-- ------------------------------------------------------------
create table if not exists public.cbt_attempts (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  exam_id uuid not null references public.cbt_exams(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  status text not null default 'in_progress' check (status in ('in_progress','submitted','graded','expired')),
  score numeric(10,2),
  max_score numeric(10,2),
  unique (school_id, exam_id, student_id)
);

create table if not exists public.cbt_answers (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  attempt_id uuid not null references public.cbt_attempts(id) on delete cascade,
  question_id uuid not null references public.cbt_questions(id) on delete cascade,
  answer text,
  awarded_points numeric(10,2) default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (attempt_id, question_id)
);

-- ------------------------------------------------------------
-- Notifications and communication
-- ------------------------------------------------------------
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  type text not null default 'general',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.message_threads (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  subject text not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.message_participants (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  thread_id uuid not null references public.message_threads(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (thread_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  thread_id uuid not null references public.message_threads(id) on delete cascade,
  sender_user_id uuid references auth.users(id) on delete set null,
  body text not null,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- School website / white label
-- ------------------------------------------------------------
create table if not exists public.website_settings (
  school_id uuid primary key references public.schools(id) on delete cascade,
  is_published boolean not null default false,
  headline text,
  subheadline text,
  hero_image_path text,
  primary_color text not null default '#3882F6',
  accent_color text not null default '#A3E635',
  contact_email text,
  contact_phone text,
  address text,
  welcome_message text,
  updated_at timestamptz not null default now()
);

create table if not exists public.website_pages (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  slug text not null,
  title text not null,
  body text not null default '',
  published boolean not null default true,
  updated_at timestamptz not null default now(),
  unique (school_id, slug)
);

create table if not exists public.website_submissions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  type text not null default 'contact',
  name text,
  email text,
  phone text,
  message text,
  status text not null default 'new' check (status in ('new','contacted','closed')),
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- Finance receipts / provider metadata
-- ------------------------------------------------------------
alter table public.payments add column if not exists payment_method text;
alter table public.payments add column if not exists metadata jsonb not null default '{}'::jsonb;
alter table public.payments add column if not exists receipt_number text;
alter table public.payments add column if not exists paid_by uuid references auth.users(id) on delete set null;

-- ------------------------------------------------------------
-- Subscription plans and usage controls
-- ------------------------------------------------------------
create table if not exists public.subscription_plans (
  code text primary key,
  name text not null,
  monthly_amount numeric(14,2) not null default 0,
  yearly_amount numeric(14,2) not null default 0,
  features jsonb not null default '[]'::jsonb,
  limits jsonb not null default '{}'::jsonb,
  active boolean not null default true
);

insert into public.subscription_plans(code,name,monthly_amount,yearly_amount,features,limits)
values
('starter','Starter',15000,150000,'["Students","Classes","Attendance","Fees"]','{"students":300,"staff":10}'),
('growth','Growth',30000,300000,'["Everything in Starter","Results","CBT","Parent portal","Reports"]','{"students":1000,"staff":50}'),
('professional','Professional',60000,600000,'["Everything in Growth","White-label website","Advanced reports","Priority support"]','{"students":5000,"staff":150}'),
('enterprise','Enterprise',0,0,'["Custom limits","Custom integrations","Dedicated support"]','{"students":-1,"staff":-1}')
on conflict (code) do update set name=excluded.name, monthly_amount=excluded.monthly_amount, yearly_amount=excluded.yearly_amount, features=excluded.features, limits=excluded.limits;

-- ------------------------------------------------------------
-- Helper functions
-- ------------------------------------------------------------
create or replace function public.is_school_staff(target_school_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.school_role(target_school_id) in ('owner','admin','bursar','teacher','staff');
$$;

create or replace function public.is_school_teacher(target_school_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.school_role(target_school_id) = 'teacher';
$$;

create or replace function public.can_manage_academics(target_school_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.school_role(target_school_id) in ('owner','admin','teacher');
$$;

create or replace function public.is_linked_guardian(target_school_id uuid, target_student_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.student_guardians g where g.school_id=target_school_id and g.student_id=target_student_id and g.user_id=auth.uid())
      or exists(select 1 from public.student_accounts a where a.school_id=target_school_id and a.student_id=target_student_id and a.user_id=auth.uid());
$$;

create or replace function public.is_linked_student(target_school_id uuid, target_student_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.student_accounts a where a.school_id=target_school_id and a.student_id=target_student_id and a.user_id=auth.uid() and a.status='active');
$$;

-- ------------------------------------------------------------
-- RLS hardening. Drop broad policies and replace with role-aware ones.
-- ------------------------------------------------------------

-- memberships: only school admins may create/update memberships; users can read their own.
drop policy if exists "members read own school memberships" on public.school_memberships;
drop policy if exists "users read own memberships" on public.school_memberships;
create policy "memberships own or admin read" on public.school_memberships for select to authenticated
using (user_id=auth.uid() or public.is_school_admin(school_id));

-- Students: staff may read; admins/staff can manage, teachers can only manage assigned classes.
drop policy if exists "members manage students" on public.students;
drop policy if exists "students scoped read" on public.students;
drop policy if exists "students admins manage" on public.students;
drop policy if exists "students teachers manage assigned" on public.students;
create policy "students scoped read" on public.students for select to authenticated
using (public.is_school_member(school_id) or public.is_linked_guardian(school_id,id) or public.is_linked_student(school_id,id));
create policy "students admins manage" on public.students for all to authenticated
using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
create policy "students teachers manage assigned" on public.students for update to authenticated
using (public.is_school_teacher(students.school_id) and exists(select 1 from public.teacher_class_assignments a where a.school_id=students.school_id and a.teacher_user_id=auth.uid() and a.class_id=students.class_id))
with check (public.is_school_teacher(students.school_id));

-- Academics
 drop policy if exists "members manage attendance" on public.attendance_records;
create policy "attendance read scoped" on public.attendance_records for select to authenticated
using (public.is_school_member(school_id) or public.is_linked_guardian(school_id,student_id) or public.is_linked_student(school_id,student_id));
create policy "attendance manage admins teachers" on public.attendance_records for insert to authenticated
with check (public.can_manage_academics(school_id));
create policy "attendance update admins teachers" on public.attendance_records for update to authenticated
using (public.can_manage_academics(school_id)) with check (public.can_manage_academics(school_id));

 drop policy if exists "members manage assessments" on public.assessments;
create policy "assessments read scoped" on public.assessments for select to authenticated using (public.is_school_member(school_id));
create policy "assessments manage academics" on public.assessments for all to authenticated using (public.can_manage_academics(school_id)) with check (public.can_manage_academics(school_id));

 drop policy if exists "members manage scores" on public.assessment_scores;
create policy "scores read scoped" on public.assessment_scores for select to authenticated
using (public.is_school_member(school_id) or public.is_linked_guardian(school_id,student_id) or public.is_linked_student(school_id,student_id));
create policy "scores manage academics" on public.assessment_scores for all to authenticated using (public.can_manage_academics(school_id)) with check (public.can_manage_academics(school_id));

-- CBT
 drop policy if exists "members manage cbt exams" on public.cbt_exams;
 drop policy if exists "members manage cbt questions" on public.cbt_questions;
create policy "cbt exams read school" on public.cbt_exams for select to authenticated using (public.is_school_member(school_id));
create policy "cbt exams manage admins teachers" on public.cbt_exams for all to authenticated using (public.can_manage_academics(school_id)) with check (public.can_manage_academics(school_id));
create policy "cbt questions read school" on public.cbt_questions for select to authenticated using (public.is_school_member(school_id));
create policy "cbt questions manage admins teachers" on public.cbt_questions for all to authenticated using (public.can_manage_academics(school_id)) with check (public.can_manage_academics(school_id));
create policy "cbt attempts own" on public.cbt_attempts for select to authenticated
using (public.is_school_member(school_id) or public.is_linked_student(school_id,student_id));
create policy "cbt attempts start" on public.cbt_attempts for insert to authenticated
with check (public.is_linked_student(school_id,student_id) or public.is_school_member(school_id));
create policy "cbt attempts update own" on public.cbt_attempts for update to authenticated
using (public.is_linked_student(school_id,student_id) or public.can_manage_academics(school_id))
with check (public.is_linked_student(school_id,student_id) or public.can_manage_academics(school_id));
create policy "cbt answers own" on public.cbt_answers for all to authenticated
using (exists(select 1 from public.cbt_attempts a where a.id=attempt_id and (public.is_linked_student(a.school_id,a.student_id) or public.can_manage_academics(a.school_id))))
with check (exists(select 1 from public.cbt_attempts a where a.id=attempt_id and (public.is_linked_student(a.school_id,a.student_id) or public.can_manage_academics(a.school_id))));

-- Parent/student records
alter table public.student_accounts enable row level security;
create policy "student accounts self or admin" on public.student_accounts for select to authenticated using (user_id=auth.uid() or public.is_school_admin(school_id));
create policy "student accounts admin manage" on public.student_accounts for all to authenticated using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));

-- Teachers
alter table public.staff_profiles enable row level security;
create policy "staff profiles school read" on public.staff_profiles for select to authenticated using (public.is_school_member(school_id));
create policy "staff profiles admins manage" on public.staff_profiles for all to authenticated using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
alter table public.teacher_class_assignments enable row level security;
create policy "teacher class assignments school read" on public.teacher_class_assignments for select to authenticated using (public.is_school_member(school_id));
create policy "teacher class assignments admins manage" on public.teacher_class_assignments for all to authenticated using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
alter table public.teacher_subject_assignments enable row level security;
create policy "teacher subject assignments school read" on public.teacher_subject_assignments for select to authenticated using (public.is_school_member(school_id));
create policy "teacher subject assignments admins manage" on public.teacher_subject_assignments for all to authenticated using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));

-- Reports
alter table public.report_cards enable row level security;
create policy "report cards scoped read" on public.report_cards for select to authenticated using (public.is_school_member(school_id) or public.is_linked_guardian(school_id,student_id) or public.is_linked_student(school_id,student_id));
create policy "report cards admins manage" on public.report_cards for all to authenticated using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));

-- Notifications
alter table public.notifications enable row level security;
create policy "notifications own" on public.notifications for select to authenticated using (user_id=auth.uid() or public.is_school_admin(school_id));
create policy "notifications admin create" on public.notifications for insert to authenticated with check (public.is_school_admin(school_id));
create policy "notifications own update" on public.notifications for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());

-- Messaging
alter table public.message_threads enable row level security;
alter table public.message_participants enable row level security;
alter table public.messages enable row level security;
create policy "threads participants read" on public.message_threads for select to authenticated using (public.is_school_member(school_id));
create policy "threads staff create" on public.message_threads for insert to authenticated with check (public.is_school_member(school_id));
create policy "participants school read" on public.message_participants for select to authenticated using (public.is_school_member(school_id));
create policy "participants staff manage" on public.message_participants for all to authenticated using (public.is_school_member(school_id)) with check (public.is_school_member(school_id));
create policy "messages school read" on public.messages for select to authenticated using (public.is_school_member(school_id));
create policy "messages staff create" on public.messages for insert to authenticated with check (public.is_school_member(school_id) and sender_user_id=auth.uid());

-- Website
alter table public.website_settings enable row level security;
alter table public.website_pages enable row level security;
alter table public.website_submissions enable row level security;
create policy "website settings admin" on public.website_settings for all to authenticated using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
create policy "website pages admin" on public.website_pages for all to authenticated using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
create policy "website submissions admin" on public.website_submissions for all to authenticated using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));

-- Finance receipts are finance-staff only for writes; members can read payment history through RLS already.

-- Subscription plan catalog is public-readable; only server/admin should mutate.
alter table public.subscription_plans enable row level security;
create policy "plans readable" on public.subscription_plans for select to anon, authenticated using (active=true);

-- Indexes
create index if not exists idx_staff_school on public.staff_profiles(school_id);
create index if not exists idx_teacher_classes on public.teacher_class_assignments(school_id,teacher_user_id);
create index if not exists idx_teacher_subjects on public.teacher_subject_assignments(school_id,teacher_user_id);
create index if not exists idx_enrollments_student on public.student_enrollments(school_id,student_id,is_current);
create index if not exists idx_attempts_student on public.cbt_attempts(school_id,student_id);
create index if not exists idx_notifications_user on public.notifications(school_id,user_id,created_at desc);
create index if not exists idx_messages_thread on public.messages(school_id,thread_id,created_at);
create index if not exists idx_website_pages_school on public.website_pages(school_id,slug);
create index if not exists idx_submissions_school on public.website_submissions(school_id,created_at desc);

-- Seed website settings for existing schools.
insert into public.website_settings(school_id,headline,subheadline)
select id, 'Nurturing learners for a brighter future', 'A modern school community built around learning, connection and progress.'
from public.schools
on conflict (school_id) do nothing;

-- Seed current subscription if a school has none. Keeps billing state explicit without charging anyone.
insert into public.subscriptions(school_id,plan_code,status)
select s.id,'starter','trialing' from public.schools s
where not exists(select 1 from public.subscriptions sub where sub.school_id=s.id);

-- ------------------------------------------------------------
-- Public website + storage
-- ------------------------------------------------------------
create or replace function public.slugify_school_name(input text)
returns text language sql immutable as $$
  select trim(both '-' from regexp_replace(lower(coalesce(input,'')), '[^a-z0-9]+', '-', 'g'));
$$;

create or replace function public.create_school(
  school_name text,
  school_type text default 'private_school'
)
returns uuid language plpgsql security definer set search_path=public as $$
declare
  new_school_id uuid;
  base_slug text;
  final_slug text;
  n integer := 0;
begin
  if auth.uid() is null then raise exception 'You must be signed in'; end if;
  if trim(coalesce(school_name,''))='' then raise exception 'School name is required'; end if;
  base_slug:=public.slugify_school_name(school_name);
  if base_slug='' then base_slug:='school'; end if;
  final_slug:=base_slug;
  while exists(select 1 from public.schools where slug=final_slug) loop
    n:=n+1; final_slug:=base_slug||'-'||n;
  end loop;
  insert into public.schools(name,school_type,slug) values(trim(school_name),coalesce(school_type,'private_school'),final_slug) returning id into new_school_id;
  insert into public.school_memberships(school_id,user_id,role,status) values(new_school_id,auth.uid(),'owner','active');
  insert into public.school_settings(school_id) values(new_school_id) on conflict do nothing;
  insert into public.website_settings(school_id,headline,subheadline) values(new_school_id,'Everything your school needs. One platform.','Smart infrastructure for modern schools.') on conflict do nothing;
  insert into public.subscriptions(school_id,plan_code,status) values(new_school_id,'starter','trialing') on conflict do nothing;
  return new_school_id;
end;
$$;
revoke all on function public.create_school(text,text) from public;
grant execute on function public.create_school(text,text) to authenticated;

-- Public website read access is intentionally limited to published schools/pages.
create policy "public published school" on public.schools for select to anon
using (status='active' and slug is not null);
create policy "public published website settings" on public.website_settings for select to anon
using (is_published=true);
create policy "public published website pages" on public.website_pages for select to anon
using (published=true and exists(select 1 from public.website_settings w where w.school_id=website_pages.school_id and w.is_published=true));

-- Private storage buckets. Uploads are constrained to a school path.
insert into storage.buckets(id,name,public) values
('school-branding','school-branding',true),('school-documents','school-documents',false),('school-student-media','school-student-media',false),('school-cbt','school-cbt',false)
on conflict (id) do nothing;

create policy "school storage read" on storage.objects for select to authenticated
using (bucket_id in ('school-branding','school-documents','school-student-media','school-cbt') and public.is_school_member((storage.foldername(name))[1]::uuid));
create policy "school storage write" on storage.objects for insert to authenticated
with check (bucket_id in ('school-branding','school-documents','school-student-media','school-cbt') and public.is_school_admin((storage.foldername(name))[1]::uuid));
create policy "school storage update" on storage.objects for update to authenticated
using (bucket_id in ('school-branding','school-documents','school-student-media','school-cbt') and public.is_school_admin((storage.foldername(name))[1]::uuid));
create policy "school storage delete" on storage.objects for delete to authenticated
using (bucket_id in ('school-branding','school-documents','school-student-media','school-cbt') and public.is_school_admin((storage.foldername(name))[1]::uuid));

-- ------------------------------------------------------------
-- Audit trigger for high-value operational changes
-- ------------------------------------------------------------
create or replace function public.write_audit_log()
returns trigger language plpgsql security definer set search_path=public as $$
declare sid uuid;
begin
  sid:=coalesce((to_jsonb(new)->>'school_id')::uuid,(to_jsonb(old)->>'school_id')::uuid);
  if sid is not null then
    insert into public.audit_logs(school_id,actor_user_id,action,entity_type,entity_id,metadata)
    values(sid,auth.uid(),lower(tg_op)||'.'||tg_table_name,tg_table_name,coalesce((to_jsonb(new)->>'id')::uuid,(to_jsonb(old)->>'id')::uuid),jsonb_build_object('table',tg_table_name));
  end if;
  return coalesce(new,old);
end;
$$;

do $$
begin
  if not exists(select 1 from pg_trigger where tgname='audit_students') then create trigger audit_students after insert or update or delete on public.students for each row execute function public.write_audit_log(); end if;
  if not exists(select 1 from pg_trigger where tgname='audit_payments') then create trigger audit_payments after insert or update or delete on public.payments for each row execute function public.write_audit_log(); end if;
  if not exists(select 1 from pg_trigger where tgname='audit_invoices') then create trigger audit_invoices after insert or update or delete on public.fee_invoices for each row execute function public.write_audit_log(); end if;
  if not exists(select 1 from pg_trigger where tgname='audit_assessment_scores') then create trigger audit_assessment_scores after insert or update or delete on public.assessment_scores for each row execute function public.write_audit_log(); end if;
  if not exists(select 1 from pg_trigger where tgname='audit_cbt_exams') then create trigger audit_cbt_exams after insert or update or delete on public.cbt_exams for each row execute function public.write_audit_log(); end if;
end $$;

-- Backfill slugs for schools created by the previous MVP.
do $$
declare r record; base text; candidate text; n integer;
begin
 for r in select id,name from public.schools where slug is null loop
   base:=public.slugify_school_name(r.name); if base='' then base:='school'; end if; candidate:=base; n:=0;
   while exists(select 1 from public.schools where slug=candidate and id<>r.id) loop n:=n+1; candidate:=base||'-'||n; end loop;
   update public.schools set slug=candidate where id=r.id;
 end loop;
end $$;

-- Portal read policies for linked parents/students.
drop policy if exists "members manage classes" on public.classes;
create policy "classes school staff read" on public.classes for select to authenticated
using (public.is_school_member(school_id) or exists(select 1 from public.student_accounts sa join public.students st on st.id=sa.student_id where sa.school_id=classes.school_id and sa.user_id=auth.uid() and st.class_id=classes.id) or exists(select 1 from public.student_guardians sg join public.students st on st.id=sg.student_id where sg.school_id=classes.school_id and sg.user_id=auth.uid() and st.class_id=classes.id));
create policy "classes admins manage" on public.classes for all to authenticated using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));

drop policy if exists "members manage subjects" on public.subjects;
create policy "subjects school read" on public.subjects for select to authenticated using (public.is_school_member(school_id) or exists(select 1 from public.assessment_scores sc where sc.school_id=subjects.school_id and sc.student_id in (select sg.student_id from public.student_guardians sg where sg.user_id=auth.uid()) and sc.assessment_id in (select a.id from public.assessments a where a.subject_id=subjects.id)) or exists(select 1 from public.assessment_scores sc where sc.school_id=subjects.school_id and sc.student_id in (select sa.student_id from public.student_accounts sa where sa.user_id=auth.uid()) and sc.assessment_id in (select a.id from public.assessments a where a.subject_id=subjects.id)));
create policy "subjects admins manage" on public.subjects for all to authenticated using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));

drop policy if exists "finance staff manage invoices" on public.fee_invoices;
create policy "invoices finance manage" on public.fee_invoices for all to authenticated using (public.is_school_finance_staff(school_id)) with check (public.is_school_finance_staff(school_id));
create policy "invoices linked read" on public.fee_invoices for select to authenticated using (public.is_linked_guardian(school_id,student_id) or public.is_linked_student(school_id,student_id));

drop policy if exists "finance staff manage payments" on public.payments;
create policy "payments finance manage" on public.payments for all to authenticated using (public.is_school_finance_staff(school_id)) with check (public.is_school_finance_staff(school_id));
create policy "payments linked read" on public.payments for select to authenticated using (exists(select 1 from public.fee_invoices i where i.id=payments.invoice_id and (public.is_linked_guardian(i.school_id,i.student_id) or public.is_linked_student(i.school_id,i.student_id))));

drop policy if exists "cbt exams read school" on public.cbt_exams;
create policy "cbt exams read school or linked student" on public.cbt_exams for select to authenticated
using (public.is_school_member(school_id) or exists(select 1 from public.student_accounts sa join public.students st on st.id=sa.student_id where sa.user_id=auth.uid() and sa.school_id=cbt_exams.school_id and (cbt_exams.class_id is null or st.class_id=cbt_exams.class_id)) or exists(select 1 from public.student_guardians sg join public.students st on st.id=sg.student_id where sg.user_id=auth.uid() and sg.school_id=cbt_exams.school_id and (cbt_exams.class_id is null or st.class_id=cbt_exams.class_id)));

drop policy if exists "members manage guardians" on public.student_guardians;
create policy "guardians admin manage" on public.student_guardians for all to authenticated using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
create policy "guardians self read" on public.student_guardians for select to authenticated using (user_id=auth.uid());

create unique index if not exists uq_report_cards_period on public.report_cards(school_id,student_id,session_id,term_id);

-- Tighten academic period management to admins while keeping read access for staff.
drop policy if exists "members manage sessions" on public.academic_sessions;
create policy "sessions staff read" on public.academic_sessions for select to authenticated using (public.is_school_member(school_id));
create policy "sessions admins manage" on public.academic_sessions for all to authenticated using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
drop policy if exists "members manage terms" on public.academic_terms;
create policy "terms staff read" on public.academic_terms for select to authenticated using (public.is_school_member(school_id));
create policy "terms admins manage" on public.academic_terms for all to authenticated using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));

alter table public.platform_admins enable row level security;
create policy "platform admin self read" on public.platform_admins for select to authenticated using (user_id=auth.uid());

create or replace function public.create_school(
  school_name text,
  school_type text default 'private_school'
)
returns uuid language plpgsql security definer set search_path=public as $$
declare new_school_id uuid; base_slug text; final_slug text; n integer:=0;
begin
 if auth.uid() is null then raise exception 'You must be signed in'; end if;
 if trim(coalesce(school_name,''))='' then raise exception 'School name is required'; end if;
 base_slug:=public.slugify_school_name(school_name); if base_slug='' then base_slug:='school'; end if; final_slug:=base_slug;
 while exists(select 1 from public.schools where slug=final_slug) loop n:=n+1; final_slug:=base_slug||'-'||n; end loop;
 insert into public.schools(name,school_type,slug) values(trim(school_name),coalesce(school_type,'private_school'),final_slug) returning id into new_school_id;
 insert into public.school_memberships(school_id,user_id,role,status) values(new_school_id,auth.uid(),'owner','active');
 insert into public.school_settings(school_id) values(new_school_id) on conflict do nothing;
 insert into public.website_settings(school_id,headline,subheadline) values(new_school_id,'Everything your school needs. One platform.','Smart infrastructure for modern schools.') on conflict do nothing;
 insert into public.website_pages(school_id,slug,title,body) values
 (new_school_id,'about','About us','Tell your school story here.'),
 (new_school_id,'admissions','Admissions','Add admission information, requirements and dates here.'),
 (new_school_id,'academics','Academics','Describe your academic programmes and learning approach here.')
 on conflict (school_id,slug) do nothing;
 insert into public.subscriptions(school_id,plan_code,status) values(new_school_id,'starter','trialing') on conflict do nothing;
 -- Bootstrap the first Edvora platform administrator only. Later school owners remain school-scoped.
 perform public.bootstrap_first_platform_admin();
 return new_school_id;
end;
$$;
revoke all on function public.create_school(text,text) from public;
grant execute on function public.create_school(text,text) to authenticated;


-- V4/V9 HARDENING
-- EDVORA V4 COMPLETE PRODUCTION HARDENING + WORKFLOWS
-- Run after schema-v2-single-campus.sql and schema-v3-production.sql.
-- This migration is intentionally idempotent.
-- Tenant model: one school = one tenant = one campus.

create extension if not exists pgcrypto;

-- ============================================================
-- PARENT LINK IDs
-- Every student gets a high-entropy bearer code stored in a
-- school-scoped table. Parents never receive SELECT access to it.
-- Admins can view/rotate it. Linking is done through a SECURITY
-- DEFINER function that creates a guardian row for the signed-in user.
-- ============================================================
create table if not exists public.student_parent_link_codes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  code_hash text not null,
  last_four text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  rotated_at timestamptz not null default now(),
  unique (student_id),
  unique (code_hash)
);

create index if not exists idx_parent_link_school on public.student_parent_link_codes(school_id,student_id);
alter table public.student_parent_link_codes enable row level security;
drop policy if exists "parent link admin read" on public.student_parent_link_codes;
drop policy if exists "parent link admin manage" on public.student_parent_link_codes;
drop policy if exists "parent link admin read" on public.student_parent_link_codes;
create policy "parent link admin read" on public.student_parent_link_codes for select to authenticated
using (public.is_school_admin(school_id));
drop policy if exists "parent link admin manage" on public.student_parent_link_codes;
create policy "parent link admin manage" on public.student_parent_link_codes for all to authenticated
using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));

create or replace function public.generate_parent_link_code()
returns text language plpgsql as $$
begin
  return 'EDV-' || upper(replace(replace(replace(upper(gen_random_uuid()::text || gen_random_uuid()::text),'-',''),'/','A'),'+','B'));
end;
$$;

create or replace function public.ensure_student_parent_link_code()
returns trigger language plpgsql security definer set search_path=public as $$
declare c text;
begin
  if new.school_id is null then return new; end if;
  if not exists(select 1 from public.student_parent_link_codes where student_id=new.id) then
    c := replace(replace(replace(public.generate_parent_link_code(),'/','A'),'+','B'),'=','C');
    insert into public.student_parent_link_codes(school_id,student_id,code_hash,last_four)
    values(new.school_id,new.id,encode(digest(c,'sha256'),'hex'),right(c,4));
  else
    update public.student_parent_link_codes set school_id=new.school_id where student_id=new.id;
  end if;
  return new;
end;
$$;

do $$ begin
  if not exists(select 1 from pg_trigger where tgname='student_parent_link_code') then
    create trigger student_parent_link_code after insert on public.students for each row execute function public.ensure_student_parent_link_code();
  end if;
end $$;

-- Backfill every existing student.
do $$
declare r record; c text;
begin
  for r in select s.id,s.school_id from public.students s left join public.student_parent_link_codes p on p.student_id=s.id where p.id is null loop
    c := replace(replace(replace(public.generate_parent_link_code(),'/','A'),'+','B'),'=','C');
    insert into public.student_parent_link_codes(school_id,student_id,code_hash,last_four)
    values(r.school_id,r.id,encode(digest(c,'sha256'),'hex'),right(c,4))
    on conflict (student_id) do nothing;
  end loop;
end $$;

create or replace function public.rotate_parent_link_code(target_student_id uuid)
returns text language plpgsql security definer set search_path=public as $$
declare sid uuid; c text;
begin
  select school_id into sid from public.students where id=target_student_id;
  if sid is null or not public.is_school_admin(sid) then raise exception 'Not authorized'; end if;
  c := replace(replace(replace(public.generate_parent_link_code(),'/','A'),'+','B'),'=','C');
  insert into public.student_parent_link_codes(school_id,student_id,code_hash,last_four,active,rotated_at)
  values(sid,target_student_id,encode(digest(c,'sha256'),'hex'),right(c,4),true,now())
  on conflict (student_id) do update set code=excluded.code,code_hash=excluded.code_hash,last_four=excluded.last_four,active=true,rotated_at=now();
  return c;
end;
$$;
revoke all on function public.rotate_parent_link_code(uuid) from public;
grant execute on function public.rotate_parent_link_code(uuid) to authenticated;

create or replace function public.link_parent_by_code(link_code text, relationship_name text default 'Parent')
returns jsonb language plpgsql security definer set search_path=public as $$
declare r record; uid uuid;
begin
  uid := auth.uid();
  if uid is null then raise exception 'You must be signed in'; end if;
  if length(trim(coalesce(link_code,''))) < 20 then raise exception 'Parent ID is invalid'; end if;
  select p.school_id,p.student_id,s.first_name,s.last_name,s.admission_number,s.class_id
    into r
  from public.student_parent_link_codes p
  join public.students s on s.id=p.student_id and s.school_id=p.school_id
  where p.active=true and p.code_hash=encode(digest(trim(link_code),'sha256'),'hex')
  limit 1;
  if r.student_id is null then raise exception 'Parent ID is invalid or has been rotated'; end if;
  insert into public.student_guardians(school_id,student_id,user_id,full_name,email,relationship,is_primary)
  select r.school_id,r.student_id,uid,coalesce(p.full_name,u.email),u.email,coalesce(nullif(trim(relationship_name),''),'Parent'),false
  from auth.users u left join public.profiles p on p.id=u.id where u.id=uid
  on conflict do nothing;
  return jsonb_build_object('school_id',r.school_id,'student_id',r.student_id,'student_name',trim(r.first_name||' '||r.last_name),'admission_number',r.admission_number,'class_id',r.class_id);
end;
$$;
revoke all on function public.link_parent_by_code(text,text) from public;
grant execute on function public.link_parent_by_code(text,text) to authenticated;

-- ============================================================
-- GRADING
-- ============================================================
create table if not exists public.grading_scales (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  unique(school_id,name)
);
create table if not exists public.grading_scale_items (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  scale_id uuid not null references public.grading_scales(id) on delete cascade,
  min_score numeric(6,2) not null,
  max_score numeric(6,2) not null,
  grade text not null,
  remark text,
  grade_point numeric(6,2),
  unique(scale_id,grade),
  check(min_score>=0 and max_score<=100 and min_score<=max_score)
);
alter table public.grading_scales enable row level security;
alter table public.grading_scale_items enable row level security;
drop policy if exists "grading scales school read" on public.grading_scales;
drop policy if exists "grading scales admin manage" on public.grading_scales;
drop policy if exists "grading items school read" on public.grading_scale_items;
drop policy if exists "grading items admin manage" on public.grading_scale_items;
drop policy if exists "grading scales school read" on public.grading_scales;
create policy "grading scales school read" on public.grading_scales for select to authenticated using (public.is_school_member(school_id) or exists(select 1 from public.student_guardians g where g.school_id=grading_scales.school_id and g.user_id=auth.uid()));
drop policy if exists "grading scales admin manage" on public.grading_scales;
create policy "grading scales admin manage" on public.grading_scales for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
drop policy if exists "grading items school read" on public.grading_scale_items;
create policy "grading items school read" on public.grading_scale_items for select to authenticated using(public.is_school_member(school_id));
drop policy if exists "grading items admin manage" on public.grading_scale_items;
create policy "grading items admin manage" on public.grading_scale_items for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));

insert into public.grading_scales(school_id,name,is_default)
select s.id,'Default Nigerian 100-point',true from public.schools s
where not exists(select 1 from public.grading_scales g where g.school_id=s.id);
insert into public.grading_scale_items(school_id,scale_id,min_score,max_score,grade,remark,grade_point)
select g.school_id,g.id,x.min_score,x.max_score,x.grade,x.remark,x.grade_point
from public.grading_scales g
cross join (values
 (70,100,'A','Excellent',5),(60,69.99,'B','Very good',4),(50,59.99,'C','Good',3),(45,49.99,'D','Fair',2),(40,44.99,'E','Pass',1),(0,39.99,'F','Fail',0)
) x(min_score,max_score,grade,remark,grade_point)
where g.name='Default Nigerian 100-point'
on conflict do nothing;

create or replace function public.grade_for_score(target_school_id uuid, score numeric)
returns jsonb language sql stable security definer set search_path=public as $$
select jsonb_build_object('grade',i.grade,'remark',i.remark,'grade_point',i.grade_point)
from public.grading_scales g join public.grading_scale_items i on i.scale_id=g.id
where g.school_id=target_school_id and g.is_default=true and score between i.min_score and i.max_score
order by i.min_score desc limit 1;
$$;

create table if not exists public.report_card_items (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  report_card_id uuid not null references public.report_cards(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  assessment_id uuid references public.assessments(id) on delete set null,
  score numeric(8,2),
  max_score numeric(8,2),
  grade text,
  remark text,
  grade_point numeric(6,2),
  unique(report_card_id,subject_id,assessment_id)
);
alter table public.report_card_items enable row level security;
drop policy if exists "report card items read" on public.report_card_items;
drop policy if exists "report card items admin manage" on public.report_card_items;
drop policy if exists "report card items read" on public.report_card_items;
create policy "report card items read" on public.report_card_items for select to authenticated using(
 public.is_school_member(school_id) or exists(select 1 from public.report_cards r where r.id=report_card_id and (public.is_linked_guardian(r.school_id,r.student_id) or public.is_linked_student(r.school_id,r.student_id)))
);
drop policy if exists "report card items admin manage" on public.report_card_items;
create policy "report card items admin manage" on public.report_card_items for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));

-- ============================================================
-- TIMETABLE
-- ============================================================
create table if not exists public.timetables (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  class_id uuid references public.classes(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  teacher_user_id uuid references auth.users(id) on delete set null,
  day_of_week smallint not null check(day_of_week between 1 and 7),
  period_label text not null,
  starts_at time,
  ends_at time,
  room text,
  created_at timestamptz not null default now()
);
create index if not exists idx_timetable_school_class on public.timetables(school_id,class_id,day_of_week);
alter table public.timetables enable row level security;
drop policy if exists "timetable school read" on public.timetables;
drop policy if exists "timetable admin manage" on public.timetables;
drop policy if exists "timetable school read" on public.timetables;
create policy "timetable school read" on public.timetables for select to authenticated using(
 public.is_school_admin(school_id)
 or (public.school_role(school_id)='teacher' and exists(
   select 1 from public.teacher_subject_assignments a
   where a.school_id=timetables.school_id
     and a.teacher_user_id=auth.uid()
     and a.subject_id=timetables.subject_id
     and (a.class_id is null or a.class_id=timetables.class_id)
 ))
 or exists(select 1 from public.student_accounts sa join public.students st on st.id=sa.student_id where sa.school_id=timetables.school_id and sa.user_id=auth.uid() and st.class_id=timetables.class_id)
 or exists(select 1 from public.student_guardians g join public.students st on st.id=g.student_id where g.school_id=timetables.school_id and g.user_id=auth.uid() and st.class_id=timetables.class_id)
);
drop policy if exists "timetable admin manage" on public.timetables;
create policy "timetable admin manage" on public.timetables for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));

-- ============================================================
-- ADMISSIONS + STUDENT LIFECYCLE + PROMOTION
-- ============================================================
create table if not exists public.admission_applications (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  application_number text not null,
  first_name text not null,
  last_name text not null,
  email text,
  phone text,
  desired_class_id uuid references public.classes(id) on delete set null,
  status text not null default 'submitted' check(status in('draft','submitted','review','accepted','rejected','enrolled')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(school_id,application_number)
);
alter table public.admission_applications enable row level security;
drop policy if exists "admissions admin manage" on public.admission_applications;
drop policy if exists "admissions admin manage" on public.admission_applications;
create policy "admissions admin manage" on public.admission_applications for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));

create table if not exists public.student_lifecycle_events (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  event_type text not null check(event_type in('admitted','enrolled','promoted','transferred','withdrawn','graduated','reactivated')),
  from_class_id uuid references public.classes(id) on delete set null,
  to_class_id uuid references public.classes(id) on delete set null,
  session_id uuid references public.academic_sessions(id) on delete set null,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.student_lifecycle_events enable row level security;
drop policy if exists "lifecycle school read" on public.student_lifecycle_events;
drop policy if exists "lifecycle admin manage" on public.student_lifecycle_events;
drop policy if exists "lifecycle school read" on public.student_lifecycle_events;
create policy "lifecycle school read" on public.student_lifecycle_events for select to authenticated using(public.is_school_member(school_id) or public.is_linked_guardian(school_id,student_id) or public.is_linked_student(school_id,student_id));
drop policy if exists "lifecycle admin manage" on public.student_lifecycle_events;
create policy "lifecycle admin manage" on public.student_lifecycle_events for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));

create table if not exists public.promotion_batches (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  session_id uuid references public.academic_sessions(id) on delete set null,
  from_class_id uuid references public.classes(id) on delete set null,
  to_class_id uuid references public.classes(id) on delete set null,
  status text not null default 'draft' check(status in('draft','processed','cancelled')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.promotion_items (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  batch_id uuid not null references public.promotion_batches(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  old_class_id uuid references public.classes(id) on delete set null,
  new_class_id uuid references public.classes(id) on delete set null,
  status text not null default 'pending' check(status in('pending','promoted','skipped')),
  unique(batch_id,student_id)
);
alter table public.promotion_batches enable row level security;
alter table public.promotion_items enable row level security;
drop policy if exists "promotion admin" on public.promotion_batches;
create policy "promotion admin" on public.promotion_batches for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
drop policy if exists "promotion items admin" on public.promotion_items;
create policy "promotion items admin" on public.promotion_items for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));

-- ============================================================
-- PROFILE / MEMBERSHIP MANAGEMENT
-- ============================================================
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists status text not null default 'active';
alter table public.school_memberships add column if not exists updated_at timestamptz not null default now();

-- ============================================================
-- BILLING HARDENING
-- ============================================================
alter table public.subscriptions add column if not exists billing_cycle text not null default 'monthly';
alter table public.subscriptions add column if not exists cancel_at_period_end boolean not null default false;
alter table public.subscriptions add column if not exists authorization_code text;
alter table public.subscriptions add column if not exists email text;
alter table public.subscription_events add column if not exists processed_at timestamptz;
create unique index if not exists uq_payments_provider_reference on public.payments(provider,provider_reference) where provider_reference is not null;
create index if not exists idx_subscriptions_status on public.subscriptions(status, current_period_end);

-- ============================================================
-- NOTIFICATION EVENT ENGINE
-- ============================================================
create or replace function public.notify_school_members()
returns trigger language plpgsql security definer set search_path=public as $$
declare r record; title_text text; body_text text;
begin
  if tg_table_name='fee_invoices' then title_text:='New fee invoice'; body_text:=coalesce(new.title,'School fees')||' has been added.';
  elsif tg_table_name='attendance_records' and new.status='absent' and (tg_op='INSERT' or old.status is distinct from new.status) then title_text:='Attendance alert'; body_text:='A student was marked absent on '||new.attendance_date::text||'.';
  elsif tg_table_name='report_cards' and new.status='published' and (tg_op='INSERT' or old.status is distinct from new.status) then title_text:='Result published'; body_text:='A report card is now available.';
  else return new; end if;
  for r in select distinct g.user_id from public.student_guardians g where g.school_id=new.school_id and g.student_id=coalesce((to_jsonb(new)->>'student_id')::uuid,null) and g.user_id is not null loop
    insert into public.notifications(school_id,user_id,title,body,type) values(new.school_id,r.user_id,title_text,body_text,'school_event');
  end loop;
  return new;
end;
$$;

do $$ begin
  if not exists(select 1 from pg_trigger where tgname='notify_invoice') then create trigger notify_invoice after insert on public.fee_invoices for each row execute function public.notify_school_members(); end if;
  if not exists(select 1 from pg_trigger where tgname='notify_absence') then create trigger notify_absence after insert or update on public.attendance_records for each row execute function public.notify_school_members(); end if;
  if not exists(select 1 from pg_trigger where tgname='notify_report') then create trigger notify_report after update on public.report_cards for each row execute function public.notify_school_members(); end if;
end $$;

-- ============================================================
-- TENANT INTEGRITY TRIGGERS
-- Prevent a user from combining a school A record with a school B FK.
-- ============================================================
create or replace function public.enforce_same_school_fk()
returns trigger language plpgsql security definer set search_path=public as $$
declare target_id uuid; target_school uuid; col text; tbl text;
begin
  tbl:=tg_argv[0]; col:=tg_argv[1];
  target_id:=(to_jsonb(new)->>col)::uuid;
  if target_id is null then return new; end if;
  execute format('select school_id from public.%I where id=$1',tbl) into target_school using target_id;
  if target_school is not null and target_school<>new.school_id then raise exception 'Tenant boundary violation'; end if;
  return new;
end;
$$;

do $$
begin
  if not exists(select 1 from pg_trigger where tgname='students_class_tenant') then create trigger students_class_tenant before insert or update on public.students for each row execute function public.enforce_same_school_fk('classes','class_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='attendance_student_tenant') then create trigger attendance_student_tenant before insert or update on public.attendance_records for each row execute function public.enforce_same_school_fk('students','student_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='attendance_class_tenant') then create trigger attendance_class_tenant before insert or update on public.attendance_records for each row execute function public.enforce_same_school_fk('classes','class_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='assessment_class_tenant') then create trigger assessment_class_tenant before insert or update on public.assessments for each row execute function public.enforce_same_school_fk('classes','class_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='assessment_subject_tenant') then create trigger assessment_subject_tenant before insert or update on public.assessments for each row execute function public.enforce_same_school_fk('subjects','subject_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='score_student_tenant') then create trigger score_student_tenant before insert or update on public.assessment_scores for each row execute function public.enforce_same_school_fk('students','student_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='score_assessment_tenant') then create trigger score_assessment_tenant before insert or update on public.assessment_scores for each row execute function public.enforce_same_school_fk('assessments','assessment_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='cbt_question_exam_tenant') then create trigger cbt_question_exam_tenant before insert or update on public.cbt_questions for each row execute function public.enforce_same_school_fk('cbt_exams','exam_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='cbt_attempt_exam_tenant') then create trigger cbt_attempt_exam_tenant before insert or update on public.cbt_attempts for each row execute function public.enforce_same_school_fk('cbt_exams','exam_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='cbt_attempt_student_tenant') then create trigger cbt_attempt_student_tenant before insert or update on public.cbt_attempts for each row execute function public.enforce_same_school_fk('students','student_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='cbt_answer_attempt_tenant') then create trigger cbt_answer_attempt_tenant before insert or update on public.cbt_answers for each row execute function public.enforce_same_school_fk('cbt_attempts','attempt_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='invoice_student_tenant') then create trigger invoice_student_tenant before insert or update on public.fee_invoices for each row execute function public.enforce_same_school_fk('students','student_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='payment_student_tenant') then create trigger payment_student_tenant before insert or update on public.payments for each row execute function public.enforce_same_school_fk('students','student_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='payment_invoice_tenant') then create trigger payment_invoice_tenant before insert or update on public.payments for each row execute function public.enforce_same_school_fk('fee_invoices','invoice_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='enrollment_student_tenant') then create trigger enrollment_student_tenant before insert or update on public.student_enrollments for each row execute function public.enforce_same_school_fk('students','student_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='enrollment_class_tenant') then create trigger enrollment_class_tenant before insert or update on public.student_enrollments for each row execute function public.enforce_same_school_fk('classes','class_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='guardian_student_tenant') then create trigger guardian_student_tenant before insert or update on public.student_guardians for each row execute function public.enforce_same_school_fk('students','student_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='staff_school_assignment') then create trigger staff_school_assignment before insert or update on public.teacher_class_assignments for each row execute function public.enforce_same_school_fk('classes','class_id'); end if;
  if not exists(select 1 from pg_trigger where tgname='staff_subject_assignment') then create trigger staff_subject_assignment before insert or update on public.teacher_subject_assignments for each row execute function public.enforce_same_school_fk('subjects','subject_id'); end if;
end $$;

-- ============================================================
-- MESSAGE SECURITY: participants only, same tenant.
-- ============================================================
drop policy if exists "threads participants read" on public.message_threads;
drop policy if exists "participants school read" on public.message_participants;
drop policy if exists "participants staff manage" on public.message_participants;
drop policy if exists "messages school read" on public.messages;
drop policy if exists "messages staff create" on public.messages;
drop policy if exists "threads participants read" on public.message_threads;
create policy "threads participants read" on public.message_threads for select to authenticated
using(public.is_school_member(school_id) and (created_by=auth.uid() or exists(select 1 from public.message_participants p where p.thread_id=message_threads.id and p.user_id=auth.uid())));
drop policy if exists "threads staff create" on public.message_threads;
create policy "threads staff create" on public.message_threads for insert to authenticated with check(public.is_school_member(school_id) and created_by=auth.uid());
drop policy if exists "participants self or admin" on public.message_participants;
create policy "participants self or admin" on public.message_participants for select to authenticated using(public.is_school_admin(school_id) or user_id=auth.uid());
drop policy if exists "participants admin manage" on public.message_participants;
create policy "participants admin manage" on public.message_participants for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
drop policy if exists "messages participants read" on public.messages;
create policy "messages participants read" on public.messages for select to authenticated using(public.is_school_member(school_id) and exists(select 1 from public.message_participants p where p.thread_id=messages.thread_id and p.user_id=auth.uid()));
drop policy if exists "messages participants create" on public.messages;
create policy "messages participants create" on public.messages for insert to authenticated with check(public.is_school_member(school_id) and sender_user_id=auth.uid() and exists(select 1 from public.message_participants p where p.thread_id=messages.thread_id and p.user_id=auth.uid()));

-- Public website must only expose published pages for a published school.
drop policy if exists "public published school" on public.schools;
drop policy if exists "public published website settings" on public.website_settings;
drop policy if exists "public published website pages" on public.website_pages;
drop policy if exists "public published school" on public.schools;
create policy "public published school" on public.schools for select to anon using(status in('active','trialing') and exists(select 1 from public.website_settings w where w.school_id=schools.id and w.is_published=true));
drop policy if exists "public published website settings" on public.website_settings;
create policy "public published website settings" on public.website_settings for select to anon using(is_published=true and exists(select 1 from public.schools s where s.id=website_settings.school_id and s.status in('active','trialing')));
drop policy if exists "public published website pages" on public.website_pages;
create policy "public published website pages" on public.website_pages for select to anon using(published=true and exists(select 1 from public.website_settings w where w.school_id=website_pages.school_id and w.is_published=true));

-- ============================================================
-- REPORT-CARD GENERATION
-- ============================================================
create or replace function public.build_report_card(target_student uuid,target_session uuid,target_term uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare sid uuid; rc uuid; a record; g jsonb;
begin
  select school_id into sid from public.students where id=target_student;
  if sid is null or not public.is_school_admin(sid) then raise exception 'Not authorized'; end if;
  insert into public.report_cards(school_id,student_id,session_id,term_id,status)
  values(sid,target_student,target_session,target_term,'draft')
  on conflict (school_id,student_id,session_id,term_id) do update set updated_at=now()
  returning id into rc;
  delete from public.report_card_items where report_card_id=rc;
  for a in select sc.score,ass.max_score,ass.subject_id,ass.id assessment_id from public.assessment_scores sc join public.assessments ass on ass.id=sc.assessment_id and ass.school_id=sid where sc.school_id=sid and sc.student_id=target_student and ass.session_id=target_session and ass.term_id=target_term loop
    g:=public.grade_for_score(sid,case when coalesce(a.max_score,0)>0 then (a.score/a.max_score)*100 else 0 end);
    insert into public.report_card_items(school_id,report_card_id,subject_id,assessment_id,score,max_score,grade,remark,grade_point)
    values(sid,rc,a.subject_id,a.assessment_id,a.score,a.max_score,g->>'grade',g->>'remark',(g->>'grade_point')::numeric);
  end loop;
  return rc;
end;
$$;
revoke all on function public.build_report_card(uuid,uuid,uuid) from public;
grant execute on function public.build_report_card(uuid,uuid,uuid) to authenticated;

-- ============================================================
-- AUDIT + RETENTION
-- ============================================================
create or replace function public.purge_old_audit_logs(retention_days integer default 365)
returns integer language plpgsql security definer set search_path=public as $$
declare n integer;
begin
  if retention_days < 30 then raise exception 'Retention cannot be less than 30 days'; end if;
  delete from public.audit_logs where created_at < now() - make_interval(days=>retention_days);
  get diagnostics n = row_count;
  return n;
end;
$$;
revoke all on function public.purge_old_audit_logs(integer) from public;
grant execute on function public.purge_old_audit_logs(integer) to authenticated;

-- Helpful indexes.
create index if not exists idx_guardians_user_school on public.student_guardians(user_id,school_id);
create index if not exists idx_students_school_class on public.students(school_id,class_id,status);
create index if not exists idx_assessment_scores_student on public.assessment_scores(school_id,student_id);
create index if not exists idx_fee_invoices_student on public.fee_invoices(school_id,student_id,status);
create index if not exists idx_audit_school_created on public.audit_logs(school_id,created_at desc);

-- End V4.

-- ============================================================
-- SECURE CBT STUDENT FUNCTIONS
-- Correct answers are never exposed through a student SELECT policy.
-- ============================================================
drop policy if exists "cbt questions read school" on public.cbt_questions;
drop policy if exists "cbt questions admin teacher read" on public.cbt_questions;
create policy "cbt questions admin teacher read" on public.cbt_questions for select to authenticated using(public.is_school_member(school_id) and public.can_manage_academics(school_id));

create or replace function public.get_student_cbt_exam(target_exam_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); sid uuid; ex record; qs jsonb;
begin
  select sa.student_id into sid from public.student_accounts sa where sa.user_id=uid and sa.status='active' limit 1;
  if sid is null then raise exception 'No linked student account'; end if;
  select e.* into ex from public.cbt_exams e join public.students st on st.id=sid and st.school_id=e.school_id and (e.class_id is null or e.class_id=st.class_id)
  where e.id=target_exam_id and e.status in('scheduled','live') and (e.starts_at is null or e.starts_at<=now()) and (e.ends_at is null or e.ends_at>=now());
  if ex.id is null then raise exception 'Exam is not available for this student'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'question_text',q.question_text,'question_type',q.question_type,'options',q.options,'points',q.points,'position',q.position) order by q.position),'[]'::jsonb) into qs from public.cbt_questions q where q.exam_id=ex.id and q.school_id=ex.school_id;
  return jsonb_build_object('exam',to_jsonb(ex)-'created_by','questions',qs,'student_id',sid);
end;
$$;
revoke all on function public.get_student_cbt_exam(uuid) from public;
grant execute on function public.get_student_cbt_exam(uuid) to authenticated;

create or replace function public.start_student_cbt_attempt(target_exam_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); sid uuid; sid_school uuid; attempt uuid;
begin
  select sa.student_id into sid from public.student_accounts sa where sa.user_id=uid and sa.status='active' limit 1;
  if sid is null then raise exception 'No linked student account'; end if;
  select school_id into sid_school from public.students where id=sid;
  perform public.get_student_cbt_exam(target_exam_id);
  insert into public.cbt_attempts(school_id,exam_id,student_id,status,max_score)
  select e.school_id,e.id,sid,'in_progress',coalesce((select sum(q.points) from public.cbt_questions q where q.exam_id=e.id),0)
  from public.cbt_exams e where e.id=target_exam_id
  on conflict(school_id,exam_id,student_id) do update set status=case when public.cbt_attempts.status='submitted' then public.cbt_attempts.status else 'in_progress' end
  returning id into attempt;
  return attempt;
end;
$$;
revoke all on function public.start_student_cbt_attempt(uuid) from public;
grant execute on function public.start_student_cbt_attempt(uuid) to authenticated;

create or replace function public.save_student_cbt_answer(target_attempt_id uuid,target_question_id uuid,target_answer text)
returns boolean language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); a public.cbt_attempts; q public.cbt_questions;
begin
  select * into a from public.cbt_attempts where id=target_attempt_id;
  if a.id is null then raise exception 'Attempt not found'; end if;
  if not exists(select 1 from public.student_accounts where user_id=uid and student_id=a.student_id and status='active') then raise exception 'Not authorized'; end if;
  if a.status<>'in_progress' then raise exception 'Attempt is no longer editable'; end if;
  select * into q from public.cbt_questions where id=target_question_id and exam_id=a.exam_id and school_id=a.school_id;
  if q.id is null then raise exception 'Question does not belong to this exam'; end if;
  insert into public.cbt_answers(school_id,attempt_id,question_id,answer,updated_at) values(a.school_id,a.id,q.id,target_answer,now())
  on conflict(attempt_id,question_id) do update set answer=excluded.answer,updated_at=now();
  return true;
end;
$$;
revoke all on function public.save_student_cbt_answer(uuid,uuid,text) from public;
grant execute on function public.save_student_cbt_answer(uuid,uuid,text) to authenticated;

create or replace function public.submit_student_cbt_attempt(target_attempt_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); a public.cbt_attempts; q record; answer_text text; total numeric:=0; max_total numeric:=0;
begin
  select * into a from public.cbt_attempts where id=target_attempt_id;
  if a.id is null then raise exception 'Attempt not found'; end if;
  if not exists(select 1 from public.student_accounts where user_id=uid and student_id=a.student_id and status='active') then raise exception 'Not authorized'; end if;
  if a.status not in('in_progress','expired') then return jsonb_build_object('score',a.score,'max_score',a.max_score,'status',a.status); end if;
  for q in select q.id,q.points,q.correct_answer,coalesce(ans.answer,'') answer from public.cbt_questions q left join public.cbt_answers ans on ans.question_id=q.id and ans.attempt_id=a.id where q.exam_id=a.exam_id and q.school_id=a.school_id order by q.position loop
    max_total:=max_total+coalesce(q.points,0);
    if q.correct_answer is not null and lower(trim(coalesce(q.answer,'')))=lower(trim(q.correct_answer)) then
      update public.cbt_answers set awarded_points=q.points,updated_at=now() where attempt_id=a.id and question_id=q.id;
      total:=total+q.points;
    else
      update public.cbt_answers set awarded_points=0,updated_at=now() where attempt_id=a.id and question_id=q.id;
    end if;
  end loop;
  update public.cbt_attempts set status='graded',submitted_at=now(),score=total,max_score=max_total where id=a.id;
  return jsonb_build_object('score',total,'max_score',max_total,'status','graded');
end;
$$;
revoke all on function public.submit_student_cbt_attempt(uuid) from public;
grant execute on function public.submit_student_cbt_attempt(uuid) to authenticated;

-- ============================================================
-- ANNOUNCEMENT VISIBILITY + NOTIFICATION FANOUT
-- ============================================================
drop policy if exists "members manage announcements" on public.announcements;
drop policy if exists "announcements school read" on public.announcements;
drop policy if exists "announcements create admins" on public.announcements;
drop policy if exists "announcements school read" on public.announcements;
create policy "announcements school read" on public.announcements for select to authenticated using(
 public.is_school_member(school_id)
 or (audience in('all','parents') and exists(select 1 from public.student_guardians g where g.school_id=announcements.school_id and g.user_id=auth.uid()))
 or (audience in('all','students') and exists(select 1 from public.student_accounts a where a.school_id=announcements.school_id and a.user_id=auth.uid() and a.status='active'))
);
drop policy if exists "announcements create admins" on public.announcements;
create policy "announcements create admins" on public.announcements for insert to authenticated with check(public.is_school_admin(school_id) and created_by=auth.uid());
drop policy if exists "announcements admin update" on public.announcements;
create policy "announcements admin update" on public.announcements for update to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
drop policy if exists "announcements admin delete" on public.announcements;
create policy "announcements admin delete" on public.announcements for delete to authenticated using(public.is_school_admin(school_id));

create or replace function public.fanout_announcement_notifications()
returns trigger language plpgsql security definer set search_path=public as $$
declare r record;
begin
  for r in select distinct sm.user_id from public.school_memberships sm where sm.school_id=new.school_id and sm.status='active' and (new.audience='all' or new.audience='staff' or (new.audience='teachers' and sm.role='teacher') or (new.audience='staff' and sm.role in('staff','admin','bursar','owner'))) loop
    insert into public.notifications(school_id,user_id,title,body,type) values(new.school_id,r.user_id,new.title,new.body,'announcement');
  end loop;
  if new.audience in('all','parents') then for r in select distinct g.user_id from public.student_guardians g where g.school_id=new.school_id and g.user_id is not null loop insert into public.notifications(school_id,user_id,title,body,type) values(new.school_id,r.user_id,new.title,new.body,'announcement'); end loop; end if;
  if new.audience in('all','students') then for r in select distinct a.user_id from public.student_accounts a where a.school_id=new.school_id and a.status='active' loop insert into public.notifications(school_id,user_id,title,body,type) values(new.school_id,r.user_id,new.title,new.body,'announcement'); end loop; end if;
  return new;
end;
$$;
do $$ begin if not exists(select 1 from pg_trigger where tgname='announcement_notification_fanout') then create trigger announcement_notification_fanout after insert on public.announcements for each row execute function public.fanout_announcement_notifications(); end if; end $$;

-- Profile access is explicitly self-only. This prevents tenant/account enumeration.
alter table public.profiles enable row level security;
drop policy if exists "profiles self read" on public.profiles;
drop policy if exists "profiles self write" on public.profiles;
drop policy if exists "profiles self read" on public.profiles;
create policy "profiles self read" on public.profiles for select to authenticated using(id=auth.uid());
drop policy if exists "profiles self write" on public.profiles;
create policy "profiles self write" on public.profiles for insert to authenticated with check(id=auth.uid());
drop policy if exists "profiles self update" on public.profiles;
create policy "profiles self update" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());

-- Portal users may initiate a thread with a school member, but cannot read
-- unrelated threads or add arbitrary external participants.
drop policy if exists "threads staff create" on public.message_threads;
drop policy if exists "threads school or portal create" on public.message_threads;
create policy "threads school or portal create" on public.message_threads for insert to authenticated with check(
 (public.is_school_member(school_id) and created_by=auth.uid())
 or ((exists(select 1 from public.student_guardians g where g.school_id=message_threads.school_id and g.user_id=auth.uid()) or exists(select 1 from public.student_accounts a where a.school_id=message_threads.school_id and a.user_id=auth.uid() and a.status='active')) and created_by=auth.uid())
);
drop policy if exists "participants admin manage" on public.message_participants;
drop policy if exists "participants self or admin manage" on public.message_participants;
create policy "participants self or admin manage" on public.message_participants for insert to authenticated with check(
 public.is_school_admin(school_id)
 or (user_id=auth.uid() and exists(select 1 from public.message_threads t where t.id=message_participants.thread_id and t.school_id=message_participants.school_id and t.created_by=auth.uid()))
 or (public.is_school_member(school_id) and exists(select 1 from public.message_threads t join public.message_participants p on p.thread_id=t.id where t.id=message_participants.thread_id and p.user_id=auth.uid() and p.school_id=message_participants.school_id))
);
drop policy if exists "participants admin update delete" on public.message_participants;
create policy "participants admin update delete" on public.message_participants for update to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
drop policy if exists "participants admin delete" on public.message_participants;
create policy "participants admin delete" on public.message_participants for delete to authenticated using(public.is_school_admin(school_id));

-- ============================================================
-- ROLE-BOUND ACADEMIC ACCESS
-- ============================================================
create or replace function public.teacher_can_class(target_school_id uuid,target_class_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
select public.is_school_admin(target_school_id) or (public.school_role(target_school_id)='teacher' and exists(select 1 from public.teacher_class_assignments a where a.school_id=target_school_id and a.teacher_user_id=auth.uid() and a.class_id=target_class_id));
$$;
create or replace function public.teacher_can_subject(target_school_id uuid,target_subject_id uuid,target_class_id uuid default null)
returns boolean language sql stable security definer set search_path=public as $$
select public.is_school_admin(target_school_id) or (public.school_role(target_school_id)='teacher' and exists(select 1 from public.teacher_subject_assignments a where a.school_id=target_school_id and a.teacher_user_id=auth.uid() and a.subject_id=target_subject_id and (target_class_id is null or a.class_id is null or a.class_id=target_class_id)));
$$;

-- Assessment metadata must be visible to linked parents/students for their child only.
drop policy if exists "assessments read scoped" on public.assessments;
drop policy if exists "assessments read scoped" on public.assessments;
create policy "assessments read scoped" on public.assessments for select to authenticated using(
 public.is_school_member(school_id)
 or exists(select 1 from public.students st where st.school_id=assessments.school_id and st.class_id=assessments.class_id and (public.is_linked_guardian(assessments.school_id,st.id) or public.is_linked_student(assessments.school_id,st.id)))
);
drop policy if exists "assessments manage academics" on public.assessments;
drop policy if exists "assessments manage academics" on public.assessments;
create policy "assessments manage academics" on public.assessments for all to authenticated using(
 public.is_school_admin(school_id) or (public.school_role(school_id)='teacher' and public.teacher_can_class(school_id,class_id) and (subject_id is null or public.teacher_can_subject(school_id,subject_id,class_id)))
) with check(
 public.is_school_admin(school_id) or (public.school_role(school_id)='teacher' and public.teacher_can_class(school_id,class_id) and (subject_id is null or public.teacher_can_subject(school_id,subject_id,class_id)))
);

drop policy if exists "scores manage academics" on public.assessment_scores;
drop policy if exists "scores manage academics" on public.assessment_scores;
create policy "scores manage academics" on public.assessment_scores for all to authenticated using(
 public.is_school_admin(school_id) or (public.school_role(school_id)='teacher' and exists(select 1 from public.assessments a where a.id=assessment_scores.assessment_id and a.school_id=assessment_scores.school_id and public.teacher_can_class(assessment_scores.school_id,a.class_id)))
) with check(
 public.is_school_admin(school_id) or (public.school_role(school_id)='teacher' and exists(select 1 from public.assessments a where a.id=assessment_scores.assessment_id and a.school_id=assessment_scores.school_id and public.teacher_can_class(assessment_scores.school_id,a.class_id)) and exists(select 1 from public.students st join public.assessments a on a.class_id=st.class_id where st.id=assessment_scores.student_id and a.id=assessment_scores.assessment_id and st.school_id=assessment_scores.school_id and a.school_id=assessment_scores.school_id))
);

drop policy if exists "attendance manage admins teachers" on public.attendance_records;
drop policy if exists "attendance update admins teachers" on public.attendance_records;
drop policy if exists "attendance manage admins teachers" on public.attendance_records;
create policy "attendance manage admins teachers" on public.attendance_records for insert to authenticated with check(
 public.is_school_admin(school_id) or (public.school_role(school_id)='teacher' and public.teacher_can_class(school_id,class_id))
);
drop policy if exists "attendance update admins teachers" on public.attendance_records;
create policy "attendance update admins teachers" on public.attendance_records for update to authenticated using(
 public.is_school_admin(school_id) or (public.school_role(school_id)='teacher' and public.teacher_can_class(school_id,class_id))
) with check(
 public.is_school_admin(school_id) or (public.school_role(school_id)='teacher' and public.teacher_can_class(school_id,class_id))
);

drop policy if exists "cbt exams manage admins teachers" on public.cbt_exams;
drop policy if exists "cbt questions manage admins teachers" on public.cbt_questions;
drop policy if exists "cbt exams manage admins teachers" on public.cbt_exams;
create policy "cbt exams manage admins teachers" on public.cbt_exams for all to authenticated using(
 public.is_school_admin(school_id) or (public.school_role(school_id)='teacher' and public.teacher_can_class(school_id,class_id))
) with check(
 public.is_school_admin(school_id) or (public.school_role(school_id)='teacher' and public.teacher_can_class(school_id,class_id))
);
drop policy if exists "cbt questions manage admins teachers" on public.cbt_questions;
create policy "cbt questions manage admins teachers" on public.cbt_questions for all to authenticated using(
 public.is_school_admin(school_id) or (public.school_role(school_id)='teacher' and exists(select 1 from public.cbt_exams e where e.id=cbt_questions.exam_id and e.school_id=cbt_questions.school_id and public.teacher_can_class(cbt_questions.school_id,e.class_id)))
) with check(
 public.is_school_admin(school_id) or (public.school_role(school_id)='teacher' and exists(select 1 from public.cbt_exams e where e.id=cbt_questions.exam_id and e.school_id=cbt_questions.school_id and public.teacher_can_class(cbt_questions.school_id,e.class_id)))
);

-- Invitation visibility for admins only.
alter table public.school_invitations enable row level security;
drop policy if exists "invitations admin read" on public.school_invitations;
drop policy if exists "invitations admin read" on public.school_invitations;
create policy "invitations admin read" on public.school_invitations for select to authenticated using(public.is_school_admin(school_id));

-- Prevent staff from assigning a teacher to records belonging to another tenant.
drop policy if exists "teacher class assignments admins manage" on public.teacher_class_assignments;
drop policy if exists "teacher subject assignments admins manage" on public.teacher_subject_assignments;
drop policy if exists "teacher class assignments admins manage" on public.teacher_class_assignments;
create policy "teacher class assignments admins manage" on public.teacher_class_assignments for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id) and exists(select 1 from public.school_memberships m where m.school_id=school_id and m.user_id=teacher_user_id and m.status='active' and m.role='teacher'));
drop policy if exists "teacher subject assignments admins manage" on public.teacher_subject_assignments;
create policy "teacher subject assignments admins manage" on public.teacher_subject_assignments for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id) and exists(select 1 from public.school_memberships m where m.school_id=school_id and m.user_id=teacher_user_id and m.status='active' and m.role='teacher'));
delete from public.student_guardians a using public.student_guardians b where a.id>b.id and a.school_id=b.school_id and a.student_id=b.student_id and a.user_id=b.user_id and a.user_id is not null;
create unique index if not exists uq_student_guardian_user on public.student_guardians(school_id,student_id,user_id) where user_id is not null;

drop function if exists public.purge_old_audit_logs(integer);
create or replace function public.purge_old_audit_logs(target_school_id uuid, retention_days integer default 365)
returns integer language plpgsql security definer set search_path=public as $$
declare n integer;
begin
  if not public.is_school_admin(target_school_id) then raise exception 'Not authorized'; end if;
  if retention_days < 30 then raise exception 'Retention cannot be less than 30 days'; end if;
  delete from public.audit_logs where school_id=target_school_id and created_at < now() - make_interval(days=>retention_days);
  get diagnostics n = row_count;
  return n;
end;
$$;
revoke all on function public.purge_old_audit_logs(uuid,integer) from public;
grant execute on function public.purge_old_audit_logs(uuid,integer) to authenticated;

-- Membership administration: admins can suspend/remove non-owner memberships,
-- but no browser user can promote themselves to owner.
drop policy if exists "memberships admin manage" on public.school_memberships;
drop policy if exists "memberships admin manage" on public.school_memberships;
create policy "memberships admin manage" on public.school_memberships for update to authenticated using(
 public.is_school_admin(school_id) and not (user_id=auth.uid() and role='owner')
) with check(
 public.is_school_admin(school_id) and (role in('admin','bursar','teacher','staff'))
);
drop policy if exists "memberships admin delete" on public.school_memberships;
create policy "memberships admin delete" on public.school_memberships for delete to authenticated using(public.is_school_admin(school_id) and role<>'owner');

create or replace function public.assign_receipt_number()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.receipt_number is null or trim(new.receipt_number)='' then
    new.receipt_number:='EDV-RCP-'||to_char(now(),'YYYYMMDD')||'-'||upper(substr(replace(new.id::text,'-',''),1,10));
  end if;
  return new;
end;
$$;
do $$ begin if not exists(select 1 from pg_trigger where tgname='payment_receipt_number') then create trigger payment_receipt_number before insert on public.payments for each row execute function public.assign_receipt_number(); end if; end $$;

do $$
begin
  if not exists(select 1 from pg_trigger where tgname='audit_staff_profiles') then create trigger audit_staff_profiles after insert or update or delete on public.staff_profiles for each row execute function public.write_audit_log(); end if;
  if not exists(select 1 from pg_trigger where tgname='audit_attendance') then create trigger audit_attendance after insert or update or delete on public.attendance_records for each row execute function public.write_audit_log(); end if;
  if not exists(select 1 from pg_trigger where tgname='audit_assessments') then create trigger audit_assessments after insert or update or delete on public.assessments for each row execute function public.write_audit_log(); end if;
  if not exists(select 1 from pg_trigger where tgname='audit_report_cards') then create trigger audit_report_cards after insert or update or delete on public.report_cards for each row execute function public.write_audit_log(); end if;
  if not exists(select 1 from pg_trigger where tgname='audit_cbt_attempts') then create trigger audit_cbt_attempts after insert or update or delete on public.cbt_attempts for each row execute function public.write_audit_log(); end if;
  if not exists(select 1 from pg_trigger where tgname='audit_announcements') then create trigger audit_announcements after insert or update or delete on public.announcements for each row execute function public.write_audit_log(); end if;
  if not exists(select 1 from pg_trigger where tgname='audit_website_settings') then create trigger audit_website_settings after insert or update or delete on public.website_settings for each row execute function public.write_audit_log(); end if;
  if not exists(select 1 from pg_trigger where tgname='audit_timetables') then create trigger audit_timetables after insert or update or delete on public.timetables for each row execute function public.write_audit_log(); end if;
end $$;
revoke all on function public.generate_parent_link_code() from public;
revoke all on function public.grade_for_score(uuid,numeric) from public;
grant execute on function public.grade_for_score(uuid,numeric) to authenticated;
revoke all on function public.is_school_member(uuid) from public;
revoke all on function public.school_role(uuid) from public;
revoke all on function public.is_school_admin(uuid) from public;
revoke all on function public.is_school_finance_staff(uuid) from public;
revoke all on function public.is_school_staff(uuid) from public;
revoke all on function public.is_school_teacher(uuid) from public;
revoke all on function public.can_manage_academics(uuid) from public;
revoke all on function public.is_linked_guardian(uuid,uuid) from public;
revoke all on function public.is_linked_student(uuid,uuid) from public;
revoke all on function public.teacher_can_class(uuid,uuid) from public;
revoke all on function public.teacher_can_subject(uuid,uuid,uuid) from public;
grant execute on function public.is_school_member(uuid),public.school_role(uuid),public.is_school_admin(uuid),public.is_school_finance_staff(uuid),public.is_school_staff(uuid),public.is_school_teacher(uuid),public.can_manage_academics(uuid),public.is_linked_guardian(uuid,uuid),public.is_linked_student(uuid,uuid),public.teacher_can_class(uuid,uuid),public.teacher_can_subject(uuid,uuid,uuid) to authenticated;
revoke all on function public.ensure_student_parent_link_code() from public;
revoke all on function public.write_audit_log() from public;
revoke all on function public.notify_school_members() from public;
revoke all on function public.fanout_announcement_notifications() from public;
revoke all on function public.enforce_same_school_fk() from public;
revoke all on function public.assign_receipt_number() from public;

-- CBT attempts/answers: students own their attempts; staff can review, not impersonate.
drop policy if exists "cbt attempts start" on public.cbt_attempts;
drop policy if exists "cbt attempts update own" on public.cbt_attempts;
drop policy if exists "cbt answers own" on public.cbt_answers;
drop policy if exists "cbt attempts start" on public.cbt_attempts;
create policy "cbt attempts start" on public.cbt_attempts for insert to authenticated with check(public.is_linked_student(school_id,student_id) or public.is_school_admin(school_id));
drop policy if exists "cbt attempts update own" on public.cbt_attempts;
create policy "cbt attempts update own" on public.cbt_attempts for update to authenticated using(public.is_linked_student(school_id,student_id) or public.is_school_admin(school_id)) with check(public.is_linked_student(school_id,student_id) or public.is_school_admin(school_id));
drop policy if exists "cbt answers read" on public.cbt_answers;
create policy "cbt answers read" on public.cbt_answers for select to authenticated using(exists(select 1 from public.cbt_attempts a where a.id=attempt_id and (public.is_school_admin(a.school_id) or public.is_school_teacher(a.school_id) or public.is_linked_student(a.school_id,a.student_id))));
drop policy if exists "cbt answers student write" on public.cbt_answers;
create policy "cbt answers student write" on public.cbt_answers for insert to authenticated with check(exists(select 1 from public.cbt_attempts a where a.id=attempt_id and public.is_linked_student(a.school_id,a.student_id)));
drop policy if exists "cbt answers student update" on public.cbt_answers;
create policy "cbt answers student update" on public.cbt_answers for update to authenticated using(exists(select 1 from public.cbt_attempts a where a.id=attempt_id and public.is_linked_student(a.school_id,a.student_id))) with check(exists(select 1 from public.cbt_attempts a where a.id=attempt_id and public.is_linked_student(a.school_id,a.student_id)));


-- ============================================================
-- V9 SECURITY / OPERATIONS HARDENING
-- ============================================================
alter table public.student_parent_link_codes drop column if exists code;
alter table public.student_parent_link_codes add column if not exists expires_at timestamptz;
alter table public.student_parent_link_codes add column if not exists revoked_at timestamptz;
create table if not exists public.parent_link_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  school_id uuid references public.schools(id) on delete cascade,
  attempted_at timestamptz not null default now(),
  succeeded boolean not null default false
);
create index if not exists idx_parent_link_attempts_user_time on public.parent_link_attempts(user_id, attempted_at desc);
alter table public.parent_link_attempts enable row level security;
drop policy if exists "parent link attempts self read" on public.parent_link_attempts;
create policy "parent link attempts self read" on public.parent_link_attempts for select to authenticated using(user_id=auth.uid());
revoke all on public.parent_link_attempts from anon,authenticated;

create or replace function public.generate_parent_link_code()
returns text language sql security definer set search_path=public as $$
  select 'EDV-' || upper(replace(upper(gen_random_uuid()::text || gen_random_uuid()::text),'-',''));
$$;
revoke all on function public.generate_parent_link_code() from public,anon,authenticated;

create or replace function public.rotate_parent_link_code(target_student_id uuid)
returns text language plpgsql security definer set search_path=public as $$
declare sid uuid; c text;
begin
  select school_id into sid from public.students where id=target_student_id;
  if sid is null or not public.is_school_admin(sid) then raise exception 'Not authorized'; end if;
  c := public.generate_parent_link_code();
  insert into public.student_parent_link_codes(school_id,student_id,code_hash,last_four,active,rotated_at,expires_at,revoked_at)
  values(sid,target_student_id,encode(digest(c,'sha256'),'hex'),right(c,4),true,now(),now()+interval '365 days',null)
  on conflict (student_id) do update set code_hash=excluded.code_hash,last_four=excluded.last_four,active=true,rotated_at=now(),expires_at=excluded.expires_at,revoked_at=null;
  return c;
end;
$$;
revoke all on function public.rotate_parent_link_code(uuid) from public,anon;
grant execute on function public.rotate_parent_link_code(uuid) to authenticated;

create or replace function public.link_parent_by_code(link_code text, relationship_name text default 'Parent')
returns jsonb language plpgsql security definer set search_path=public as $$
declare r record; uid uuid; attempts integer; attempt_id uuid;
begin
  uid := auth.uid();
  if uid is null then raise exception 'You must be signed in'; end if;
  if length(trim(coalesce(link_code,''))) < 20 then raise exception 'Parent ID is invalid'; end if;
  select count(*) into attempts from public.parent_link_attempts where user_id=uid and attempted_at > now() - interval '15 minutes';
  if attempts >= 10 then raise exception 'Too many attempts. Please try again later'; end if;
  insert into public.parent_link_attempts(user_id,succeeded) values(uid,false) returning id into attempt_id;
  select p.school_id,p.student_id,s.first_name,s.last_name,s.admission_number,s.class_id
    into r
  from public.student_parent_link_codes p
  join public.students s on s.id=p.student_id and s.school_id=p.school_id
  where p.active=true and p.revoked_at is null and (p.expires_at is null or p.expires_at > now())
    and p.code_hash=encode(digest(trim(link_code),'sha256'),'hex')
  limit 1;
  if r.student_id is null then raise exception 'Parent ID is invalid or has been rotated'; end if;
  insert into public.student_guardians(school_id,student_id,user_id,full_name,email,relationship,is_primary)
  select r.school_id,r.student_id,uid,coalesce(p.full_name,u.email),u.email,coalesce(nullif(trim(relationship_name),''),'Parent'),false
  from auth.users u left join public.profiles p on p.id=u.id where u.id=uid
  on conflict do nothing;
  update public.parent_link_attempts set school_id=r.school_id,succeeded=true where id=attempt_id;
  return jsonb_build_object('school_id',r.school_id,'student_id',r.student_id,'student_name',trim(r.first_name||' '||r.last_name),'admission_number',r.admission_number,'class_id',r.class_id);
end;
$$;
revoke all on function public.link_parent_by_code(text,text) from public,anon;
grant execute on function public.link_parent_by_code(text,text) to authenticated;

create or replace function public.recalculate_invoice_balance(target_invoice_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare total_paid numeric;
begin
  if target_invoice_id is null then return; end if;
  select coalesce(sum(case when status='successful' then amount else 0 end),0) into total_paid from public.payments where invoice_id=target_invoice_id;
  update public.fee_invoices i set amount_paid=least(i.amount,total_paid), status=case when total_paid<=0 then 'unpaid' when total_paid<i.amount then 'partially_paid' else 'paid' end where i.id=target_invoice_id;
end;
$$;
revoke all on function public.recalculate_invoice_balance(uuid) from public,anon,authenticated;
create or replace function public.recalculate_invoice_balance_trigger()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  perform public.recalculate_invoice_balance(coalesce(new.invoice_id,old.invoice_id));
  if TG_OP='DELETE' then return old; else return new; end if;
end;
$$;
revoke all on function public.recalculate_invoice_balance_trigger() from public,anon,authenticated;
do $$ begin
  if not exists(select 1 from pg_trigger where tgname='payments_recalculate_invoice') then
    create trigger payments_recalculate_invoice after insert or update or delete on public.payments for each row execute function public.recalculate_invoice_balance_trigger();
  end if;
end $$;

-- Parent-link secrets expire by default after 365 days.
update public.student_parent_link_codes set expires_at=coalesce(expires_at,created_at + interval '365 days') where expires_at is null;

create index if not exists idx_students_school_status on public.students(school_id,status);
create index if not exists idx_guardians_school_user on public.student_guardians(school_id,user_id);
create index if not exists idx_student_accounts_school_user on public.student_accounts(school_id,user_id,status);
create index if not exists idx_payments_school_status on public.payments(school_id,status,paid_at desc);
create index if not exists idx_notifications_user_unread on public.notifications(user_id,read_at,created_at desc);
create index if not exists idx_messages_thread_created on public.messages(thread_id,created_at);

insert into public.website_settings(school_id,headline,subheadline)
select id,'Everything your school needs. One platform.','Smart infrastructure for modern schools.' from public.schools
where not exists(select 1 from public.website_settings w where w.school_id=schools.id);

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

-- The first authenticated school owner bootstraps platform administration once.
create or replace function public.bootstrap_first_platform_admin()
returns boolean language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then return false; end if;
  perform pg_advisory_xact_lock(hashtextextended('edvora-platform-bootstrap',0));
  if exists(select 1 from public.platform_admins) then return false; end if;
  if not exists(select 1 from public.school_memberships where user_id=auth.uid() and role='owner' and status='active') then return false; end if;
  insert into public.platform_admins(user_id) values(auth.uid()) on conflict do nothing;
  return true;
end;
$$;
revoke all on function public.bootstrap_first_platform_admin() from public,anon;
grant execute on function public.bootstrap_first_platform_admin() to authenticated;

-- Platform admins can inspect the full school directory; normal users remain tenant-scoped.
drop policy if exists "platform admins read all schools" on public.schools;
create policy "platform admins read all schools" on public.schools for select to authenticated using(public.is_platform_admin() or public.is_school_member(id));

do $$
declare t text; arr text[] := array['assignments','assignment_submissions','school_events','ai_generation_jobs','notification_deliveries','integration_connections','webhook_events','push_subscriptions','student_documents','teacher_documents','media_assets','admission_reviews','promotion_runs','grading_rules','report_card_templates','fee_adjustments','payment_refunds','finance_ledger_entries','subscription_plan_changes','platform_support_tickets','support_ticket_messages','data_exports','deletion_requests','consent_records','retention_policies','backup_operations','import_jobs','school_health_snapshots','school_domains'];
begin
 foreach t in array arr loop execute format('alter table public.%I enable row level security',t); end loop;
end $$;

-- Tenant-scoped policies are intentionally role-aware. Parent/student rows are read-only where applicable.
drop policy if exists assignments_school_access on public.assignments;
drop policy if exists assignments_read on public.assignments;
drop policy if exists assignments_manage on public.assignments;
drop policy if exists assignments_update on public.assignments;
drop policy if exists assignments_delete on public.assignments;
create policy assignments_read on public.assignments for select to authenticated using(public.is_school_member(school_id));
create policy assignments_manage on public.assignments for insert to authenticated with check(public.is_school_admin(school_id) or (public.is_school_teacher(school_id) and teacher_id=auth.uid()));
create policy assignments_update on public.assignments for update to authenticated using(public.is_school_admin(school_id) or (public.is_school_teacher(school_id) and teacher_id=auth.uid())) with check(public.is_school_admin(school_id) or (public.is_school_teacher(school_id) and teacher_id=auth.uid()));
create policy assignments_delete on public.assignments for delete to authenticated using(public.is_school_admin(school_id) or (public.is_school_teacher(school_id) and teacher_id=auth.uid()));
drop policy if exists assignment_submissions_school_access on public.assignment_submissions; create policy assignment_submissions_school_access on public.assignment_submissions for all to authenticated using(public.is_school_member(school_id) or public.is_linked_student(school_id,student_id) or public.is_linked_guardian(school_id,student_id)) with check(public.is_school_member(school_id) or public.is_linked_student(school_id,student_id));
drop policy if exists school_events_access on public.school_events;
drop policy if exists school_events_read on public.school_events;
drop policy if exists school_events_manage on public.school_events;
create policy school_events_read on public.school_events for select to authenticated using(public.is_school_member(school_id));
create policy school_events_manage on public.school_events for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
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

-- V13: class creation is administrator-only.
drop policy if exists "members manage classes" on public.classes;
drop policy if exists "classes school staff read" on public.classes;
drop policy if exists "classes admins manage" on public.classes;
create policy "classes school read" on public.classes for select to authenticated
using(public.is_school_member(school_id));
create policy "classes admins manage" on public.classes for all to authenticated
using(public.is_school_admin(school_id))
with check(public.is_school_admin(school_id));
-- EDVORA V15 PRODUCTION COMPLETION
-- End-to-end public website, admissions, student/teacher workflows,
-- finance, messaging, CBT hardening, governance, security and platform controls.

-- ---------- WEBSITE CMS ----------
alter table public.website_settings add column if not exists site_title text;
alter table public.website_settings add column if not exists meta_description text;
alter table public.website_settings add column if not exists og_image_path text;
alter table public.website_settings add column if not exists favicon_path text;
alter table public.website_settings add column if not exists social_links jsonb not null default '{}'::jsonb;
alter table public.website_settings add column if not exists seo jsonb not null default '{}'::jsonb;
alter table public.website_settings add column if not exists principal_message text;
alter table public.website_settings add column if not exists facilities jsonb not null default '[]'::jsonb;
alter table public.website_settings add column if not exists testimonials jsonb not null default '[]'::jsonb;
alter table public.website_settings add column if not exists faqs jsonb not null default '[]'::jsonb;
alter table public.website_settings add column if not exists admissions_enabled boolean not null default true;
alter table public.website_settings add column if not exists tour_enabled boolean not null default true;
alter table public.website_settings add column if not exists published_at timestamptz;

alter table public.website_pages add column if not exists sort_order integer not null default 0;
alter table public.website_pages add column if not exists excerpt text;
alter table public.website_pages add column if not exists meta_title text;
alter table public.website_pages add column if not exists meta_description text;
alter table public.website_pages add column if not exists template text not null default 'content';
alter table public.website_pages add column if not exists hero_image_path text;

create table if not exists public.website_revisions (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 page_id uuid references public.website_pages(id) on delete cascade, snapshot jsonb not null default '{}'::jsonb,
 created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.website_news (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 title text not null, slug text not null, excerpt text, body text not null default '', image_path text,
 published boolean not null default false, published_at timestamptz, created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(school_id,slug)
);
create table if not exists public.website_gallery (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 title text, image_path text not null, alt_text text, caption text, sort_order integer not null default 0,
 published boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.website_staff (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 staff_profile_id uuid references public.staff_profiles(id) on delete cascade, name text not null, role_title text,
 bio text, photo_path text, published boolean not null default true, sort_order integer not null default 0,
 created_at timestamptz not null default now()
);

-- ---------- STUDENT PROFILE / LIFECYCLE ----------
alter table public.students add column if not exists middle_name text;
alter table public.students add column if not exists photo_path text;
alter table public.students add column if not exists address text;
alter table public.students add column if not exists previous_school text;
alter table public.students add column if not exists state_of_origin text;
alter table public.students add column if not exists nationality text;
alter table public.students add column if not exists house text;
alter table public.students add column if not exists transport_details jsonb not null default '{}'::jsonb;
alter table public.students add column if not exists boarding_status text not null default 'day' check (boarding_status in ('day','boarding'));
alter table public.students add column if not exists medical_notes text;
alter table public.students add column if not exists emergency_contact jsonb not null default '{}'::jsonb;
alter table public.students add column if not exists notes text;
alter table public.students add column if not exists joined_on date;
create table if not exists public.student_behaviour_records (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 student_id uuid not null references public.students(id) on delete cascade, category text not null default 'note', title text not null,
 details text, action_taken text, recorded_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.student_lifecycle_requests (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 student_id uuid not null references public.students(id) on delete cascade, request_type text not null check(request_type in ('withdrawal','graduation','transfer')),
 reason text, status text not null default 'requested' check(status in ('requested','approved','rejected','completed')),
 requested_by uuid references auth.users(id) on delete set null, reviewed_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(), completed_at timestamptz
);
create table if not exists public.student_scholarships (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 student_id uuid not null references public.students(id) on delete cascade, name text not null, amount numeric(14,2) not null default 0,
 percentage numeric(6,2), reason text, starts_on date, ends_on date, active boolean not null default true, created_at timestamptz not null default now()
);

-- ---------- TEACHER WORKSPACE ----------
alter table public.staff_profiles add column if not exists photo_path text;
alter table public.staff_profiles add column if not exists bio text;
alter table public.staff_profiles add column if not exists qualifications text;
alter table public.staff_profiles add column if not exists availability jsonb not null default '{}'::jsonb;
create table if not exists public.teacher_leave_requests (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 teacher_user_id uuid not null references auth.users(id) on delete cascade, starts_on date not null, ends_on date not null,
 reason text, status text not null default 'pending' check(status in ('pending','approved','rejected','cancelled')),
 reviewed_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.lesson_notes (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 teacher_user_id uuid not null references auth.users(id) on delete cascade, class_id uuid references public.classes(id) on delete set null,
 subject_id uuid references public.subjects(id) on delete set null, title text not null, body text not null default '', lesson_date date,
 status text not null default 'draft' check(status in ('draft','published')), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

-- ---------- ADMISSIONS ----------
alter table public.admission_applications add column if not exists applicant_address text;
alter table public.admission_applications add column if not exists date_of_birth date;
alter table public.admission_applications add column if not exists gender text;
alter table public.admission_applications add column if not exists guardian_name text;
alter table public.admission_applications add column if not exists guardian_email text;
alter table public.admission_applications add column if not exists guardian_phone text;
alter table public.admission_applications add column if not exists source text not null default 'staff';
alter table public.admission_applications add column if not exists submitted_at timestamptz;
create or replace function public.assign_application_number()
returns trigger language plpgsql security definer set search_path=public as $$
declare y text:=extract(year from current_date)::text; n bigint;
begin
 if nullif(trim(new.application_number),'') is not null then return new; end if;
 perform pg_advisory_xact_lock(hashtextextended(new.school_id::text||':admission',0));
 select coalesce(max((substring(application_number from '^APP-[0-9]{4}-([0-9]+)$'))::bigint),0)+1 into n
 from public.admission_applications where school_id=new.school_id and application_number like 'APP-'||y||'-%';
 new.application_number:='APP-'||y||'-'||lpad(n::text,6,'0');
 if new.submitted_at is null then new.submitted_at:=now(); end if;
 return new;
end; $$;
drop trigger if exists admission_application_number on public.admission_applications;
create trigger admission_application_number before insert on public.admission_applications for each row execute function public.assign_application_number();
create or replace function public.submit_public_admission(
 target_slug text, first_name text, last_name text, applicant_email text, applicant_phone text,
 target_class uuid default null, applicant_gender text default null, applicant_dob date default null,
 guardian_full_name text default null, guardian_email_address text default null, guardian_phone_number text default null,
 applicant_address_value text default null, applicant_notes text default null
) returns jsonb language plpgsql security definer set search_path=public as $$
declare sid uuid; aid uuid; anum text;
begin
 select s.id into sid from public.schools s join public.website_settings w on w.school_id=s.id
 where s.slug=trim(target_slug) and s.status in ('active','trialing') and w.is_published=true and w.admissions_enabled=true;
 if sid is null then raise exception 'Admissions are not available for this school'; end if;
 if target_class is not null and not exists(select 1 from public.classes where id=target_class and school_id=sid) then raise exception 'Selected class is invalid'; end if;
 insert into public.admission_applications(school_id,first_name,last_name,email,phone,desired_class_id,notes,status,source,gender,date_of_birth,guardian_name,guardian_email,guardian_phone,applicant_address)
 values(sid,trim(first_name),trim(last_name),lower(trim(applicant_email)),trim(applicant_phone),target_class,trim(applicant_notes),'submitted','public',applicant_gender,applicant_dob,trim(guardian_full_name),lower(trim(guardian_email_address)),trim(guardian_phone_number),trim(applicant_address_value)) returning id,application_number into aid,anum;
 return jsonb_build_object('id',aid,'application_number',anum,'school_id',sid);
end; $$;
revoke all on function public.submit_public_admission(text,text,text,text,text,uuid,text,date,text,text,text,text,text) from public;
grant execute on function public.submit_public_admission(text,text,text,text,text,uuid,text,date,text,text,text,text,text) to anon,authenticated;

-- ---------- FINANCE ----------
create table if not exists public.expenses (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 category text not null, description text not null, amount numeric(14,2) not null check(amount>=0), expense_date date not null default current_date,
 payment_method text, reference text, approved_by uuid references auth.users(id) on delete set null, created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.payment_plans (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 student_id uuid not null references public.students(id) on delete cascade, name text not null, total_amount numeric(14,2) not null,
 installments integer not null default 1, interval_days integer not null default 30, status text not null default 'active' check(status in ('active','completed','cancelled')),
 created_at timestamptz not null default now()
);
create table if not exists public.finance_reconciliations (
 id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
 reconciliation_date date not null, account_name text not null, expected_amount numeric(14,2) not null default 0, actual_amount numeric(14,2) not null default 0,
 difference numeric(14,2) generated always as (actual_amount-expected_amount) stored, notes text, reconciled_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);

-- ---------- CBT ----------
alter table public.cbt_questions add column if not exists image_path text;
alter table public.cbt_questions add column if not exists explanation text;
alter table public.cbt_exams add column if not exists randomize_questions boolean not null default true;
alter table public.cbt_exams add column if not exists randomize_options boolean not null default true;
alter table public.cbt_exams add column if not exists max_attempts integer not null default 1;
alter table public.cbt_exams add column if not exists instructions text;
alter table public.cbt_exams add column if not exists pass_mark numeric(6,2);

-- ---------- REPORT CARDS ----------
alter table public.report_cards add column if not exists attendance_summary jsonb not null default '{}'::jsonb;
alter table public.report_cards add column if not exists behaviour_summary text;
alter table public.report_cards add column if not exists skills jsonb not null default '[]'::jsonb;
alter table public.report_cards add column if not exists position integer;
alter table public.report_cards add column if not exists promotion_recommendation text;
alter table public.report_cards add column if not exists approved_by uuid references auth.users(id) on delete set null;

-- ---------- NOTIFICATIONS / MESSAGING ----------
alter table public.messages add column if not exists read_at timestamptz;
alter table public.message_threads add column if not exists archived_at timestamptz;
create table if not exists public.notification_preferences (
 user_id uuid primary key references auth.users(id) on delete cascade, email_enabled boolean not null default true,
 sms_enabled boolean not null default false, whatsapp_enabled boolean not null default false, push_enabled boolean not null default true,
 attendance_alerts boolean not null default true, fee_alerts boolean not null default true, result_alerts boolean not null default true,
 assignment_alerts boolean not null default true, updated_at timestamptz not null default now()
);

-- ---------- SECURITY / PRIVACY / OBSERVABILITY ----------
create table if not exists public.rate_limit_events (
 id uuid primary key default gen_random_uuid(), key_hash text not null, action text not null, created_at timestamptz not null default now()
);
create index if not exists idx_rate_limit_events_key_time on public.rate_limit_events(key_hash,action,created_at desc);
create table if not exists public.security_devices (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 label text, user_agent text, last_seen_at timestamptz not null default now(), trusted boolean not null default false, created_at timestamptz not null default now()
);
create table if not exists public.system_logs (
 id uuid primary key default gen_random_uuid(), level text not null default 'info', source text not null, message text not null,
 metadata jsonb not null default '{}'::jsonb, school_id uuid references public.schools(id) on delete set null, created_at timestamptz not null default now()
);
create table if not exists public.mfa_enrollments (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 provider text not null default 'totp', status text not null default 'pending', created_at timestamptz not null default now()
);

-- ---------- RLS ----------

alter table public.website_revisions enable row level security;
alter table public.website_news enable row level security;
alter table public.website_gallery enable row level security;
alter table public.website_staff enable row level security;
alter table public.student_behaviour_records enable row level security;
alter table public.student_lifecycle_requests enable row level security;
alter table public.student_scholarships enable row level security;
alter table public.teacher_leave_requests enable row level security;
alter table public.lesson_notes enable row level security;
alter table public.expenses enable row level security;
alter table public.payment_plans enable row level security;
alter table public.finance_reconciliations enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.security_devices enable row level security;
alter table public.system_logs enable row level security;

-- Public published website reads.
drop policy if exists public_published_school on public.schools;
create policy public_published_school on public.schools for select to anon,authenticated using(status in ('active','trialing'));
drop policy if exists public_published_website on public.website_settings;
create policy public_published_website on public.website_settings for select to anon,authenticated using(is_published=true);
drop policy if exists public_published_pages on public.website_pages;
create policy public_published_pages on public.website_pages for select to anon,authenticated using(published=true and exists(select 1 from public.website_settings w where w.school_id=website_pages.school_id and w.is_published=true));
drop policy if exists public_published_news on public.website_news;
create policy public_published_news on public.website_news for select to anon,authenticated using(published=true and exists(select 1 from public.website_settings w where w.school_id=website_news.school_id and w.is_published=true));
drop policy if exists public_published_gallery on public.website_gallery;
create policy public_published_gallery on public.website_gallery for select to anon,authenticated using(published=true and exists(select 1 from public.website_settings w where w.school_id=website_gallery.school_id and w.is_published=true));
drop policy if exists public_published_staff on public.website_staff;
create policy public_published_staff on public.website_staff for select to anon,authenticated using(published=true and exists(select 1 from public.website_settings w where w.school_id=website_staff.school_id and w.is_published=true));

-- Staff management.
create policy student_behaviour_read on public.student_behaviour_records for select to authenticated using(public.is_school_member(school_id) or public.is_linked_guardian(school_id,student_id));
create policy student_behaviour_manage on public.student_behaviour_records for all to authenticated using(public.is_school_admin(school_id) or (public.is_school_teacher(school_id) and exists(select 1 from public.teacher_class_assignments a join public.students s on s.class_id=a.class_id where a.school_id=school_id and a.teacher_user_id=auth.uid() and s.id=student_id))) with check(public.is_school_admin(school_id) or public.is_school_teacher(school_id));
create policy lifecycle_requests_read on public.student_lifecycle_requests for select to authenticated using(public.is_school_member(school_id) or public.is_linked_guardian(school_id,student_id));
create policy lifecycle_requests_manage on public.student_lifecycle_requests for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
create policy scholarships_school on public.student_scholarships for all to authenticated using(public.is_school_finance_staff(school_id)) with check(public.is_school_finance_staff(school_id));
create policy teacher_leave_own_or_admin on public.teacher_leave_requests for all to authenticated using(teacher_user_id=auth.uid() or public.is_school_admin(school_id)) with check(teacher_user_id=auth.uid() or public.is_school_admin(school_id));
create policy lesson_notes_teacher on public.lesson_notes for all to authenticated using(teacher_user_id=auth.uid() or public.is_school_admin(school_id)) with check(teacher_user_id=auth.uid() or public.is_school_admin(school_id));
create policy expenses_finance on public.expenses for all to authenticated using(public.is_school_finance_staff(school_id)) with check(public.is_school_finance_staff(school_id));
create policy payment_plans_finance on public.payment_plans for all to authenticated using(public.is_school_finance_staff(school_id)) with check(public.is_school_finance_staff(school_id));
create policy reconciliation_finance on public.finance_reconciliations for all to authenticated using(public.is_school_finance_staff(school_id)) with check(public.is_school_finance_staff(school_id));
create policy notification_preferences_own on public.notification_preferences for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy security_devices_own on public.security_devices for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy system_logs_admin on public.system_logs for select to authenticated using(public.is_platform_admin() or (school_id is not null and public.is_school_admin(school_id)));

-- Website content management.
create policy website_revisions_admin on public.website_revisions for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
create policy website_news_admin on public.website_news for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
create policy website_gallery_admin on public.website_gallery for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
create policy website_staff_admin on public.website_staff for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));

-- Public submissions are inserted only through controlled RPCs/API.
drop policy if exists public_submission_insert on public.website_submissions;
create policy public_submission_insert on public.website_submissions for insert to anon,authenticated with check(exists(select 1 from public.website_settings w where w.school_id=website_submissions.school_id and w.is_published=true));

-- Sort existing website pages.
update public.website_pages set sort_order=case slug when 'about' then 10 when 'admissions' then 20 when 'academics' then 30 else 100 end where sort_order=0;

-- Default website content for all existing schools.
insert into public.website_pages(school_id,slug,title,body,sort_order,published,template)
select s.id,'contact','Contact','Contact our school for admissions, tours and general enquiries.',50,true,'contact'
from public.schools s where not exists(select 1 from public.website_pages p where p.school_id=s.id and p.slug='contact');

-- Public sitemap support indexes.
create index if not exists idx_website_pages_public on public.website_pages(school_id,published,sort_order);
create index if not exists idx_website_news_public on public.website_news(school_id,published,published_at desc);
create index if not exists idx_website_gallery_public on public.website_gallery(school_id,published,sort_order);

-- Default retention policies.
insert into public.retention_policies(school_id,data_type,retention_days,legal_basis)
select s.id,v.data_type,v.days,'School policy'
from public.schools s cross join (values ('website_submissions',365),('audit_logs',2555),('login_events',365),('notifications',365)) v(data_type,days)
on conflict(school_id,data_type) do nothing;

-- Security hardening: only published public data is anonymous-readable; all sensitive tables stay authenticated/RLS protected.

-- Public school calendar events.
drop policy if exists public_published_events on public.school_events;
create policy public_published_events on public.school_events for select to anon,authenticated using(exists(select 1 from public.website_settings w where w.school_id=school_events.school_id and w.is_published=true));

-- Public submissions rate limiting: keep only recent buckets; application/API should use this helper before accepting spam-prone requests.
create or replace function public.allow_public_request(request_key text, action_name text, window_seconds integer default 60, max_requests integer default 10)
returns boolean language plpgsql security definer set search_path=public as $$
declare h text:=encode(digest(coalesce(request_key,'')||':'||coalesce(action_name,''),'sha256'),'hex'); c integer;
begin
 delete from public.rate_limit_events where created_at < now()-interval '1 day';
 select count(*) into c from public.rate_limit_events where key_hash=h and action=action_name and created_at >= now()-(window_seconds||' seconds')::interval;
 if c >= max_requests then return false; end if;
 insert into public.rate_limit_events(key_hash,action) values(h,action_name); return true;
end; $$;
revoke all on function public.allow_public_request(text,text,integer,integer) from public;
grant execute on function public.allow_public_request(text,text,integer,integer) to anon,authenticated;

drop policy if exists public_published_classes on public.classes;
create policy public_published_classes on public.classes for select to anon,authenticated using(exists(select 1 from public.website_settings w where w.school_id=classes.school_id and w.is_published=true and w.admissions_enabled=true));

-- Safe application-number backfill for legacy rows.
with numbered as (
 select id,'APP-'||extract(year from coalesce(created_at,current_date))::text||'-'||lpad(row_number() over(partition by school_id order by created_at,id)::text,6,'0') as new_number
 from public.admission_applications where application_number is null or trim(application_number)=''
)
update public.admission_applications a set application_number=n.new_number from numbered n where a.id=n.id;
