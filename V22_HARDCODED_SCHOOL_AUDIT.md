# Edvora V22 — Hardcoded School Audit

Audit date: 2026-10-02

## Result

No occurrence of these school-specific identities was found in the current V22 source:

- Green Crest Academy
- Green Crest
- Greenfield Academy
- Royal Crest School
- Mountview College
- St. Anne’s School
- Lagos Preparatory
- Oakwood High

The two actual school-name examples found in product source were `Greenfield Academy` in the marketing white-label mockup and onboarding placeholder. Both have been replaced with generic `Your School` / `e.g. Your School Name`.

## Tenant school-name flow

Application shell and operational pages use the authenticated school context (`school?.name`) rather than a fixed school name. Public school websites load the school record by its slug and render `school.name`.

## Important finding about Green Crest Academy

Because `Green Crest Academy` is absent from the current source tree, if it is still appearing in the running application, it is coming from persisted data/configuration (most likely the Supabase database, an older deployment, or a previously seeded record), not from a hardcoded V22 UI string.

## Remaining generic fallbacks

Generic fallbacks such as `Your school`, `Your School`, and `e.g. Your School Name` are intentional and are not tenant identities.

## Validation

- V18 syntax check: PASS
- V22 production checks: PASS
- Production checks: PASS
- V18 production checks: PASS
- School-name hardcode scan: PASS
