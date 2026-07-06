// DharmaAI — Cloudflare Worker
// Routed by path:
//   • POST /                 → OpenAI chat proxy (auth-gated, model-locked)
//   • POST /razorpay/order   → create a Razorpay order (server sets the price)
//   • POST /razorpay/verify  → verify payment signature + grant the subscription
//   • POST /razorpay/redeem  → redeem a gift code
//   • POST /razorpay/webhook → Razorpay server-to-server callback (reliable grant)
//   • POST /play/verify      → verify Google Play purchase token + grant subscription
//
// Secrets (set via `wrangler secret put <NAME>`):
//   OPENAI_API_KEY
//   RAZORPAY_KEY_ID          (test: rzp_test_xxx, live: rzp_live_xxx)
//   RAZORPAY_KEY_SECRET
//   RAZORPAY_WEBHOOK_SECRET  (from Razorpay dashboard → Webhooks)
//   SUPABASE_URL             (e.g. https://xxxx.supabase.co)
//   SUPABASE_SERVICE_KEY     (service_role key — server only)
//   GOOGLE_PLAY_SA_JSON      (service account JSON for Play Developer API)
// Vars (wrangler.toml [vars]): ALLOWED_ORIGINS
// KV binding (wrangler.toml [[kv_namespaces]]): AI_RATE_LIMIT (per-user daily cap)

// ── Server-side price table — the client can NEVER choose the amount ─────────
// Amounts in paise (₹101 = 10100). tier maps to app feature level.
const PLANS = {
  monthly:   { tier: 'sadhaka', amount: 10100,  days: 30,  label: 'Sadhaka Premium (Monthly)' },
  quarterly: { tier: 'sadhaka', amount: 20100,  days: 90,  label: 'Sadhaka Quarterly' },
  annual:    { tier: 'annual',  amount: 50100,  days: 365, label: 'Sadhaka Annual' },
};

// International prices (non-IN countries). Server picks based on request.cf.country.
const PLANS_INTL = {
  monthly:   { tier: 'sadhaka', amount: 20100,  days: 30,  label: 'Sadhaka Premium (Monthly)' },
  quarterly: { tier: 'sadhaka', amount: 50100,  days: 90,  label: 'Sadhaka Quarterly' },
  annual:    { tier: 'annual',  amount: 100100, days: 365, label: 'Sadhaka Annual' },
};

// Returns the correct plan table based on Cloudflare country header.
function plansForCountry(request) {
  const country = (request.cf?.country || '').toUpperCase();
  return country === 'IN' ? PLANS : PLANS_INTL;
}

// Play product IDs → plan names (server-side mapping; client cannot override).
const PLAY_PRODUCTS = {
  dharmaai_monthly:   'monthly',
  dharmaai_quarterly: 'quarterly',
  dharmaai_annual:    'annual',
};

export default {
  // Cron trigger: daily sadhana reminders via FCM (see wrangler.toml [triggers]).
  async scheduled(event, env, ctx) {
    ctx.waitUntil(sendDailySadhanaReminders(env));
  },

  async fetch(request, env) {
    const path = new URL(request.url).pathname;

    // Razorpay webhook is server-to-server (no Origin / no CORS). It is
    // authenticated by its own HMAC signature, so it bypasses the origin gate.
    if (path === '/razorpay/webhook') {
      if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });
      try {
        return await handleWebhook(request, env);
      } catch (e) {
        // Always 200 on our errors so Razorpay doesn't hammer retries forever.
        return new Response('ok', { status: 200 });
      }
    }

    // Supabase Database Webhook: fires when a new row is inserted into `profiles`.
    // Authenticated by a shared secret in the Authorization header.
    // Always returns 200 so Supabase doesn't retry on our side errors.
    if (path === '/notify/new-user') {
      if (request.method !== 'POST') return new Response('ok', { status: 200 });
      try {
        return await handleNewUserNotification(request, env);
      } catch (e) {
        console.error('new-user notify error:', e.message);
        return new Response('ok', { status: 200 });
      }
    }

    const origin = request.headers.get('Origin') || '';
    if (request.method === 'OPTIONS') return cors('', 204, allowedOrigin(origin, env));

    // GET /geo — returns the caller's country code (from Cloudflare). Used by
    // the Flutter web app to display the correct regional pricing tier.
    if (path === '/geo' && request.method === 'GET') {
      if (origin && !isAllowed(origin, env)) return cors(j({ error: 'Forbidden' }), 403, null);
      const country = (request.cf?.country || '').toUpperCase() || 'XX';
      return cors(j({ country }), 200, allowedOrigin(origin, env));
    }

    if (request.method !== 'POST') return cors(j({ error: 'Method not allowed' }), 405, null);
    // Native clients (Android) send no Origin header — each handler enforces its own auth.
    // Only block requests that come from a browser origin NOT in the allow-list.
    if (origin && !isAllowed(origin, env)) return cors(j({ error: 'Forbidden' }), 403, null);

    try {
      if (path === '/razorpay/order')  return await createOrder(request, env, origin);
      if (path === '/razorpay/verify') return await verifyPayment(request, env, origin);
      if (path === '/razorpay/redeem') return await redeemGift(request, env, origin);
      // Android Play Billing: no browser Origin header — auth via Supabase JWT only.
      if (path === '/play/verify')     return await verifyPlayPurchase(request, env, origin);
      return await openaiProxy(request, env, origin); // default
    } catch (e) {
      return cors(j({ error: 'Worker error', detail: e.message }), 500, origin);
    }
  },
};

