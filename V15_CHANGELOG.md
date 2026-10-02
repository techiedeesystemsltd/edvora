# Edvora V15 Production Completion

V15 is the production-completion pass over the V14 baseline.

## Public school website
- Full published school-site shell with navigation, admissions CTA, contact, principal message, staff, news and gallery sections.
- Website CMS supports page creation, editing, ordering, drafts, publishing and revision snapshots.
- SEO title/description, Open Graph image field, social links, favicon field and public sitemap/robots support.
- Public admissions application flow with database-generated `APP-YYYY-000001` numbers.
- Public school custom-domain hostname routing through `school_domains`.
- Published school branding assets remain public; sensitive school data remains RLS-protected.

## School operations
- Rich student profile fields, documents, guardians, behaviour, scholarships and lifecycle requests.
- Teacher workspace expanded with assigned classes/subjects, timetable, assignments and lesson notes.
- Parent portal expanded with assignments, timetable, results, fees and notifications.
- Finance workspace for expenses and reconciliation foundations.
- CBT configuration fields for randomized questions/options, attempts, instructions and pass mark.
- Report-card fields for attendance, behaviour, skills, position and promotion recommendation.
- Notification preferences and message read state.

## Security / reliability
- Public contact and admissions request rate limiting.
- Security headers.
- Smoke test script and production E2E test plan.
- Custom-domain routing support.
- Public sitemap and robots endpoints.

## Database
Fresh database: run `supabase/EDVORA_COMPLETE_SCHEMA_V15.sql`.
Existing V14 database: run `supabase/EDVORA_V15_UPGRADE.sql` after the previous migrations.

External providers still require real credentials and staging/production verification: Paystack, Resend, SMS, WhatsApp, push, OpenAI, and any monitoring provider.
