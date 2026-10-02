-- EDVORA V22
-- Results release workflow, parent-first result review, server-enforced CBT window,
-- school onboarding structure, and secure parent linking hardening.

create extension if not exists pgcrypto;

-- ============================================================
-- SCHOOL STRUCTURE
-- ============================================================
alter table public.schools add column if not exists school_ownership text;
alter table public.schools add column if not exists school_levels text[] not null default '{}';
alter table public.schools drop constraint if exists schools_ownership_check_v22;
alter table public.schools add constraint schools_ownership_check_v22
  check (school_ownership is null or school_ownership in ('private_school','federal_government','state_government','other_public')) not valid;

-- ============================================================
-- PARENT-FIRST RESULT RELEASE
-- Published results are visible to linked parents first. A student
-- cannot read the same period until a linked parent has reviewed it.
-- ============================================================
create table if not exists public.parent_result_reviews (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  session_id uuid not null references public.academic_sessions(id) on delete cascade,
  term_id uuid not null references public.academic_terms(id) on delete cascade,
  reviewed_by uuid not null references auth.users(id) on delete cascade,
  reviewed_at timestamptz not null default now(),
  unique(school_id,student_id,session_id,term_id)
);
create index if not exists idx_parent_result_reviews_lookup
  on public.parent_result_reviews(school_id,student_id,session_id,term_id);

create or replace function public.parent_has_reviewed_result(
  target_school uuid,target_student uuid,target_session uuid,target_term uuid
) returns boolean
language sql stable security definer set search_path=public as $$
  select exists (
    select 1 from public.parent_result_reviews r
    where r.school_id=target_school and r.student_id=target_student
      and r.session_id=target_session and r.term_id=target_term
      and r.reviewed_by=auth.uid()
  );
$$;
revoke all on function public.parent_has_reviewed_result(uuid,uuid,uuid,uuid) from public;
grant execute on function public.parent_has_reviewed_result(uuid,uuid,uuid,uuid) to authenticated;

create or replace function public.result_has_any_parent_review(
  target_school uuid,target_student uuid,target_session uuid,target_term uuid
) returns boolean
language sql stable security definer set search_path=public as $$
  select exists (
    select 1 from public.parent_result_reviews r
    where r.school_id=target_school and r.student_id=target_student
      and r.session_id=target_session and r.term_id=target_term
  );
$$;
revoke all on function public.result_has_any_parent_review(uuid,uuid,uuid,uuid) from public;
grant execute on function public.result_has_any_parent_review(uuid,uuid,uuid,uuid) to authenticated;

create or replace function public.review_student_result(
  target_student uuid,target_session uuid,target_term uuid
) returns jsonb
language plpgsql security definer set search_path=public as $$
declare sid uuid; rid uuid; target_school uuid; existing uuid;
begin
  select s.school_id into target_school from public.students s where s.id=target_student;
  if target_school is null then raise exception 'Student not found'; end if;
  if not exists(select 1 from public.student_guardians g where g.school_id=target_school and g.student_id=target_student and g.user_id=auth.uid()) then raise exception 'Only a linked parent or guardian can review this result'; end if;
  if not exists (
    select 1 from public.student_term_results r
    where r.school_id=target_school and r.student_id=target_student
      and r.session_id=target_session and r.term_id=target_term and r.status in ('published','locked')
  ) then raise exception 'This result has not been published'; end if;
  select id into existing from public.parent_result_reviews
    where school_id=target_school and student_id=target_student and session_id=target_session and term_id=target_term;
  if existing is null then
    insert into public.parent_result_reviews(school_id,student_id,session_id,term_id,reviewed_by)
    values(target_school,target_student,target_session,target_term,auth.uid()) returning id into rid;
  else
    rid:=existing;
  end if;
  return jsonb_build_object('review_id',rid,'student_id',target_student,'released',true);
end;
$$;
revoke all on function public.review_student_result(uuid,uuid,uuid) from public;
grant execute on function public.review_student_result(uuid,uuid,uuid) to authenticated;