// Per-user DAILY request ceiling (abuse backstop). These sit well ABOVE normal
// usage — the app's real product limits (free vs paid) are enforced client-side.
// A bypassed/scripted client can never exceed these, capping the OpenAI bill per
// account. Tuned so a legitimate user is never affected.
const DAILY_LIMITS = { free: 40, paid: 250 };

// ── OpenAI proxy ────────────────────────────────────────────────────────────
// Hardened: requires a valid signed-in Supabase user, enforces a per-user daily
// rate limit, and forces a cheap model + token cap so the endpoint can't be
// abused to run up the OpenAI bill.
async function openaiProxy(request, env, origin) {
  const user = await validateUser(env, request);
  if (!user) return cors(j({ error: 'Unauthorized' }), 401, origin);

  // Per-user daily ceiling (KV-backed). Fails open if KV isn't bound yet.
  const tier = await getUserTier(env, user.id);
  const rl = await enforceRateLimit(env, user.id, tier);
  if (!rl.ok) {
    return cors(j({ error: 'Daily request limit reached. Please try again tomorrow.' }), 429, origin);
  }

  const body = await request.json();
  body.model = 'gpt-4o-mini'; // never honour a client-chosen (expensive) model
  if (!Number.isInteger(body.max_tokens) || body.max_tokens > 1000) body.max_tokens = 1000;

  const wantsStream = body.stream === true;

  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify(body),
  });

  if (wantsStream && res.body) {
    // Forward the SSE stream directly to the client with CORS headers.
    const headers = {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'X-Accel-Buffering': 'no',
    };
    if (origin) {
      headers['Access-Control-Allow-Origin'] = origin;
      headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization';
      headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS';
      headers['Access-Control-Allow-Credentials'] = 'true';
    }
    return new Response(res.body, { status: res.status, headers });
  }

  const data = await res.json();
  return cors(j(data), res.status, origin);
}

// Validate the caller's Supabase access token (sent as `Authorization: Bearer`).
// Returns the user object when the token is valid, otherwise null.
async function validateUser(env, request) {
  const token = (request.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
  if (!token) return null;
  try {
    const res = await fetch(`${sbBase(env)}/auth/v1/user`, {
      headers: { apikey: env.SUPABASE_SERVICE_KEY, Authorization: `Bearer ${token}` },
    });
    if (!res.ok) return null;
    const u = await res.json();
    return u && u.id ? u : null;
  } catch (_) {
    return null;
  }
}

// Resolve the caller's effective tier ('free' | 'paid') for rate-limit sizing.
// Treats a lapsed subscription as free. Fails safe to 'free' on any error.
async function getUserTier(env, userId) {
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_KEY) return 'free';
  try {
    const sb = sbFetch(env);
    const res = await sb(`profiles?id=eq.${userId}&select=subscription_tier,subscription_end`, { method: 'GET' });
    const rows = await res.json();
    if (!Array.isArray(rows) || !rows.length) return 'free';
    const row = rows[0];
    const end = row.subscription_end ? new Date(row.subscription_end) : null;
    if (end && end.getTime() < Date.now()) return 'free'; // lapsed → free
    return (row.subscription_tier && row.subscription_tier !== 'free') ? 'paid' : 'free';
  } catch (_) {
    return 'free';
  }
}

