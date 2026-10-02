-- Static regression checks for CI / review.
-- These checks are intentionally source-level and do not pretend to be a live Supabase test.
do $$ declare src text; begin
  select string_agg(pg_get_policydef(p.oid), E'\n') into src from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('assignments','school_events','student_behaviour_records','messages','notification_preferences');
  if src is null then raise exception 'Expected RLS policies are missing'; end if;
  if position('is_school_member' in src)=0 then raise exception 'Tenant membership predicates missing'; end if;
  if position('teacher_user_id' in src)=0 then raise exception 'Teacher assignment predicates missing'; end if;
end $$;