alter table public.parent_result_reviews enable row level security;
drop policy if exists v22_parent_result_reviews_read on public.parent_result_reviews;
create policy v22_parent_result_reviews_read on public.parent_result_reviews for select to authenticated
using (public.is_school_admin(school_id) or reviewed_by=auth.uid());
drop policy if exists v22_parent_result_reviews_insert on public.parent_result_reviews;
create policy v22_parent_result_reviews_insert on public.parent_result_reviews for insert to authenticated
with check (reviewed_by=auth.uid() and exists(select 1 from public.student_guardians g where g.school_id=public.parent_result_reviews.school_id and g.student_id=public.parent_result_reviews.student_id and g.user_id=auth.uid()));

-- Replace broad V18 result visibility with publication-aware policies.
drop policy if exists v18_results_read on public.student_term_results;
drop policy if exists v22_results_read on public.student_term_results;
create policy v22_results_read on public.student_term_results for select to authenticated using (
  public.is_school_member(school_id)
  or (exists(select 1 from public.student_guardians g where g.school_id=public.student_term_results.school_id and g.student_id=public.student_term_results.student_id and g.user_id=auth.uid()) and status in ('published','locked'))
  or (public.is_linked_student(school_id,student_id)
      and status in ('published','locked')
      and public.result_has_any_parent_review(school_id,student_id,session_id,term_id))
);

-- Report cards follow the same publication gate for parents/students.
drop policy if exists "report cards scoped read" on public.report_cards;
create policy "report cards v22 scoped read" on public.report_cards for select to authenticated using (
  public.is_school_member(school_id)
  or (exists(select 1 from public.student_guardians g where g.school_id=public.report_cards.school_id and g.student_id=public.report_cards.student_id and g.user_id=auth.uid()) and status in ('published','locked'))
  or (public.is_linked_student(school_id,student_id)
      and status in ('published','locked')
      and public.result_has_any_parent_review(school_id,student_id,session_id,term_id))
);


-- Parent/student may resolve only the academic period metadata attached to a result they are entitled to see.
drop policy if exists v22_academic_sessions_linked_read on public.academic_sessions;
create policy v22_academic_sessions_linked_read on public.academic_sessions for select to authenticated using (
  public.is_school_member(school_id)
  or exists(select 1 from public.student_term_results r where r.school_id=academic_sessions.school_id and r.session_id=academic_sessions.id and (public.is_linked_guardian(r.school_id,r.student_id) or public.is_linked_student(r.school_id,r.student_id)) and r.status in ('published','locked'))
);
drop policy if exists v22_academic_terms_linked_read on public.academic_terms;
create policy v22_academic_terms_linked_read on public.academic_terms for select to authenticated using (
  public.is_school_member(school_id)
  or exists(select 1 from public.student_term_results r where r.school_id=academic_terms.school_id and r.term_id=academic_terms.id and (public.is_linked_guardian(r.school_id,r.student_id) or public.is_linked_student(r.school_id,r.student_id)) and r.status in ('published','locked'))
);
drop policy if exists v22_subjects_result_linked_read on public.subjects;
create policy v22_subjects_result_linked_read on public.subjects for select to authenticated using (
  public.is_school_member(school_id)
  or exists(select 1 from public.student_term_results r where r.school_id=subjects.school_id and r.subject_id=subjects.id and (public.is_linked_guardian(r.school_id,r.student_id) or public.is_linked_student(r.school_id,r.student_id)) and r.status in ('published','locked'))
);

-- ============================================================
-- RESULT LIFECYCLE
-- ============================================================
create or replace function public.submit_term_results(target_school uuid,target_session uuid,target_term uuid)
returns integer language plpgsql security definer set search_path=public as $$
declare n integer;
begin
  if not public.can_manage_academics(target_school) then raise exception 'Not authorized'; end if;
  update public.student_term_results set status='submitted',updated_at=now()
   where school_id=target_school and session_id=target_session and term_id=target_term and status='draft';
  get diagnostics n=row_count; return n;
end;$$;
revoke all on function public.submit_term_results(uuid,uuid,uuid) from public;
grant execute on function public.submit_term_results(uuid,uuid,uuid) to authenticated;

create or replace function public.approve_term_results(target_school uuid,target_session uuid,target_term uuid)
returns integer language plpgsql security definer set search_path=public as $$
declare n integer;
begin
  if not public.is_school_admin(target_school) then raise exception 'Only school administrators can approve results'; end if;
  update public.student_term_results set status='approved',updated_at=now()
   where school_id=target_school and session_id=target_session and term_id=target_term and status in ('submitted','review');
  get diagnostics n=row_count; return n;