// Per-user daily request counter in Cloudflare KV. Key auto-expires after ~2
// days so the namespace stays small. KV is eventually consistent, which is fine
// for a soft daily abuse ceiling. Fails OPEN (allows the request) if the KV
// binding isn't configured, so AI never breaks on a missing binding.
async function enforceRateLimit(env, userId, tier) {
  const kv = env.AI_RATE_LIMIT;
  if (!kv) return { ok: true };
  try {
    const day = new Date().toISOString().slice(0, 10); // YYYY-MM-DD (UTC)
    const key = `rl:${userId}:${day}`;
    const count = parseInt((await kv.get(key)) || '0', 10);
    const limit = DAILY_LIMITS[tier] || DAILY_LIMITS.free;
    if (count >= limit) return { ok: false };
    await kv.put(key, String(count + 1), { expirationTtl: 172800 });
    return { ok: true };
  } catch (_) {
    return { ok: true }; // never block on a KV hiccup
  }
}

// ── Razorpay: create order ──────────────────────────────────────────────────
// Body: { plan: 'monthly'|'quarterly'|'annual', user_id }
async function createOrder(request, env, origin) {
  const { plan, user_id, gift } = await request.json();
  const p = plansForCountry(request)[plan];
  if (!p) return cors(j({ error: 'Invalid plan' }), 400, origin);
  if (!user_id) return cors(j({ error: 'Missing user_id' }), 400, origin);

  const auth = btoa(`${env.RAZORPAY_KEY_ID}:${env.RAZORPAY_KEY_SECRET}`);
  const res = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: { 'Authorization': `Basic ${auth}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      amount: p.amount,
      currency: 'INR',
      receipt: `dharma_${plan}_${Date.now()}`,
      // Plan + user are stored on the order so verify()/webhook trust the
      // server, not the client. 'gift' marks a gift purchase.
      notes: { plan, user_id, gift: gift ? '1' : '' },
    }),
  });
  const order = await res.json();
  if (!res.ok) return cors(j({ error: 'Order failed', detail: order }), res.status, origin);

  return cors(j({
    order_id: order.id,
    amount: order.amount,
    currency: order.currency,
    key_id: env.RAZORPAY_KEY_ID,
    plan_label: p.label,
  }), 200, origin);
}

// ── Razorpay: verify payment (client-driven) + grant ────────────────────────
async function verifyPayment(request, env, origin) {
  const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = await request.json();
  if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
    return cors(j({ valid: false, error: 'Missing fields' }), 400, origin);
  }

  // 1. Verify the signature: HMAC_SHA256(order_id|payment_id, key_secret)
  const expected = await hmacHex(env.RAZORPAY_KEY_SECRET, `${razorpay_order_id}|${razorpay_payment_id}`);
  if (expected !== razorpay_signature) {
    return cors(j({ valid: false, error: 'Signature mismatch' }), 400, origin);
  }

  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_KEY) {
    return cors(j({ valid: false, error: 'Supabase secrets not set on Worker' }), 500, origin);
  }

  // 2. Re-fetch the order to read the server-trusted plan/user_id, then grant
  //    (idempotently — the webhook may also grant the same payment).
  const order = await fetchOrder(env, razorpay_order_id);
  if (!order || !order.id) {
    return cors(j({ valid: false, error: 'Order fetch failed', detail: order }), 400, origin);
  }
  const r = await grantFromOrder(env, order, razorpay_payment_id);
  if (!r.ok) return cors(j({ valid: false, error: r.error, detail: r.detail }), r.status || 500, origin);
  if (r.gift) return cors(j({ valid: true, gift: true, code: r.code, plan: r.plan, tier: r.tier }), 200, origin);
  return cors(j({ valid: true, tier: r.tier, plan: r.plan, expires_at: r.expires_at }), 200, origin);
}

// ── Razorpay: webhook (server-to-server) — the reliable grant path ──────────
// Configure in Razorpay dashboard → Webhooks. Events: order.paid (and/or
// payment.captured). Signed with RAZORPAY_WEBHOOK_SECRET.
async function handleWebhook(request, env) {
  const raw = await request.text();
  const sig = request.headers.get('X-Razorpay-Signature') || '';
  const expected = await hmacHex(env.RAZORPAY_WEBHOOK_SECRET || '', raw);
  if (!sig || expected !== sig) return new Response('Invalid signature', { status: 400 });

  const event = JSON.parse(raw);
  if (event.event === 'order.paid' || event.event === 'payment.captured') {
    const payment = event.payload?.payment?.entity;
    const orderEntity = event.payload?.order?.entity;
    const orderId = orderEntity?.id || payment?.order_id;
    const paymentId = payment?.id;
    if (orderId && paymentId) {
      // Prefer the order entity from the event; fall back to a fetch for notes.
      let order = orderEntity && orderEntity.notes ? orderEntity : await fetchOrder(env, orderId);
      if (order && order.id) {
        await grantFromOrder(env, order, paymentId); // idempotent
      }
    }
  }
  // Acknowledge so Razorpay stops retrying — we've processed (or safely ignored) it.
  return new Response('ok', { status: 200 });
}

// ── Shared, idempotent grant from a Razorpay order ──────────────────────────
async function grantFromOrder(env, order, paymentId) {
  const plan = order?.notes?.plan;
  const userId = order?.notes?.user_id;
  const p = PLANS[plan];
  if (!p || !userId) return { ok: false, status: 400, error: 'Bad order notes' };
  const sb = sbFetch(env);

  try {
    // Gift purchase → one shareable code per payment (idempotent on payment id).
    if (order.notes?.gift === '1') {
      const exRes = await sb(`gift_codes?razorpay_id=eq.${encodeURIComponent(paymentId)}&select=code`, { method: 'GET' });
      const ex = await exRes.json();
      if (Array.isArray(ex) && ex.length) {
        return { ok: true, gift: true, code: ex[0].code, plan, tier: p.tier };
      }
      const code = makeGiftCode();
      const ins = await sb('gift_codes', {
        method: 'POST', headers: { Prefer: 'return=minimal' },
        body: JSON.stringify({
          code, plan, tier: p.tier, amount_inr: p.amount / 100,
          razorpay_id: paymentId, purchased_by: userId, status: 'active',
        }),
      });
      if (!ins.ok) return { ok: false, status: 500, error: 'Gift code save failed', detail: await ins.text() };
      return { ok: true, gift: true, code, plan, tier: p.tier };
    }

    // Normal purchase → grant once per payment (idempotent).
    const exRes = await sb(`subscriptions?razorpay_id=eq.${encodeURIComponent(paymentId)}&select=expires_at`, { method: 'GET' });
    const ex = await exRes.json();
    if (Array.isArray(ex) && ex.length) {
      return { ok: true, tier: p.tier, plan, expires_at: ex[0].expires_at };
    }
    const grant = await grantSubscription(env, sb, userId, p, paymentId);
    if (!grant.ok) return { ok: false, status: 500, error: 'Subscription insert failed', detail: grant.detail };
    return { ok: true, tier: p.tier, plan, expires_at: grant.expires_at };
  } catch (e) {
    return { ok: false, status: 500, error: 'Supabase write error', detail: e.message };
  }
}

async function fetchOrder(env, orderId) {
  const auth = btoa(`${env.RAZORPAY_KEY_ID}:${env.RAZORPAY_KEY_SECRET}`);
  const res = await fetch(`https://api.razorpay.com/v1/orders/${orderId}`, {
    headers: { 'Authorization': `Basic ${auth}` },
  });
  return res.ok ? res.json() : null;
}

