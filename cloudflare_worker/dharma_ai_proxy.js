// DharmaAI — Cloudflare Worker
// Two responsibilities, routed by path:
//   • POST /                → OpenAI chat proxy (key stays server-side)
//   • POST /razorpay/order  → create a Razorpay order (server sets the price)
//   • POST /razorpay/verify → verify payment signature + grant the subscription
//
// Secrets (set via `wrangler secret put <NAME>`):
//   OPENAI_API_KEY
//   RAZORPAY_KEY_ID         (test: rzp_test_xxx, live: rzp_live_xxx)
//   RAZORPAY_KEY_SECRET
//   SUPABASE_URL            (e.g. https://xxxx.supabase.co)
//   SUPABASE_SERVICE_KEY    (service_role key — server only)
// Vars (wrangler.toml [vars]): ALLOWED_ORIGINS

// ── Server-side price table — the client can NEVER choose the amount ─────────
// Amounts in paise (₹101 = 10100). tier maps to app feature level.
const PLANS = {
  monthly:   { tier: 'sadhaka', amount: 10100,  days: 30,  label: 'Sadhaka Premium (Monthly)' },
  quarterly: { tier: 'sadhaka', amount: 20100,  days: 90,  label: 'Sadhaka Quarterly' },
  annual:    { tier: 'annual',  amount: 50100, days: 365, label: 'Sadhaka Annual' },
};

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '';

    if (request.method === 'OPTIONS') {
      return cors('', 204, allowedOrigin(origin, env));
    }
    if (request.method !== 'POST') {
      return cors(j({ error: 'Method not allowed' }), 405, null);
    }
    if (!isAllowed(origin, env)) {
      return cors(j({ error: 'Forbidden' }), 403, null);
    }

    const path = new URL(request.url).pathname;
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

// ── OpenAI proxy (unchanged behavior) ───────────────────────────────────────
async function openaiProxy(request, env, origin) {
  const body = await request.json();
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

// ── Razorpay: create order ──────────────────────────────────────────────────
// Body: { plan: 'monthly'|'quarterly'|'annual', user_id }
// The amount comes from the server PLANS table, so it can't be tampered with.
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
      // Plan + user are stored on the order so verify() trusts the server, not the client.
      // 'gift' marks this as a gift purchase (creates a code instead of granting the buyer).
      notes: { plan, user_id, gift: gift ? '1' : '' },
    }),
  });
  const order = await res.json();
  if (!res.ok) return cors(j({ error: 'Order failed', detail: order }), res.status, origin);

  // key_id is the public identifier — safe to return to the browser.
  return cors(j({
    order_id: order.id,
    amount: order.amount,
    currency: order.currency,
    key_id: env.RAZORPAY_KEY_ID,
    plan_label: p.label,
  }), 200, origin);
}

// ── Razorpay: verify payment + grant subscription ───────────────────────────
// Body: { razorpay_order_id, razorpay_payment_id, razorpay_signature }
// Everything granted is derived from the ORDER (server-trusted), not the client.
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

  // 2. Re-fetch the order from Razorpay to read the trusted plan/user_id.
  // The signature above already proves the payment is genuine; we do NOT
  // hard-require status === 'paid' (capture can lag a moment after success).
  const auth = btoa(`${env.RAZORPAY_KEY_ID}:${env.RAZORPAY_KEY_SECRET}`);
  const ordRes = await fetch(`https://api.razorpay.com/v1/orders/${razorpay_order_id}`, {
    headers: { 'Authorization': `Basic ${auth}` },
  });
  const order = await ordRes.json();
  if (!ordRes.ok) {
    return cors(j({ valid: false, error: 'Order fetch failed', detail: order }), 400, origin);
  }

  const plan = order.notes?.plan;
  const userId = order.notes?.user_id;
  const p = PLANS[plan];
  if (!p || !userId) {
    return cors(j({ valid: false, error: 'Bad order notes', notes: order.notes }), 400, origin);
  }

  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_KEY) {
    return cors(j({ valid: false, error: 'Supabase secrets not set on Worker' }), 500, origin);
  }
  const sb = sbFetch(env);

  try {
    // Gift purchase → create a shareable code instead of granting the buyer.
    if (order.notes?.gift === '1') {
      const code = makeGiftCode();
      const insRes = await sb('gift_codes', {
        method: 'POST', headers: { Prefer: 'return=minimal' },
        body: JSON.stringify({
          code, plan, tier: p.tier, amount_inr: p.amount / 100,
          razorpay_id: razorpay_payment_id, purchased_by: userId, status: 'active',
        }),
      });
      if (!insRes.ok) {
        const detail = await insRes.text();
        return cors(j({ valid: false, error: 'Gift code save failed', detail }), 500, origin);
      }
      return cors(j({ valid: true, gift: true, code, plan, tier: p.tier }), 200, origin);
    }

    // Normal purchase → grant the subscription to the buyer.
    const grant = await grantSubscription(sb, userId, p, razorpay_payment_id);
    if (!grant.ok) {
      return cors(j({ valid: false, error: 'Subscription insert failed', status: grant.status, detail: grant.detail }), 500, origin);
    }
    return cors(j({ valid: true, tier: p.tier, plan, expires_at: grant.expires_at }), 200, origin);
  } catch (e) {
    return cors(j({ valid: false, error: 'Supabase write error', detail: e.message }), 500, origin);
  }
}

// ── Razorpay: redeem a gift code → grant the subscription to the redeemer ────
// Body: { code, user_id }
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

// Supabase REST helper using the service role (bypasses RLS).
function sbFetch(env) {
  let base = (env.SUPABASE_URL || '').replace(/\/+$/, '');
  if (!/^https?:\/\//i.test(base)) base = 'https://' + base;
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

// Grant a subscription to a user: expire old active rows, insert new, set tier.
async function grantSubscription(sb, userId, p, razorpayId) {
  const now = new Date();
  const expires = new Date(now.getTime() + p.days * 86400000);
  await sb(`subscriptions?user_id=eq.${userId}&status=eq.active`, {
    method: 'PATCH', headers: { Prefer: 'return=minimal' },
    body: JSON.stringify({ status: 'expired' }),
  });
  const insRes = await sb('subscriptions', {
    method: 'POST', headers: { Prefer: 'return=minimal' },
    body: JSON.stringify({
      user_id: userId, tier: p.tier, status: 'active',
      amount_inr: p.amount / 100, razorpay_id: razorpayId,
      started_at: now.toISOString(), expires_at: expires.toISOString(),
    }),
  });
  if (!insRes.ok) {
    return { ok: false, status: insRes.status, detail: await insRes.text() };
  }
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
    'Access-Control-Allow-Headers': 'Content-Type',
  };
  if (origin) headers['Access-Control-Allow-Origin'] = origin;
  return new Response(body, { status, headers });
}