end;$$;
revoke all on function public.approve_term_results(uuid,uuid,uuid) from public;
grant execute on function public.approve_term_results(uuid,uuid,uuid) to authenticated;

-- Rebuild recalculation so published/locked results are immutable.
create or replace function public.recalculate_term_results(target_school uuid,target_session uuid,target_term uuid)
returns integer language plpgsql security definer set search_path=public as $$
declare cfg record; n integer:=0; r record; g jsonb; existing_status text; calculated numeric;
begin
  if not public.is_school_admin(target_school) then raise exception 'Not authorized'; end if;
  select * into cfg from public.result_configurations where school_id=target_school and session_id=target_session and term_id=target_term;
  if not found then
    insert into public.result_configurations(school_id,session_id,term_id) values(target_school,target_session,target_term) returning * into cfg;
  end if;
  if abs((cfg.ca_weight + cfg.exam_weight)-100) >= .01 then raise exception 'CA and exam weights must total 100'; end if;
  for r in
    select distinct e.student_id,a.subject_id,
      coalesce((select avg((s.score/nullif(a2.max_score,0))*100) from public.assessment_scores s join public.assessments a2 on a2.id=s.assessment_id where s.school_id=target_school and s.student_id=e.student_id and a2.subject_id=a.subject_id and a2.session_id=target_session and a2.term_id=target_term and lower(a2.assessment_type) in ('ca','test','assignment')),0) ca_pct,
      coalesce((select avg((s.score/nullif(a2.max_score,0))*100) from public.assessment_scores s join public.assessments a2 on a2.id=s.assessment_id where s.school_id=target_school and s.student_id=e.student_id and a2.subject_id=a.subject_id and a2.session_id=target_session and a2.term_id=target_term and lower(a2.assessment_type) in ('exam','final')),0) exam_pct
    from public.student_enrollments e
    join public.assessments a on a.school_id=target_school and a.class_id=e.class_id and a.session_id=target_session and a.term_id=target_term
    where e.school_id=target_school and e.session_id=target_session and e.is_current=true
  loop
    select status into existing_status from public.student_term_results where school_id=target_school and student_id=r.student_id and session_id=target_session and term_id=target_term and subject_id=r.subject_id;
    if existing_status in ('published','locked') then continue; end if;
    calculated:=round((r.ca_pct*cfg.ca_weight/100)+(r.exam_pct*cfg.exam_weight/100),2);
    g:=public.grade_for_score(target_school,calculated);
    insert into public.student_term_results(school_id,student_id,session_id,term_id,subject_id,ca_percent,exam_percent,total,grade,remark,grade_point,status,updated_at)
    values(target_school,r.student_id,target_session,target_term,r.subject_id,r.ca_pct,r.exam_pct,calculated,g->>'grade',g->>'remark',(g->>'grade_point')::numeric,'draft',now())
    on conflict(school_id,student_id,session_id,term_id,subject_id) do update set ca_percent=excluded.ca_percent,exam_percent=excluded.exam_percent,total=excluded.total,grade=excluded.grade,remark=excluded.remark,grade_point=excluded.grade_point,updated_at=now()
      where public.student_term_results.status not in ('published','locked');
    n:=n+1;
  end loop;
  update public.student_term_results x set position=r.pos
  from (select id,row_number() over(partition by school_id,session_id,term_id,subject_id order by total desc nulls last) pos from public.student_term_results where school_id=target_school and session_id=target_session and term_id=target_term and status not in ('published','locked')) r
  where x.id=r.id and x.status not in ('published','locked');
  return n;
end;$$;
revoke all on function public.recalculate_term_results(uuid,uuid,uuid) from public;
grant execute on function public.recalculate_term_results(uuid,uuid,uuid) to authenticated;