// ── Razorpay: redeem a gift code → grant the subscription to the redeemer ────
async function redeemGift(request, env, origin) {
  const { code, user_id } = await request.json();
  if (!code || !user_id) return cors(j({ valid: false, error: 'Missing fields' }), 400, origin);
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_KEY) {
    return cors(j({ valid: false, error: 'Supabase secrets not set on Worker' }), 500, origin);
  }
  const sb = sbFetch(env);
  try {
    const res = await sb(`gift_codes?code=eq.${encodeURIComponent(code.trim())}&select=*`, { method: 'GET' });
    const rows = await res.json();
    if (!Array.isArray(rows) || rows.length === 0) {
      return cors(j({ valid: false, error: 'Invalid gift code.' }), 404, origin);
    }
    const gc = rows[0];
    if (gc.status !== 'active') {
      return cors(j({ valid: false, error: 'This code has already been redeemed.' }), 409, origin);
    }
    // A gift is for someone else — the buyer can't redeem their own code.
    if (gc.purchased_by && gc.purchased_by === user_id) {
      return cors(j({ valid: false, error: 'This is your own gift code — please share it with a friend to redeem.' }), 403, origin);
    }
    const p = PLANS[gc.plan];
    if (!p) return cors(j({ valid: false, error: 'Unknown plan on code.' }), 400, origin);

    const grant = await grantSubscription(env, sb, user_id, p, gc.razorpay_id);
    if (!grant.ok) {
      return cors(j({ valid: false, error: 'Could not grant subscription', detail: grant.detail }), 500, origin);
    }
    await sb(`gift_codes?code=eq.${encodeURIComponent(code.trim())}`, {
      method: 'PATCH', headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({ status: 'redeemed', redeemed_by: user_id, redeemed_at: new Date().toISOString() }),
    });
    return cors(j({ valid: true, tier: p.tier, plan: gc.plan, expires_at: grant.expires_at }), 200, origin);
  } catch (e) {
    return cors(j({ valid: false, error: 'Redeem error', detail: e.message }), 500, origin);
  }
}

