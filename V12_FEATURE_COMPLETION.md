# Edvora V12 feature map

V11 overstated the completeness of several items. V12 makes the implemented areas discoverable in the UI and fixes the core configuration and teacher workflow. Some provider integrations still require provider credentials and production verification before they can be called "live".

## Implemented and visible
- Assignments and submission foundation: `/assignments`
- School calendar: `/calendar`
- AI workspace: `/ai`
- Offline queue/service-worker foundation: `lib/offline.js`, `public/sw.js`
- Notification records: AppShell notification popover and delivery table
- SMS / WhatsApp / push provider slots: `/integrations`
- Global search: AppShell search
- Student documents: student/document schema foundation
- Teacher documents: teacher/document schema foundation
- Admissions and enrollment: `/admissions`
- Promotion: `/promotion`
- Grading: `/grading`
- Report-card configuration: `/reports`, `/report-cards/[studentId]`
- Finance adjustments/refunds/ledger schema: `/fees`
- Recurring billing history/webhooks: `/pricing`
- Platform super admin: `/super-admin`
- Data export/deletion/consent/retention controls: `/data-governance`
- Backup/DR tracking: schema + operations surface
- Integrations/provider registry: `/integrations`
- Imports: `/imports`
- Support: `/support`
- Login/security telemetry: `/security`
- Audit: `/audit`
- Analytics/health: `/analytics`
- Accessibility preference storage: schema foundation
- Platform operations directory: `/operations`
- Custom school domains: schema foundation

## Infrastructure that still needs provider/production setup
- Real SMS sending
- Real WhatsApp sending
- Web Push delivery service worker + VAPID/provider configuration
- Paystack/Flutterwave live credentials and webhook verification
- Resend domain/API configuration
- OpenAI API configuration
- Supabase Storage bucket/policies for all document/media workflows
- Scheduled backup/retention jobs
- Production rate limiting and observability provider
- MFA enforcement policy and session-risk controls
- Automated browser/e2e suite

## V12 fixes
- Browser Supabase configuration can now use the publishable key, legacy public anon key, or server-injected `SUPABASE_ANON_KEY`.
- Server Supabase helpers now fail with a useful configuration message instead of `supabaseKey is required`.
- Added `/configuration` setup page.
- Teacher creation now goes through a protected server route and can create an invitation automatically.
- Accepting a teacher invitation updates an existing teacher profile instead of creating a duplicate.
- Added `/operations`, `/data-governance`, and `/security` to make previously hidden operational systems discoverable.
- Loading/error states use the colourful Edvora logo.
- Favicon and Apple touch icon use the colourful Edvora symbol.