create or replace function public.publish_term_results(target_school uuid,target_session uuid,target_term uuid)
returns integer language plpgsql security definer set search_path=public as $$
declare n integer; policy text;
begin
  if not public.is_school_admin(target_school) then raise exception 'Not authorized'; end if;
  select publication_policy into policy from public.result_configurations where school_id=target_school and session_id=target_session and term_id=target_term;
  if coalesce(policy,'approval_then_publish')='approval_then_publish' and exists(select 1 from public.student_term_results where school_id=target_school and session_id=target_session and term_id=target_term and status not in ('approved','published','locked')) then
    raise exception 'All results must be approved before publication';
  end if;
  update public.student_term_results set status='published',published_at=coalesce(published_at,now()),updated_at=now() where school_id=target_school and session_id=target_session and term_id=target_term and status='approved';
  get diagnostics n=row_count;
  update public.report_cards set status='published',published_at=coalesce(published_at,now()),updated_at=now() where school_id=target_school and session_id=target_session and term_id=target_term and status in ('draft','review','approved');
  return n;
end;$$;
revoke all on function public.publish_term_results(uuid,uuid,uuid) from public;
grant execute on function public.publish_term_results(uuid,uuid,uuid) to authenticated;

-- ============================================================
-- SERVER-ENFORCED CBT WINDOW
-- ============================================================
alter table public.cbt_attempts add column if not exists server_expires_at timestamptz;
alter table public.cbt_attempts add column if not exists last_server_check_at timestamptz;
create index if not exists idx_cbt_attempts_expiry on public.cbt_attempts(server_expires_at) where status='in_progress';

create or replace function public.start_student_cbt_attempt(target_exam_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); sid uuid; sid_school uuid; attempt uuid; ex public.cbt_exams; existing public.cbt_attempts; expiry timestamptz;
begin
  select sa.student_id into sid from public.student_accounts sa where sa.user_id=uid and sa.status='active' limit 1;
  if sid is null then raise exception 'No linked student account'; end if;
  select e.* into ex from public.cbt_exams e join public.students st on st.id=sid and st.school_id=e.school_id and (e.class_id is null or e.class_id=st.class_id) where e.id=target_exam_id;
  if ex.id is null then raise exception 'Exam is not available for this student'; end if;
  if ex.status not in ('scheduled','live') then raise exception 'This exam is not open'; end if;
  if ex.starts_at is not null and now() < ex.starts_at then raise exception 'This exam has not started yet'; end if;
  if ex.ends_at is not null and now() >= ex.ends_at then raise exception 'This exam has ended'; end if;
  select * into existing from public.cbt_attempts where exam_id=ex.id and student_id=sid;
  if existing.id is not null then
    if existing.status in ('submitted','graded') then return existing.id; end if;
    if existing.status='expired' then raise exception 'Your attempt has expired'; end if;
    if existing.server_expires_at is not null and now() >= existing.server_expires_at then
      update public.cbt_attempts set status='expired',submitted_at=coalesce(submitted_at,now()),last_server_check_at=now() where id=existing.id;
      raise exception 'Your attempt has expired';
    end if;
    update public.cbt_attempts set last_server_check_at=now() where id=existing.id;
    return existing.id;
  end if;
  expiry:=least(coalesce(ex.ends_at,'infinity'::timestamptz),now()+make_interval(mins=>greatest(1,ex.duration_minutes)));
  insert into public.cbt_attempts(school_id,exam_id,student_id,status,max_score,server_expires_at,last_server_check_at)
  select ex.school_id,ex.id,sid,'in_progress',coalesce((select sum(q.points) from public.cbt_questions q where q.exam_id=ex.id),0),expiry,now()
  returning id into attempt;
  return attempt;
end;$$;
revoke all on function public.start_student_cbt_attempt(uuid) from public;
grant execute on function public.start_student_cbt_attempt(uuid) to authenticated;