// ── Google Play Billing: verify purchase + grant ─────────────────────────────
// Body: { purchase_token, product_id, user_id }
// Auth: Supabase Bearer token (no Origin header from Android — CORS skipped).
// Secret: GOOGLE_PLAY_SA_JSON (service account JSON for Play Developer API).
async function verifyPlayPurchase(request, env, origin) {
  // Auth: validate the Supabase session (same as openaiProxy).
  const user = await validateUser(env, request);
  if (!user) return cors(j({ error: 'Unauthorized' }), 401, origin);

  const { purchase_token, product_id, user_id } = await request.json();
  if (!purchase_token || !product_id || !user_id) {
    return cors(j({ valid: false, error: 'Missing fields' }), 400, origin);
  }
  if (user.id !== user_id) {
    return cors(j({ valid: false, error: 'User mismatch' }), 403, origin);
  }

  const plan = PLAY_PRODUCTS[product_id];
  if (!plan) return cors(j({ valid: false, error: 'Unknown product' }), 400, origin);
  const p = PLANS[plan];

  if (!env.GOOGLE_PLAY_SA_JSON) {
    return cors(j({ valid: false, error: 'Play service account not configured' }), 500, origin);
  }

  // 1. Get a Google OAuth access token via service account JWT.
  let accessToken;
  try {
    accessToken = await getGoogleAccessToken(env.GOOGLE_PLAY_SA_JSON);
  } catch (e) {
    return cors(j({ valid: false, error: 'Google auth failed', detail: e.message }), 500, origin);
  }

  // 2. Verify the purchase token with the Play Developer API.
  const packageName = 'com.kdaanalytics.dharmaai';
  const apiUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/products/${product_id}/tokens/${encodeURIComponent(purchase_token)}`;
  const apiRes = await fetch(apiUrl, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!apiRes.ok) {
    const err = await apiRes.text();
    return cors(j({ valid: false, error: 'Play API error', detail: err }), 400, origin);
  }
  const purchase = await apiRes.json();

  // purchaseState 0 = Purchased, 1 = Cancelled, 2 = Pending.
  if (purchase.purchaseState !== 0) {
    return cors(j({ valid: false, error: 'Purchase not completed' }), 400, origin);
  }

  // 3. Idempotent grant — use prefixed purchase_token as the unique ID.
  const sb = sbFetch(env);
  const uniqueId = `play_${purchase_token}`;
  const grant = await grantSubscription(env, sb, user_id, p, uniqueId);
  if (!grant.ok) {
    return cors(j({ valid: false, error: 'Grant failed', detail: grant.detail }), 500, origin);
  }
  return cors(j({ valid: true, tier: p.tier, plan, expires_at: grant.expires_at }), 200, origin);
}

// Exchange a service account JSON key for a short-lived Google OAuth access token.
// Uses RS256 JWT signing via the WebCrypto API (available in Cloudflare Workers).
async function getGoogleAccessToken(saJson) {
  const sa = JSON.parse(saJson);
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const encode = (obj) => btoa(JSON.stringify(obj))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const unsigned = `${encode(header)}.${encode(payload)}`;

  // Import the RSA private key (PKCS#8 PEM → CryptoKey).
  const pemBody = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const der = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8', der.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false, ['sign'],
  );

  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', cryptoKey,
    new TextEncoder().encode(unsigned),
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const jwt = `${unsigned}.${sigB64}`;

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });
  const tokenData = await tokenRes.json();
  if (!tokenData.access_token) throw new Error(tokenData.error_description || 'Token exchange failed');
  return tokenData.access_token;
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function sbBase(env) {
  let base = (env.SUPABASE_URL || '').replace(/\/+$/, '');
  if (!/^https?:\/\//i.test(base)) base = 'https://' + base;
  return base;
}

// Supabase REST helper using the service role (bypasses RLS).
function sbFetch(env) {
  const base = sbBase(env);
  return (path, init) => fetch(`${base}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: env.SUPABASE_SERVICE_KEY,
      Authorization: `Bearer ${env.SUPABASE_SERVICE_KEY}`,
      'Content-Type': 'application/json',
      ...(init.headers || {}),
    },
  });
}

