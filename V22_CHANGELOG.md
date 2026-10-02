# Edvora V22 — Results, CBT, Student Portal & School Setup

## Fixed

### School creation
- Replaced the broken school-type dropdown with explicit school ownership values.
- Added multi-select school levels: Nursery, Primary, JSS, SSS.
- Added `create_school_v22(...)` as the atomic server-side school creation RPC.
- Removed the broken `.rpc(...).catch(...)` chaining pattern from the onboarding API.
- School creation now stores ownership, levels, timezone, contact details and academic-year onboarding state in one transaction.

### Results
- Added result lifecycle: Draft → Submitted → Approved → Published → Locked.
- Recalculation no longer overwrites published/locked result records.
- Publication can require approval.
- Added parent-first result release workflow.
- A linked parent/guardian can review a published result.
- Student result access is blocked until at least one linked parent has reviewed that session/term.
- Parent portal now displays the actual subject results before the release confirmation.
- Student portal now reads canonical `student_term_results` instead of raw assessment scores for final results.

### Parent linking
- Parent linking remains code-only and school-scoped.
- Parent IDs remain hashed in the database; plaintext codes are never stored.
- Student admin page no longer attempts to read the removed plaintext `code` column.
- Admins can generate/rotate a Parent ID from the student register and copy the newly issued code.

### CBT
- Exam start is server-enforced against `starts_at`, `ends_at`, status and student/class eligibility.
- Each attempt receives a server-calculated `server_expires_at`.
- Answer saves are rejected after the server expiry or exam end.
- Submit is server-authoritative and grades the saved answers even when the attempt expires.
- Client countdown is based on server expiry, not a client-created timer.
- Attempt creation now happens when the student actually starts the exam, after fullscreen requirements are satisfied.
- Periodic server status checks detect an expired attempt while the exam is open.

## Database migration
Apply:

`supabase/EDVORA_V22_RESULTS_CBT_ONBOARDING.sql`

after the existing Edvora V18/V21 schema upgrades.

## Validation
- V18 JavaScript syntax checks: passed.
- Existing V18 production static checks: passed.
- V22 SQL static symbol checks: passed.
- Live Supabase/E2E validation still requires a configured Supabase project and browser session.