create or replace function public.save_student_cbt_answer(target_attempt_id uuid,target_question_id uuid,target_answer text)
returns boolean language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); a public.cbt_attempts; q public.cbt_questions; ex public.cbt_exams;
begin
  select * into a from public.cbt_attempts where id=target_attempt_id;
  if a.id is null then raise exception 'Attempt not found'; end if;
  if not exists(select 1 from public.student_accounts where user_id=uid and student_id=a.student_id and status='active') then raise exception 'Not authorized'; end if;
  select * into ex from public.cbt_exams where id=a.exam_id;
  if a.status<>'in_progress' then raise exception 'Attempt is no longer editable'; end if;
  if ex.starts_at is not null and now()<ex.starts_at then raise exception 'Exam has not started'; end if;
  if ex.ends_at is not null and now()>=ex.ends_at then update public.cbt_attempts set status='expired',submitted_at=coalesce(submitted_at,now()),last_server_check_at=now() where id=a.id; raise exception 'Exam time has ended'; end if;
  if a.server_expires_at is not null and now()>=a.server_expires_at then update public.cbt_attempts set status='expired',submitted_at=coalesce(submitted_at,now()),last_server_check_at=now() where id=a.id; raise exception 'Exam time has ended'; end if;
  select * into q from public.cbt_questions where id=target_question_id and exam_id=a.exam_id and school_id=a.school_id;
  if q.id is null then raise exception 'Question does not belong to this exam'; end if;
  insert into public.cbt_answers(school_id,attempt_id,question_id,answer,updated_at) values(a.school_id,a.id,q.id,target_answer,now()) on conflict(attempt_id,question_id) do update set answer=excluded.answer,updated_at=now();
  update public.cbt_attempts set last_activity_at=now(),last_server_check_at=now() where id=a.id;
  return true;
end;$$;
revoke all on function public.save_student_cbt_answer(uuid,uuid,text) from public;
grant execute on function public.save_student_cbt_answer(uuid,uuid,text) to authenticated;

create or replace function public.submit_student_cbt_attempt(target_attempt_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); a public.cbt_attempts; e public.cbt_exams; q record; total numeric:=0; max_total numeric:=0; expired_now boolean:=false;
begin
  select * into a from public.cbt_attempts where id=target_attempt_id;
  if a.id is null then raise exception 'Attempt not found'; end if;
  if not exists(select 1 from public.student_accounts where user_id=uid and student_id=a.student_id and status='active') then raise exception 'Not authorized'; end if;
  select * into e from public.cbt_exams where id=a.exam_id;
  if a.status not in('in_progress','expired') then return jsonb_build_object('score',a.score,'max_score',a.max_score,'status',a.status); end if;
  expired_now:=a.status='expired' or (a.server_expires_at is not null and now()>=a.server_expires_at) or (e.ends_at is not null and now()>=e.ends_at);
  for q in select q.id,q.points,q.correct_answer,coalesce(ans.answer,'') answer from public.cbt_questions q left join public.cbt_answers ans on ans.question_id=q.id and ans.attempt_id=a.id where q.exam_id=a.exam_id and q.school_id=a.school_id order by q.position loop
    max_total:=max_total+coalesce(q.points,0);
    if q.correct_answer is not null and lower(trim(coalesce(q.answer,'')))=lower(trim(q.correct_answer)) then update public.cbt_answers set awarded_points=q.points,updated_at=now() where attempt_id=a.id and question_id=q.id; total:=total+q.points; else update public.cbt_answers set awarded_points=0,updated_at=now() where attempt_id=a.id and question_id=q.id; end if;
  end loop;
  update public.cbt_attempts set status=case when expired_now then 'expired' else 'graded' end,submitted_at=coalesce(submitted_at,now()),score=total,max_score=max_total,last_server_check_at=now() where id=a.id;
  return jsonb_build_object('score',total,'max_score',max_total,'status',case when expired_now then 'expired' else 'graded' end);
end;$$;
revoke all on function public.submit_student_cbt_attempt(uuid) from public;
grant execute on function public.submit_student_cbt_attempt(uuid) to authenticated;

