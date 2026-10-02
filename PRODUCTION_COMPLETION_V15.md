# V15 completion status

Implemented in source and SQL:
- school website CMS and public website
- public admissions and server-generated application numbers
- student profile expansion
- teacher workspace expansion
- assignment workflow foundation
- attendance workflow foundation
- report-card data expansion
- CBT hardening fields
- finance expense/reconciliation foundation
- parent portal expansion
- notification preferences/delivery foundation
- messaging read state
- data import/security/governance foundations retained
- Super Admin bootstrap and platform controls retained
- public custom-domain routing
- security headers and public form rate limiting
- sitemap/robots
- source smoke testing

Requires external staging/provider verification rather than code-only validation:
- Paystack live/subscription/webhook behavior
- Resend deliverability
- SMS/WhatsApp provider delivery
- browser push delivery
- OpenAI production behavior
- automated browser E2E against a real Supabase project
- actual database migration execution
- database backup/restore drills
