# Edvora V16 — production hardening pass

This build changes source code and SQL; it is not a claim that external providers or a live Supabase project have been executed from this environment.

## Implemented in source
- operational health dashboard with realtime school-scoped signals
- unified notification dispatch API with in-app, Resend email, Termii SMS and WhatsApp Cloud API adapters
- provider configuration checks that never fake a connected state
- CSV import preview, column mapping, validation snapshot and tracked import jobs
- data export/deletion/retention/consent operational UI
- connectivity/offline banner and reduced-motion/focus/mobile accessibility rules
- production CSP/security headers
- system incident school scoping
- stronger assignment and calendar permissions
- corrected teacher behaviour policy qualification
- backup verification/restore-test fields
- notification retry metadata
- message attachments/read receipt fields
- production test script

## Still provider/environment dependent
- actual Supabase execution of migrations/RLS
- scheduled backup provider + restore execution
- browser push delivery requires a Web Push provider/library and VAPID secrets
- live Paystack/Flutterwave/Resend/Termii/WhatsApp/OpenAI credentials
- malware scanning for uploads
- full browser E2E on iPhone/Android/tablet
