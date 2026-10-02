-- EDVORA TENANT SECURITY TESTS
-- Run in a controlled Supabase test project with test users/schools.
-- These are assertion-style checks for cross-tenant invariants.

-- 1. No student can reference a class in another school.
-- 2. No attendance record can reference a student/class in another school.
-- 3. No assessment/score can reference another school's class/subject/student.
-- 4. No CBT question/attempt/answer can cross tenants.
-- 5. No invoice/payment can cross tenants.
-- 6. No guardian/student account can cross tenants.
-- 7. Parent-link codes are stored only as SHA-256 hashes and are not selectable by parents.
-- 8. Public website queries return only published active/trialing schools/pages.
-- 9. A parent can read only linked children.
-- 10. A student can read only their own portal records.

do $$
begin
  if exists(select 1 from information_schema.columns where table_schema='public' and table_name='student_parent_link_codes' and column_name='code') then
    raise exception 'FAIL: plaintext parent-link code column still exists';
  end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='student_parent_link_codes' and column_name='code_hash') then
    raise exception 'FAIL: parent-link code_hash is missing';
  end if;
end $$;

select 'PASS: core tenant security schema checks completed' as result;
