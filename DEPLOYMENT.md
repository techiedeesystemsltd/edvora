# Edvora v7 deployment

## Vercel environment variables
Required:
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `NEXT_PUBLIC_APP_URL`

Paystack:
- `NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY`
- `PAYSTACK_SECRET_KEY`

Resend:
- `RESEND_API_KEY`
- `EMAIL_FROM`

Never put the Supabase service role key in a `NEXT_PUBLIC_*` variable.

## Supabase migration
Run:
- `supabase/schema-v2-single-campus.sql`
- `supabase/schema-v3-production.sql`

## Paystack webhook
Configure:
`https://YOUR_DOMAIN/api/billing/paystack/webhook`

The endpoint verifies `x-paystack-signature` with the server-only Paystack secret before writing subscription/payment state.

## Email
Resend is used for staff invitations when `RESEND_API_KEY` and `EMAIL_FROM` are configured.

## White-label school sites
School slugs are generated automatically. Publish a school in Settings, then use:
`/school/{slug}`

## Build validation
The source was JSX/JavaScript parse-validated in the build environment. A full `npm run build` may require network access to install the project's npm dependencies if `node_modules` is not already present.

## V4 complete migration
After v2 and the repaired v3 migration, run:
- `supabase/schema-v4-complete.sql`

This adds secure per-student Parent IDs, parent linking, grading/report-card generation, CBT student functions, timetable, admissions, promotion, notification fan-out, tenant-integrity triggers, stricter role access, messaging restrictions, audit retention, and billing hardening.

## Parent linking
Every student receives an automatically generated high-entropy Parent ID. It is stored in a dedicated school-scoped table with admin-only RLS. Parents do not have SELECT access to the code table. Linking is performed by the authenticated `link_parent_by_code` function and the resulting guardian record remains tenant-scoped.

## Recurring Paystack billing
Create recurring plans in Paystack and set the corresponding `PAYSTACK_PLAN_<PLAN>_<CYCLE>` environment variables. The application will refuse to start a subscription checkout when the provider plan code is missing instead of silently treating it as a one-time subscription.

## V15 production completion

For a new database, run `supabase/EDVORA_COMPLETE_SCHEMA_V15.sql`.
For an existing V14 database, run `supabase/EDVORA_V15_UPGRADE.sql` after the V14 migration.

Required public client variables:
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (or legacy `NEXT_PUBLIC_SUPABASE_ANON_KEY`)

Server-side integrations remain optional until configured:
- `SUPABASE_SERVICE_ROLE_KEY` for protected server operations such as public contact notifications
- `RESEND_API_KEY` + `EMAIL_FROM` for email delivery
- Paystack variables for online school payments/subscriptions
- `OPENAI_API_KEY` for AI

After deployment:
1. Run the smoke test locally with `npm run test:smoke`.
2. Apply the SQL to a staging Supabase project.
3. Run the tenant security SQL tests.
4. Create a school and publish its website.
5. Test `/school/<slug>` and `/school/<slug>/apply` from a logged-out browser.
6. Verify the first active school owner appears under Platform → Super Admin.
7. Configure any custom hostname in `school_domains` and point DNS at the Vercel project.
