# DharmaAI — Branded Auth Email Templates

Custom HTML for the transactional emails Supabase sends. They match the app's
saffron palette (`#9C3F00` on cream `#FAF7F2`) and use the `ॐ` emblem.

## Where to paste
Supabase Dashboard → **Authentication → Email Templates**. Select each template,
set the **Subject**, and paste the file's HTML into the **Message body** (the
"Source"/HTML box — not a rich-text box).

| Template (Supabase) | File | Suggested Subject |
|---|---|---|
| **Reset Password** | `reset_password.html` | `Reset your DharmaAI password` |
| **Confirm signup** | `confirm_signup.html` | `Confirm your email to begin your path` |

## Notes
- The only dynamic variable used is `{{ .ConfirmationURL }}` — Supabase fills it
  in. Don't rename it.
- Templates are table-based with inline styles for broad email-client support
  (Gmail, Outlook, Apple Mail). The `&#2384;` entity renders the `ॐ` glyph.
- These only take effect once **Custom SMTP (Resend)** is enabled and the
  `mail.kdaanalytics.com` domain is **Verified** in Resend.
- If "Confirm email" is disabled in Auth settings, the Confirm-signup template
  is simply never sent — harmless to set it up anyway.
