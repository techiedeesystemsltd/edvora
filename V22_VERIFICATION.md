# Edvora V22 Verification

This release includes three verification layers:

## 1. Static/source checks

```bash
npm install
npm run test:syntax
npm run test:production
npm run test:v18
npm run test:v22
npm run build
```

`npm run build` is intentionally part of the release gate. Do not mark a deployment production-ready until it passes.

## 2. Live Supabase integration/security test

Set these locally (never expose the service role key to the browser):

```bash
export NEXT_PUBLIC_SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
export NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY="YOUR_PUBLISHABLE_KEY"
export SUPABASE_SERVICE_ROLE_KEY="YOUR_SERVICE_ROLE_KEY"
```

Apply the database migrations in their intended order, ending with:

```text
supabase/EDVORA_V22_RESULTS_CBT_ONBOARDING.sql
```

Then run:

```bash
npm run test:live
```

The live test creates temporary users and two schools, then verifies:

- school ownership aliases work through the real RPC;
- invalid school levels are rejected by the database;
- a linked parent can read a published result;
- a linked student cannot read it before parent review;
- the student can read it after parent review;
- a parent from another school cannot read the result;
- a student from another school cannot read the result;
- CBT cannot start before `starts_at`;
- CBT starts when its window is open;
- `server_expires_at` is set server-side;
- answers are rejected after the server-side exam end;
- expired attempts are marked `expired`.

The test cleans up its temporary schools and auth users.

## 3. Browser E2E

`scripts/v22-browser-e2e.mjs` checks the deployed login/signup pages and, when test credentials are provided, authenticates and verifies the onboarding ownership selector.

It requires a Node Playwright installation in the environment running the test.

```bash
EDVORA_BASE_URL="https://YOUR_EDVORA_DEPLOYMENT" \
EDVORA_E2E_EMAIL="test@example.com" \
EDVORA_E2E_PASSWORD="..." \
node scripts/v22-browser-e2e.mjs
```

## Security note

The application must never receive `SUPABASE_SERVICE_ROLE_KEY`. It is only for controlled integration tests/administration. Keep it in CI secrets or a local secure environment.
