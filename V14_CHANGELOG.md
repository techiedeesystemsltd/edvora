# Edvora V14

## Fixed
- Public school websites no longer require `SUPABASE_SERVICE_ROLE_KEY` just to render.
- Published school branding is publicly readable so hero/logo assets can render on public school sites. Sensitive school/student buckets remain private.
- Added `force-dynamic`/no-cache behavior for the public school page so website edits appear without stale Next.js output.
- Added a visible public school URL in the Website module even while the site is draft.
- Added first-platform-admin bootstrap: the first active school owner claims the platform-admin slot once; later owners do not.
- Added platform-admin school-directory RLS access.
- Existing schools get starter website settings/pages through the V14 upgrade.
- Onboarding also attempts the platform bootstrap for both new and existing owner flows.

## Still requires production setup
- Vercel environment variables must still be configured.
- Supabase SQL upgrade must be executed.
- Contact-form email delivery still requires the configured server-side Resend variables.
- Custom school domains are modeled in the database but are not yet routed by hostname.
