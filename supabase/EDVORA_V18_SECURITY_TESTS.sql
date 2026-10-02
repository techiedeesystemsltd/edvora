-- Run in Supabase SQL editor with a test authenticated session.
-- These assertions are intentionally explicit; run them in a disposable test project.

-- Tenant boundary: a school member must never read another school's canonical results.
-- Replace :school_a and :school_b with test UUIDs and execute as a school-A user.
select count(*) as cross_tenant_results
from public.student_term_results
where school_id = ':school_b'::uuid;

-- Locked result mutation should be denied by application workflow and must not be exposed
-- to direct update paths for ordinary school users.
select status,locked_at
from public.student_term_results
where school_id = ':school_a'::uuid and status='locked'
limit 5;

-- CBT correct answers must not be exposed by the student RPC.
-- The returned question objects contain id/question_text/question_type/options/points/position only.

-- Parent boundary: linked guardian can only read linked student's published results.
select id,student_id,total,grade,status
from public.student_term_results
where school_id=':school_a'::uuid and status in ('published','locked')
order by student_id;

-- Finance duplicate provider reference must fail at the database uniqueness layer.
-- Use a disposable transaction when testing duplicate insertion.
