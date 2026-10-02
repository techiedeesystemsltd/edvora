# Edvora authentication email setup — Resend SMTP

Edvora uses Supabase Auth for account creation and password recovery. For production, **Supabase Auth should send those emails through Resend SMTP**. The application does not put the Resend API key in browser code.

## 1. Resend

1. Create/sign in to your Resend account.
2. Add and verify the domain you will use for Edvora authentication.
3. Configure the DNS records Resend provides (SPF/DKIM; DMARC is recommended).
4. Create an API key with the minimum permissions needed for SMTP sending.

Resend SMTP settings:

- Host: `smtp.resend.com`
- Port: `465` (SSL)
- Username: `resend`
- Password: your Resend API key
- From address: for example `Edvora <no-reply@auth.yourdomain.com>`

Resend documents port 465 as the recommended SSL option.

## 2. Supabase Auth SMTP

In **Supabase → Authentication → SMTP / Custom SMTP**, enable custom SMTP and enter the Resend values above. Supabase's hosted default SMTP is intended for testing and has significant limits; current documentation says the default service is currently limited to 2 messages/hour. Custom SMTP is the production path.

After enabling custom SMTP, configure the Auth rate limits appropriate for your real usage. Supabase notes that newly configured custom SMTP starts with a low rate limit of 30 messages/hour until adjusted.

## 3. Supabase URL configuration

In **Supabase → Authentication → URL Configuration**:

- **Site URL:** your real Edvora production URL, e.g. `https://edvora.example.com`
- Redirect URL: `https://edvora.example.com/auth/callback`
- Local development: `http://localhost:3000/auth/callback`

Supabase requires the redirect URL used by Auth to be present in the allow-list. The Site URL is also important for confirmation and password-reset links.

## 4. Authentication provider

In **Authentication → Providers → Email**:

- Email provider: **enabled**
- Confirm email: **enabled** for Edvora's normal school-owner signup flow

## 5. Edvora email flows

### New school owner

`/signup` → Supabase `signUp()` → confirmation email → `/auth/callback?next=/onboarding` → `/onboarding`

### Resend confirmation

`/login?confirmed=1` → `/api/auth/resend-confirmation` → Supabase Auth → Resend SMTP

The UI now enforces a 60-second resend cooldown so repeated test clicks do not immediately consume the Auth email rate limit.

### Password reset

`/forgot-password` → Supabase `resetPasswordForEmail()` → Resend SMTP → `/auth/callback?next=/reset-password` → `/reset-password`

## 6. Email templates

Configure these in **Supabase → Authentication → Email Templates**:

- Confirm signup
- Reset password
- Invite user
- Change email address
- Security notifications as required

Use `{{ .ConfirmationURL }}` for confirmation/reset links unless you deliberately implement a custom token-hash flow. Supabase documents `{{ .ConfirmationURL }}`, `{{ .RedirectTo }}`, and the other supported template variables.

Keep authentication mail operational rather than promotional: clear Edvora branding, one primary action, minimal extra links, and no marketing content.

## 7. Resend API vs Supabase SMTP

There are two separate uses in Edvora:

**Supabase Auth → Resend SMTP**

- Signup confirmation
- Password reset
- Email changes
- Auth/invitation flows handled by Supabase Auth

**Edvora server → Resend API**

- Staff invitations and other application-generated transactional mail
- Uses `RESEND_API_KEY` and `EMAIL_FROM` on the server only

Do not put `RESEND_API_KEY` in any `NEXT_PUBLIC_*` variable.

## 8. Final production checklist

- [ ] Resend domain verified
- [ ] SPF/DKIM configured
- [ ] DMARC configured/reviewed
- [ ] Resend API key created
- [ ] Supabase Custom SMTP enabled
- [ ] SMTP host/port/user/password configured
- [ ] Auth sender address verified and correct
- [ ] Supabase Site URL set to production domain
- [ ] `/auth/callback` added to redirect URLs
- [ ] Confirm email enabled
- [ ] Confirm signup template tested
- [ ] Reset password template tested
- [ ] Signup tested with a real external mailbox
- [ ] Resend confirmation tested after cooldown
- [ ] Password reset tested end-to-end
- [ ] Vercel environment variables configured

The application code is prepared for this configuration; the SMTP credentials themselves must be entered in the Supabase project because they are Auth infrastructure settings, not frontend application settings.
