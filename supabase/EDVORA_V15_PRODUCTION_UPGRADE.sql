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

-- Public application number backfill.
update public.admission_applications set application_number='APP-'||extract(year from coalesce(created_at,current_date))::text||'-'||lpad(row_number() over(partition by school_id order by created_at,id)::text,6,'0')
where application_number is null or trim(application_number)='';

-- Security hardening: only published public data is anonymous-readable; all sensitive tables stay authenticated/RLS protected.
