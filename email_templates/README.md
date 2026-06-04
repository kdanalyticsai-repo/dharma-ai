# DharmaAI — Branded Auth Email Templates

Custom HTML for the transactional emails Supabase sends. They match the app's
saffron palette (`#9C3F00` on cream `#FAF7F2`) and show the DharmaAI logo.

## Logo hosting (important)
The templates load the logo from `https://dharma.kdaanalytics.com/email-logo.png`,
which is served from `web/email-logo.png` in this repo. That URL only goes live
**after the app is deployed** (push to `main`). So deploy once before sending
real emails, or the logo will appear broken. To refresh the logo, replace
`web/email-logo.png` and redeploy.

## Where to paste
Supabase Dashboard → **Authentication → Email Templates**. Select each template,
set the **Subject**, and paste the file's HTML into the **Message body** (the
"Source"/HTML box — not a rich-text box).

| Template (Supabase) | File | Suggested Subject |
|---|---|---|
| **Reset Password** | `reset_password.html` | `Reset your DharmaAI password` |
| **Confirm signup** | `confirm_signup.html` | `Confirm your email to begin your path` |

## Notes
- **Reset Password** links to
  `https://dharma.kdaanalytics.com/?type=recovery&token_hash={{ .TokenHash }}`
  (NOT `{{ .ConfirmationURL }}`). The app reads the `token_hash` and calls
  `verifyOTP()` to open the recovery session — this works in any browser/device,
  unlike the PKCE `ConfirmationURL` which only works in the browser that
  requested the reset. Keep `{{ .TokenHash }}` intact.
- **Confirm signup** still uses `{{ .ConfirmationURL }}` — Supabase fills it in.
- Templates are table-based with inline styles for broad email-client support
  (Gmail, Outlook, Apple Mail).
- These only take effect once **Custom SMTP (Resend)** is enabled and the
  `mail.kdaanalytics.com` domain is **Verified** in Resend.
- If "Confirm email" is disabled in Auth settings, the Confirm-signup template
  is simply never sent — harmless to set it up anyway.
