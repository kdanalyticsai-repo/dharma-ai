// DharmaAI — Cloudflare Worker
// Routed by path:
//   • POST /                 → OpenAI chat proxy (auth-gated, model-locked)
//   • POST /razorpay/order   → create a Razorpay order (server sets the price)
//   • POST /razorpay/verify  → verify payment signature + grant the subscription
//   • POST /razorpay/redeem  → redeem a gift code
//   • POST /razorpay/webhook → Razorpay server-to-server callback (reliable grant)
//
// Secrets (set via `wrangler secret put <NAME>`):
//   OPENAI_API_KEY
//   RAZORPAY_KEY_ID          (test: rzp_test_xxx, live: rzp_live_xxx)
//   RAZORPAY_KEY_SECRET
//   RAZORPAY_WEBHOOK_SECRET  (from Razorpay dashboard → Webhooks)
//   SUPABASE_URL             (e.g. https://xxxx.supabase.co)
//   SUPABASE_SERVICE_KEY     (service_role key — server only)
// Vars (wrangler.toml [vars]): ALLOWED_ORIGINS
// KV binding (wrangler.toml [[kv_namespaces]]): AI_RATE_LIMIT (per-user daily cap)

// ── Server-side price table — the client can NEVER choose the amount ─────────
// Amounts in paise (₹101 = 10100). tier maps to app feature level.
const PLANS = {
  monthly:   { tier: 'sadhaka', amount: 10100,  days: 30,  label: 'Sadhaka Premium (Monthly)' },
  quarterly: { tier: 'sadhaka', amount: 20100,  days: 90,  label: 'Sadhaka Quarterly' },
  annual:    { tier: 'annual',  amount: 50100, days: 365, label: 'Sadhaka Annual' },
};

export default {
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

    const origin = request.headers.get('Origin') || '';
    if (request.method === 'OPTIONS') return cors('', 204, allowedOrigin(origin, env));
    if (request.method !== 'POST') return cors(j({ error: 'Method not allowed' }), 405, null);
    if (!isAllowed(origin, env)) return cors(j({ error: 'Forbidden' }), 403, null);

    try {
      if (path === '/razorpay/order')  return await createOrder(request, env, origin);
      if (path === '/razorpay/verify') return await verifyPayment(request, env, origin);
      if (path === '/razorpay/redeem') return await redeemGift(request, env, origin);
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

  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify(body),
  });
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
  const p = PLANS[plan];
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
    const grant = await grantSubscription(sb, userId, p, paymentId);
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

    const grant = await grantSubscription(sb, user_id, p, gc.razorpay_id);
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
async function grantSubscription(sb, userId, p, razorpayId) {
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
  return { ok: true, expires_at: expires.toISOString() };
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
  return new Response(body, { status, headers });
}