-- ============================================================
-- SECURE SCHOOL CREATION RPC
-- ============================================================
create or replace function public.create_school_v22(
  school_name text,
  school_ownership text,
  school_levels text[] default '{}',
  school_timezone text default 'Africa/Lagos',
  school_address text default '',
  school_phone text default '',
  academic_year text default ''
) returns uuid language plpgsql security definer set search_path=public as $$
declare new_school uuid; base_slug text; final_slug text; n integer:=0;
begin
  school_ownership:=case lower(trim(coalesce(school_ownership,'')))
    when 'private' then 'private_school' when 'private school' then 'private_school' when 'private_school' then 'private_school'
    when 'federal' then 'federal_government' when 'federal government' then 'federal_government' when 'federal government school' then 'federal_government' when 'federal_government' then 'federal_government'
    when 'state' then 'state_government' when 'state government' then 'state_government' when 'state government school' then 'state_government' when 'state_government' then 'state_government'
    when 'public' then 'other_public' when 'other public' then 'other_public' when 'other public school' then 'other_public' when 'other_public' then 'other_public'
    else '' end;
  if auth.uid() is null then raise exception 'You must be signed in'; end if;
  if trim(coalesce(school_name,''))='' then raise exception 'School name is required'; end if;
  if school_ownership='' then raise exception 'Select a valid school ownership type'; end if;
  if exists(select 1 from unnest(coalesce(school_levels,'{}'::text[])) as u(v) where lower(trim(v)) not in ('nursery','primary','secondary','jss','sss')) then raise exception 'Invalid school level. Choose Nursery, Primary, or Secondary.'; end if;
  school_levels:=coalesce((select array_agg(distinct normalized_level order by normalized_level) from (select case lower(trim(v)) when 'secondary' then 'jss' when 'nursery' then 'nursery' when 'primary' then 'primary' when 'jss' then 'jss' when 'sss' then 'sss' end as normalized_level from unnest(coalesce(school_levels,'{}'::text[])) as u(v) where nullif(trim(v),'') is not null) levels where normalized_level is not null),'{}'::text[]);
  if coalesce(array_length(school_levels,1),0)=0 then raise exception 'Select at least one school level'; end if;
  if exists(select 1 from unnest(coalesce(school_levels,'{}'::text[])) as u(level) where level not in ('nursery','primary','jss','sss')) then raise exception 'Invalid school level. Choose Nursery, Primary, or Secondary.'; end if;
  base_slug:=public.slugify_school_name(school_name); if base_slug='' then base_slug:='school'; end if; final_slug:=base_slug;
  while exists(select 1 from public.schools where slug=final_slug) loop n:=n+1; final_slug:=base_slug||'-'||n; end loop;
  insert into public.schools(name,school_type,school_ownership,school_levels,slug,timezone) values(trim(school_name),school_ownership,school_ownership,school_levels,final_slug,coalesce(nullif(school_timezone,''),'Africa/Lagos')) returning id into new_school;
  insert into public.school_memberships(school_id,user_id,role,status) values(new_school,auth.uid(),'owner','active');
  if not exists(select 1 from public.school_memberships where school_id=new_school and user_id=auth.uid() and role='owner' and status='active') then
    raise exception 'School was created but owner membership could not be established';
  end if;
  insert into public.school_settings(school_id,current_session,current_term,grading_scale,settings) values(
    new_school,
    coalesce(nullif(trim(academic_year),''),'2026/2027'),
    'First Term',
    '[{"grade":"A1","min":75,"max":100,"remark":"Excellent"},{"grade":"B2","min":70,"max":74,"remark":"Very Good"},{"grade":"B3","min":65,"max":69,"remark":"Good"},{"grade":"C4","min":60,"max":64,"remark":"Credit"},{"grade":"C5","min":55,"max":59,"remark":"Credit"},{"grade":"C6","min":50,"max":54,"remark":"Credit"},{"grade":"D7","min":45,"max":49,"remark":"Pass"},{"grade":"E8","min":40,"max":44,"remark":"Pass"},{"grade":"F9","min":0,"max":39,"remark":"Fail"}]'::jsonb,
    jsonb_build_object('address',trim(coalesce(school_address,'')),'phone',trim(coalesce(school_phone,'')),'academic_year',trim(coalesce(academic_year,'')),'onboarding_complete',true)
  ) on conflict do nothing;
  insert into public.website_settings(school_id,headline,subheadline) values(new_school,'Everything your school needs. One platform.','Smart infrastructure for modern schools.') on conflict do nothing;
  insert into public.subscriptions(school_id,plan_code,status) values(new_school,'starter','trialing') on conflict do nothing;
  perform public.bootstrap_first_platform_admin();
  return new_school;
exception when others then raise;
end;$$;
revoke all on function public.create_school_v22(text,text,text[],text,text,text,text) from public;
grant execute on function public.create_school_v22(text,text,text[],text,text,text,text) to authenticated;

-- ============================================================
-- PARENT LINK CODE: admin-only management remains in place.
-- Ensure only authenticated school admins can rotate/reveal codes.
-- ============================================================
revoke all on function public.rotate_parent_link_code(uuid) from public,anon;
grant execute on function public.rotate_parent_link_code(uuid) to authenticated;

-- V22 complete.
