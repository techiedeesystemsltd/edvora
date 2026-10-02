-- ============================================================
-- EDVORA V13 UPGRADE: admission numbers, classes, timetable access
-- ============================================================

create or replace function public.assign_admission_number()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  target_year integer := extract(year from current_date)::integer;
  next_number bigint;
  prefix text := 'ADM-' || target_year::text || '-';
begin
  if nullif(trim(new.admission_number), '') is not null then return new; end if;
  perform pg_advisory_xact_lock(hashtextextended(new.school_id::text, 0));
  select coalesce(max((substring(admission_number from '^ADM-[0-9]{4}-([0-9]+)$'))::bigint),0) + 1
    into next_number
    from public.students
   where school_id=new.school_id and admission_number like prefix || '%';
  new.admission_number := prefix || lpad(next_number::text,4,'0');
  return new;
end;
$$;

drop trigger if exists students_admission_number on public.students;
create trigger students_admission_number before insert on public.students
for each row execute function public.assign_admission_number();

-- Classes are administrator-owned configuration.
drop policy if exists "members manage classes" on public.classes;
drop policy if exists "classes school staff read" on public.classes;
drop policy if exists "classes admins manage" on public.classes;
create policy "classes school read" on public.classes for select to authenticated
using(public.is_school_member(school_id));
create policy "classes admins manage" on public.classes for all to authenticated
using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));

-- Teachers can read only timetable periods for subjects assigned to them.
-- Owners/admins can read and manage the whole school timetable.
drop policy if exists "timetable school read" on public.timetables;
drop policy if exists "timetable admin manage" on public.timetables;
create policy "timetable school read" on public.timetables for select to authenticated using(
 public.is_school_admin(school_id)
 or (public.school_role(school_id)='teacher' and exists(
   select 1 from public.teacher_subject_assignments a
   where a.school_id=timetables.school_id and a.teacher_user_id=auth.uid()
     and a.subject_id=timetables.subject_id
     and (a.class_id is null or a.class_id=timetables.class_id)
 ))
 or exists(select 1 from public.student_accounts sa join public.students st on st.id=sa.student_id where sa.school_id=timetables.school_id and sa.user_id=auth.uid() and st.class_id=timetables.class_id)
 or exists(select 1 from public.student_guardians g join public.students st on st.id=g.student_id where g.school_id=timetables.school_id and g.user_id=auth.uid() and st.class_id=timetables.class_id)
);
create policy "timetable admin manage" on public.timetables for all to authenticated using(public.is_school_admin(school_id)) with check(public.is_school_admin(school_id));
