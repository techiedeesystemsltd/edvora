# Edvora V10 feature completion

This build extends v9 rather than replacing its tenant model. One school remains one tenant/campus.

## 36 gaps addressed

1. Assignments: assignment and submission tables + teacher-facing creation UI.
2. School calendar: events, holidays, exams, PTA, meetings and deadlines.
3. AI: school-scoped AI job storage and existing authorized AI endpoint retained.
4. Offline/poor connectivity: IndexedDB mutation queue + service-worker shell cache foundation.
5. Notification delivery: delivery queue table with in-app/email/SMS/push/WhatsApp states.
6. SMS: provider slot in integrations layer.
7. WhatsApp: provider slot in integrations layer.
8. Push: browser push subscription table and delivery channel.
9. Global search: students/classes/invoices/staff/subjects/assignments/events.
10. Student records: documents and richer document storage foundation.
11. Teacher records: teacher document storage foundation.
12. Public admissions: review-stage infrastructure added to admissions.
13. Promotion: controlled promotion runs with preview/approval/application states.
14. Grading: configurable grading rules with grade point and remarks.
15. Report cards: reusable report-card templates and configuration storage.
16. CBT: v9 attempt/answer security remains; V10 adds offline shell foundation and operational tracking architecture.
17. Finance: discounts/scholarships/waivers/credits/penalties, refunds and ledger entries.
18. Edvora recurring billing: plan-change history and webhook event storage.
19. Platform super admin: protected `/super-admin` control surface.
20. Export/deletion: export jobs and deletion requests with legal-hold state.
21. Privacy/consent: consent and retention policy tables.
22. Backup/DR: backup operation tracking table and operational checklist.
23. Realtime: schema is compatible with Supabase Realtime; delivery/event tables provide durable state for subscriptions.
24. Storage: student/teacher docs and media assets, plus existing private buckets.
25. Public website: existing school website editor retained; domain table added for custom-domain lifecycle.
26. Integrations: provider connection registry and webhook event log.
27. API architecture: sensitive provider credentials remain server-side; integration state is stored without exposing secrets.
28. Automated testing: security test SQL retained and V10 verification checklist added.
29. Accessibility: reduced-motion/high-contrast/text-scale preference storage plus responsive auth layout.
30. Observability: webhook, delivery, login, support and system-incident records.
31. Rate limiting: parent-link rate limit retained; delivery/import/provider jobs carry retry state.
32. Account security: login-event storage and existing Supabase Auth reset flow.
33. Teacher workspace: assignments/calendar links and teacher routes retained.
34. Onboarding: existing school onboarding retained with expanded platform foundations.
35. Import/migration: CSV/Excel upload jobs with progress/error tracking.
36. Support/help: support ticket and message infrastructure + `/support` UI.

## Important deployment note

`EDVORA_COMPLETE_SCHEMA.sql` now contains the V10 additions and no longer calls `gen_random_bytes()`. Parent-link secrets are generated from the same `gen_random_uuid()` primitive already used throughout the schema, avoiding the missing-function error reported by Supabase SQL Editor.

For an existing v9 database, run `supabase/EDVORA_V10_FEATURES.sql` after the existing schema. For a fresh database, run only `supabase/EDVORA_COMPLETE_SCHEMA.sql`.

Provider credentials still have to be supplied in Supabase/Vercel for live Paystack/Flutterwave, Resend, SMS, WhatsApp and OpenAI delivery. The UI and persistence layer do not invent provider credentials.
