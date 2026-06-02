# Razorpay Web Checkout — Setup & Test Guide

Real UPI/card payments on the **web app** (`dharma.kdaanalytics.com`), with the
secret key kept server-side on your Cloudflare Worker. The Worker creates the
order (server sets the price), verifies the signature, and writes the
subscription to Supabase — so the amount and the grant can't be tampered with
from the browser.

> Android will use **Google Play Billing** later. This flow is web-only; on
> Android the app keeps the existing flow for now.

---

## 1. Create a Razorpay account
1. Sign up at https://razorpay.com → start in **Test Mode** (instant; no KYC).
2. **Settings → API Keys → Generate Test Key** → copy **Key Id** (`rzp_test_…`)
   and **Key Secret**.
3. **Settings → Configuration → Payment Methods** → enable **UPI** (and cards).
4. (For real money later) Complete **business KYC** to get **Live** keys.

## 2. Add the secrets to the Cloudflare Worker
From `cloudflare_worker/`:
```powershell
npx wrangler secret put RAZORPAY_KEY_ID        # paste rzp_test_xxx
npx wrangler secret put RAZORPAY_KEY_SECRET    # paste the secret
npx wrangler secret put SUPABASE_URL           # https://YOUR-PROJECT.supabase.co
npx wrangler secret put SUPABASE_SERVICE_KEY   # Supabase service_role key
# (OPENAI_API_KEY should already be set)
npx wrangler deploy
```
`ALLOWED_ORIGINS` in `wrangler.toml` must already include
`https://dharma.kdaanalytics.com` (it does).

## 3. Deploy the app
The web build already injects the Worker URL via `OPENAI_WORKER_URL`
(`--dart-define-from-file`), which the payment client reuses. Just let CI
deploy, or build locally with your `run_dev.ps1`.

## 4. Test the flow (Test Mode)
1. Open the web app, sign in, go to **Profile → Upgrade Account**.
2. Tap **EMBARK ON …** for any plan → the Razorpay checkout opens.
3. Pay using Razorpay's **test methods**:
   - **UPI (test):** `success@razorpay`
   - **Test card:** `4111 1111 1111 1111`, any future expiry, any CVV.
4. On success you'll see "Welcome, Sadhaka" and premium unlocks.
5. Verify in Supabase:
   ```sql
   select tier, status, amount_inr, razorpay_id, expires_at
   from subscriptions order by started_at desc limit 5;
   select subscription_tier, subscription_end from profiles where id = auth.uid();
   ```

## 5. Go live
- Swap the Worker secrets to **Live** keys (`rzp_live_…`), redeploy.
- Complete Razorpay KYC + add your settlement bank account.

---

## ⚠️ Before production: harden write access (important)
Today, the app's RLS still lets a signed-in user write their **own**
`subscriptions` / `profiles.subscription_tier` (needed by the Android mock).
That means a determined user could self-grant premium **without paying**.

When Android moves to Google Play Billing, tighten RLS so **only the service
role** (the verified Worker / Razorpay webhook) can grant subscriptions:
```sql
-- Replace the broad "own subs" / "own profile" write policies with read-only
-- for users, and let only the service role insert/update subscriptions and
-- profiles.subscription_tier. (Server becomes the single source of truth.)
```
Also recommended: add a **Razorpay webhook** (`payment.captured`) pointing at a
Worker endpoint, so subscriptions are granted from the webhook even if the
browser closes mid-redirect.

## Recurring payments (later)
This MVP uses **one-time** orders (manual renewal). For auto-renew, switch to
**Razorpay Subscriptions** (Plans + UPI AutoPay mandates) — a follow-up.