// Grant a subscription to a user. Insert-first so a UNIQUE index on razorpay_id
// makes it race-safe: if the webhook and verify grant the same payment at once,
// the second insert returns 409 and we treat it as already-granted (no dupe).
async function grantSubscription(env, sb, userId, p, razorpayId) {
  const now = new Date();
  const expires = new Date(now.getTime() + p.days * 86400000);

  // 1) Insert the new subscription first.
  const insRes = await sb('subscriptions', {
    method: 'POST', headers: { Prefer: 'return=minimal' },
    body: JSON.stringify({
      user_id: userId, tier: p.tier, status: 'active',
      amount_inr: p.amount / 100, razorpay_id: razorpayId,
      started_at: now.toISOString(), expires_at: expires.toISOString(),
    }),
  });
  // Duplicate payment (concurrent grant) → already done, idempotent success.
  if (insRes.status === 409) {
    return { ok: true, expires_at: expires.toISOString() };
  }
  if (!insRes.ok) {
    return { ok: false, status: insRes.status, detail: await insRes.text() };
  }

  // 2) Expire any OTHER active subscriptions for this user (e.g. a previous plan
  //    on renewal) — never the row we just inserted.
  const otherActive = razorpayId
    ? `subscriptions?user_id=eq.${userId}&status=eq.active&razorpay_id=neq.${encodeURIComponent(razorpayId)}`
    : `subscriptions?user_id=eq.${userId}&status=eq.active`;
  await sb(otherActive, {
    method: 'PATCH', headers: { Prefer: 'return=minimal' },
    body: JSON.stringify({ status: 'expired' }),
  });

  // 3) Profile is the quick-lookup source of truth.
  await sb(`profiles?id=eq.${userId}`, {
    method: 'PATCH', headers: { Prefer: 'return=minimal' },
    body: JSON.stringify({ subscription_tier: p.tier, subscription_end: expires.toISOString() }),
  });

  // 4) Notify admin — fire-and-forget, never blocks the payment response.
  sendSubscriptionEmail(env, sb, userId, p, razorpayId, expires).catch(() => {});

  return { ok: true, expires_at: expires.toISOString() };
}

// Sends admin notification email when a user upgrades their subscription.
async function sendSubscriptionEmail(env, sb, userId, p, paymentId, expires) {
  try {
    const resendKey = env.RESEND_API_KEY;
    if (!resendKey) return;

    const profileRes = await sb(`profiles?id=eq.${userId}&select=full_name,email`, { method: 'GET' });
    const profiles = await profileRes.json();
    const profile = (Array.isArray(profiles) && profiles[0]) || {};
    const name = profile.full_name || '(no name)';
    const email = profile.email || '(no email)';

    const tierLabel = { free: '🆓 Free', sadhaka: '⭐ Sadhaka Premium', annual: '🌟 Sadhaka Annual' }[p.tier] || p.tier;
    const amountStr = p.amount ? `₹${(p.amount / 100).toFixed(0)}` : '—';
    const expiresStr = new Date(expires).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }) + ' IST';
    const upgradedAt = new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }) + ' IST';

    const html = `<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#FAF7F2;margin:0;padding:24px}
  .card{background:#fff;border-radius:12px;padding:28px 32px;max-width:480px;margin:0 auto;border:1px solid #ecd9cf}
  .brand{color:#9C3F00;font-weight:800;font-size:1.2rem;margin-bottom:4px}
  .title{font-size:1.05rem;font-weight:700;color:#251913;margin-bottom:20px}
  table{width:100%;border-collapse:collapse}
  td{padding:9px 0;border-bottom:1px solid #f0e8e3;font-size:.95rem;color:#251913}
  td:first-child{color:#6b5648;width:38%;font-weight:600}
  .badge{display:inline-block;background:#fdeee3;color:#9C3F00;border-radius:999px;padding:2px 12px;font-size:.85rem;font-weight:700}
  .footer{margin-top:20px;font-size:.8rem;color:#aaa;text-align:center}
</style></head>
<body>
<div class="card">
  <div class="brand">🪔 DharmaAI</div>
  <div class="title">Subscription upgraded</div>
  <table>
    <tr><td>Name</td><td><strong>${escHtml(name)}</strong></td></tr>
    <tr><td>Email</td><td>${escHtml(email)}</td></tr>
    <tr><td>Plan</td><td><span class="badge">${escHtml(tierLabel)}</span></td></tr>
    <tr><td>Amount paid</td><td>${escHtml(amountStr)}</td></tr>
    <tr><td>Expires</td><td>${escHtml(expiresStr)}</td></tr>
    <tr><td>Payment ID</td><td style="font-size:.85rem;word-break:break-all">${escHtml(paymentId || '—')}</td></tr>
    <tr><td>Upgraded at</td><td>${escHtml(upgradedAt)}</td></tr>
  </table>
  <div class="footer">dharma.kdaanalytics.com — admin alert</div>
</div>
</body></html>`;

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: 'DharmaAI Admin <onboarding@resend.dev>',
        to: ['kdanalyticsai@gmail.com'],
        subject: `⭐ Subscription upgrade: ${name} → ${p.label}`,
        html,
      }),
    });
    if (!res.ok) {
      console.error('Subscription notify error HTTP', res.status, await res.text());
    }
  } catch (e) {
    console.error('Subscription notify error:', e.message);
  }
}

