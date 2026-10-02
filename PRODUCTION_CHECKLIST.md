# Edvora production checklist

- [ ] Run `supabase/EDVORA_COMPLETE_SCHEMA.sql` in a fresh Supabase project.
- [ ] Run tenant security tests in a controlled test project.
- [ ] Configure `NEXT_PUBLIC_SUPABASE_URL` and publishable/anon key.
- [ ] Configure Paystack keys and verify webhook signature.
- [ ] Configure Resend sender/domain.
- [ ] Configure `OPENAI_API_KEY` only if Edvora AI is enabled.
- [ ] Configure Storage bucket policies from the complete schema.
- [ ] Test two schools with separate users and attempt cross-tenant reads/writes.
- [ ] Test parent linking with valid, invalid, rotated and expired Parent IDs.
- [ ] Test role restrictions for owner/admin/bursar/teacher/parent/student.
- [ ] Test CBT timer refresh, autosave and submission.
- [ ] Test payment webhook replay/idempotency and invoice balances.
- [ ] Test report card generation and publishing.
- [ ] Test website draft vs published visibility.
- [ ] Test backups, retention and incident procedures before production student data.
- [ ] Run `npm install` and `npm run build` in a networked CI/Vercel environment.
