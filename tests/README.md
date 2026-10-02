# Edvora production test plan

The repository includes `npm run test:smoke` for deterministic source/syntax checks. Before production launch, run browser E2E tests against a real Supabase project for:

- signup/onboarding
- two-school tenant isolation
- owner/admin/teacher/bursar/staff permissions
- public school website and admissions
- student/teacher/parent portals
- attendance/results/report cards
- assignments/CBT
- fees/Paystack webhooks/refunds
- invitations/password reset/MFA
- imports/exports/deletion
- custom domains
- contact/admission rate limits

The Supabase SQL upgrade should be executed in a staging project first, followed by the tenant security SQL suite.