// Generate a friendly gift code (no ambiguous chars).
function makeGiftCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const seg = (n) => Array.from({ length: n }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
  return `DHARMA-${seg(4)}-${seg(4)}`;
}

async function hmacHex(secret, message) {
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

// ── New-user admin notification ─────────────────────────────────────────────
// Called by a Supabase Database Webhook on INSERT into public.profiles.
// Sends a summary email to the admin (kdanalyticsai@gmail.com) via Resend.
// Secrets needed:
//   RESEND_API_KEY         — from resend.com dashboard
//   SUPABASE_WEBHOOK_SECRET — any random string; paste the same value into
//                             the Supabase webhook "Authorization" header field
async function handleNewUserNotification(request, env) {
  // Validate shared secret so only Supabase can call this endpoint.
  const secret = env.SUPABASE_WEBHOOK_SECRET;
  if (secret) {
    const auth = request.headers.get('authorization') || '';
    if (auth !== `Bearer ${secret}`) {
      console.warn('new-user webhook: invalid secret');
      return new Response('ok', { status: 200 }); // silent reject — never 401
    }
  }

  const payload = await request.json();
  // Supabase sends: { type: 'INSERT', table, record, old_record, schema }
  const r = payload.record || {};

  const name     = r.full_name         || '(no name)';
  const email    = r.email             || '(no email)';
  const tier     = r.subscription_tier || 'free';
  const lang     = r.preferred_language || r.language || '—';
  const method   = r.auth_provider     || '—';
  const joinedAt = r.created_at
    ? new Date(r.created_at).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }) + ' IST'
    : new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }) + ' IST';

  const tierLabel = {
    free:     '🆓 Free',
    sadhaka:  '⭐ Sadhaka Premium',
    annual:   '🌟 Sadhaka Annual',
  }[tier] || tier;

  const html = `<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#FAF7F2;margin:0;padding:24px}
  .card{background:#fff;border-radius:12px;padding:28px 32px;max-width:480px;margin:0 auto;border:1px solid #ecd9cf}
  .brand{color:#9C3F00;font-weight:800;font-size:1.2rem;margin-bottom:4px}
  .title{font-size:1.05rem;font-weight:700;color:#251913;margin-bottom:20px}
  table{width:100%;border-collapse:collapse}
  td{padding:9px 0;border-bottom:1px solid #f0e8e3;font-size:.95rem;color:#251913}
  td:first-child{color:#6b5648;width:38%;font-weight:600}
  .badge{display:inline-block;background:#fdeee3;color:#9C3F00;border-radius:999px;padding:2px 12px;font-size:.85rem;font-weight:700}
  .footer{margin-top:20px;font-size:.8rem;color:#aaa;text-align:center}
</style></head>
<body>
<div class="card">
  <div class="brand">🪔 DharmaAI</div>
  <div class="title">New user registered</div>
  <table>
    <tr><td>Name</td><td><strong>${escHtml(name)}</strong></td></tr>
    <tr><td>Email</td><td>${escHtml(email)}</td></tr>
    <tr><td>Subscription</td><td><span class="badge">${escHtml(tierLabel)}</span></td></tr>
    <tr><td>Language</td><td>${escHtml(lang)}</td></tr>
    <tr><td>Auth method</td><td>${escHtml(method)}</td></tr>
    <tr><td>Joined</td><td>${escHtml(joinedAt)}</td></tr>
  </table>
  <div class="footer">dharma.kdaanalytics.com — admin alert</div>
</div>
</body></html>`;

  const resendKey = env.RESEND_API_KEY;
  if (!resendKey) {
    console.warn('new-user notify: RESEND_API_KEY not set — skipping email');
    return new Response('ok', { status: 200 });
  }

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${resendKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: 'DharmaAI Admin <onboarding@resend.dev>',
      to: ['kdanalyticsai@gmail.com'],
      subject: `🪔 New DharmaAI user: ${name}`,
      html,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    console.error('Resend error HTTP', res.status, res.statusText, '|', err);
  } else {
    console.log('Resend success HTTP', res.status);
  }

  return new Response('ok', { status: 200 });
}

