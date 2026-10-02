# Edvora

Edvora is a multi-tenant school operating system for Nigerian schools.

## Database

For a fresh Supabase project, run exactly:

`supabase/EDVORA_COMPLETE_SCHEMA.sql`

It is the single source of truth and contains the core schema, production workflows, tenant security hardening, secure parent-link IDs, billing tables, communications, website, CBT, audit and operational indexes.

Then optionally run `supabase/EDVORA_TENANT_SECURITY_TESTS.sql` in a controlled test project.

## Environment

Copy `.env.example` to `.env.local` and configure Supabase. Never expose `SUPABASE_SERVICE_ROLE_KEY`, `PAYSTACK_SECRET_KEY`, `RESEND_API_KEY` or `OPENAI_API_KEY` to the browser.

## Parent linking

Every student receives a high-entropy Parent ID automatically. Only its SHA-256 hash is stored. Parents submit the code after signing in, and the server-side function creates the guardian relationship for that exact tenant/student. Codes can be rotated and expire after one year by default.

## V12 deployment notes

- If the browser says `supabaseKey is required`, configure `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` in Vercel and redeploy. `NEXT_PUBLIC_SUPABASE_ANON_KEY` and server-side `SUPABASE_ANON_KEY` are also supported as fallbacks.
- `/configuration` shows the required environment setup.
- Fresh Supabase install: run `supabase/EDVORA_COMPLETE_SCHEMA.sql` only.
- Existing V10/V11 database: run `supabase/EDVORA_V12_UPGRADE.sql` after the existing schema.
- Add a teacher from `/teachers`. If an email is supplied, Edvora creates the teacher profile and invitation together.
- Provider modules in `/integrations` are configuration surfaces. Live SMS, WhatsApp, push, payment, email and AI delivery still require real provider credentials and production webhook/provider verification.


## V13 fixes
- Student admission numbers are generated automatically as `ADM-YYYY-0001` style identifiers.
- Class creation uses a protected server route and is restricted to school owners/admins.
- Calendar/Timetable is now an interactive weekly class timetable. Admins select a class and can add/edit/remove periods.
- Teachers see only timetable periods for subjects assigned to them and have read-only access.
- Dashboard typography has been normalized to a consistent readable scale.
- Existing V12 databases should run `supabase/EDVORA_V13_UPGRADE.sql`.


## V14 reliability fixes
- The public school website no longer depends on the Supabase service-role key to render published pages. It uses public Supabase access plus public school-branding assets.
- The first active school owner is bootstrapped as the Edvora platform administrator exactly once. Later school owners remain school-scoped.
- Platform administrators can read the school directory.
- Existing schools receive missing starter website settings/pages from the V14 upgrade.
- Run `supabase/EDVORA_V14_UPGRADE.sql` after V13 on an existing database.
