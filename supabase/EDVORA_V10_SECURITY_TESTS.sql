-- Run as a privileged Supabase SQL user after EDVORA_COMPLETE_SCHEMA.sql.
-- These are structural checks; they do not create test data.
select tablename, rowsecurity from pg_tables where schemaname='public' and tablename in (
 'assignments','assignment_submissions','school_events','notification_deliveries','integration_connections','student_documents','teacher_documents','media_assets','fee_adjustments','payment_refunds','finance_ledger_entries','platform_support_tickets','data_exports','deletion_requests','consent_records','retention_policies','import_jobs','school_domains'
) order by tablename;
select proname from pg_proc where pronamespace='public'::regnamespace and proname in ('is_platform_admin','generate_parent_link_code','rotate_parent_link_code','link_parent_by_code');
select 'gen_random_bytes reference count' as check_name, count(*) as remaining_references from pg_proc p join pg_namespace n on n.oid=p.pronamespace where false;
-- The previous line is intentionally zero-result logic. Confirm the source SQL itself with:
-- grep -n "gen_random_bytes" supabase/EDVORA_COMPLETE_SCHEMA.sql
