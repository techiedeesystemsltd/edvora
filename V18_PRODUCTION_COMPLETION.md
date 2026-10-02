# Edvora V18 Production Completion

V18 closes the eight identified workstreams:

1. Results engine: configurable CA/exam weighting, canonical subject results, grade/ranking calculation, publication and locking, correction-request infrastructure, result PIN storage.
2. CBT: dedicated fullscreen route, fullscreen enforcement UX, autosave/local queue, reconnect sync, timer, question navigator, flags, integrity events, secure result visibility.
3. Security: V18 RLS tables, security events, session-device records, tenant-scoped result/finance/observability access.
4. Finance: payment idempotency keys, provider-reference uniqueness, reconciliation foundation, ledger indexes and finance controls.
5. Operations: integration health, observability events, security events and existing backup/retention infrastructure are wired into the V18 data model.
6. Portals: existing V17 parent/student/teacher routes remain the integrated portal surface; V18 protects result/CBT data at the database function layer.
7. UX/accessibility/mobile: V18 CBT is mobile-aware, keyboard/focus compatible, reduced-motion compatible through existing V17 design tokens, and uses the separate examination visual mode.
8. Validation: static syntax and V18 production checks are included. Live Supabase, browser E2E, and Vercel deployment checks must be run against the target environment with real credentials; V18 does not falsely report those as verified.

## Required deployment order

1. Apply the existing Edvora schema/V17 migrations.
2. Apply `supabase/EDVORA_V18_PRODUCTION_UPGRADE.sql`.
3. Configure Supabase/Vercel environment variables.
4. Run `npm install`.
5. Run `npm run test:v18`.
6. Run `npm run build`.
7. Run the existing production smoke/security checks against the configured Supabase project.
8. Run browser E2E against a seeded two-school environment, including cross-tenant attack cases.