// ── Daily sadhana reminder cron ─────────────────────────────────────────────
// Fires at 08:30 IST (03:00 UTC). Sends a FCM push to every user who has an
// fcm_token stored but has NOT logged any sadhana today.
// Secrets needed: FIREBASE_SA_JSON (Firebase service account JSON).
async function sendDailySadhanaReminders(env) {
  if (!env.FIREBASE_SA_JSON || !env.SUPABASE_URL || !env.SUPABASE_SERVICE_KEY) return;
  try {
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD UTC
    const sb = sbFetch(env);

    // Users who already logged sadhana today.
    const doneRes = await sb(`sadhana_records?date=eq.${today}&select=user_id`, { method: 'GET' });
    const doneRows = await doneRes.json();
    const doneSet = new Set(Array.isArray(doneRows) ? doneRows.map((r) => r.user_id) : []);

    // All users with an FCM token.
    const profRes = await sb(
      'profiles?fcm_token=not.is.null&select=id,fcm_token,preferred_language',
      { method: 'GET' },
    );
    const profiles = await profRes.json();
    if (!Array.isArray(profiles) || !profiles.length) return;

    // Only notify those who haven't practised yet.
    const targets = profiles.filter((p) => !doneSet.has(p.id) && p.fcm_token);
    if (!targets.length) return;

    const accessToken = await getFcmAccessToken(env.FIREBASE_SA_JSON);
    const { project_id } = JSON.parse(env.FIREBASE_SA_JSON);
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${project_id}/messages:send`;

    for (const user of targets) {
      const { title, body } = getReminderMessage(user.preferred_language || 'en');
      try {
        await fetch(fcmUrl, {
          method: 'POST',
          headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            message: {
              token: user.fcm_token,
              notification: { title, body },
              data: { screen: 'sadhana' },
              android: { priority: 'normal' },
            },
          }),
        });
      } catch (e) {
        console.error('FCM send error user', user.id, e.message);
      }
    }
    console.log(`Sadhana reminders sent to ${targets.length} user(s).`);
  } catch (e) {
    console.error('sendDailySadhanaReminders error:', e.message);
  }
}

// Exchange a Firebase service account JSON key for an FCM HTTP v1 access token.
async function getFcmAccessToken(saJson) {
  const sa = JSON.parse(saJson);
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const encode = (obj) => btoa(JSON.stringify(obj))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const unsigned = `${encode(header)}.${encode(payload)}`;
  const pemBody = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const der = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8', der.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false, ['sign'],
  );
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', cryptoKey, new TextEncoder().encode(unsigned));
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const jwt = `${unsigned}.${sigB64}`;
  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });
  const tokenData = await tokenRes.json();
  if (!tokenData.access_token) throw new Error(tokenData.error_description || 'FCM token exchange failed');
  return tokenData.access_token;
}

// Multilingual reminder messages for the 6 supported languages.
function getReminderMessage(lang) {
  const msgs = {
    en: { title: 'Your daily sadhana awaits 🪷', body: 'A few minutes of practice can transform your day.' },
    hi: { title: 'आपकी साधना आपका इंतज़ार कर रही है 🪷', body: 'कुछ मिनटों का अभ्यास आपके दिन को बदल सकता है।' },
    ta: { title: 'உங்கள் சாதனை காத்திருக்கிறது 🪷', body: 'சில நிமிட பயிற்சி உங்கள் நாளை மாற்றும்.' },
    bn: { title: 'আপনার সাধনা অপেক্ষা করছে 🪷', body: 'কয়েক মিনিটের অনুশীলন আপনার দিন বদলে দিতে পারে।' },
    gu: { title: 'તમારી સાધના રાહ જોઈ રહી છે 🪷', body: 'થોડી મિનિટ અભ્યાસ તમારો દિવસ બદલી શકે છે.' },
    or: { title: 'ଆପଣଙ୍କ ସାଧନା ଅପେକ୍ଷା କରୁଛି 🪷', body: 'କିଛି ମିନିଟ ଅଭ୍ୟାସ ଆପଣଙ୍କ ଦିନ ବଦଳାଇ ପାରିବ।' },
  };
  return msgs[lang] || msgs.en;
}

function escHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

const j = (obj) => JSON.stringify(obj);

function isAllowed(origin, env) {
  const allowed = (env.ALLOWED_ORIGINS || '').split(',').filter(Boolean);
  return allowed.some((o) => origin === o);
}
function allowedOrigin(origin, env) {
  return isAllowed(origin, env) ? origin : null;
}
function cors(body, status = 200, origin = null) {
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
  if (origin) headers['Access-Control-Allow-Origin'] = origin;
  // 204/304 responses must have a null body — a zero-length string triggers a
  // Workers runtime warning. (Used by the CORS preflight, which returns 204.)
  return new Response(status === 204 || status === 304 ? null : body, { status, headers });
}
