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
// Amounts in paise (₹199 = 19900). tier maps to app feature level.
const PLANS = {
  monthly:   { tier: 'sadhaka', amount: 19900,  days: 30,  label: 'Sadhaka Premium (Monthly)' },
  quarterly: { tier: 'sadhaka', amount: 49900,  days: 90,  label: 'Sadhaka Quarterly' },
  annual:    { tier: 'annual',  amount: 149900, days: 365, label: 'Sadhaka Annual' },
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
  const { plan, user_id } = await request.json();
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
      notes: { plan, user_id },
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

  // 3. Write the subscription server-side (service role). Source of truth.
  const now = new Date();
  const expires = new Date(now.getTime() + p.days * 86400000);
  let base = env.SUPABASE_URL.replace(/\/+$/, ''); // strip trailing slash
  if (!/^https?:\/\//i.test(base)) base = 'https://' + base; // ensure scheme
  const sb = (path, init) => fetch(`${base}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: env.SUPABASE_SERVICE_KEY,
      Authorization: `Bearer ${env.SUPABASE_SERVICE_KEY}`,
      'Content-Type': 'application/json',
      ...(init.headers || {}),
    },
  });

  try {
    await sb(`subscriptions?user_id=eq.${userId}&status=eq.active`, {
      method: 'PATCH', headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({ status: 'expired' }),
    });
    const insRes = await sb('subscriptions', {
      method: 'POST', headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({
        user_id: userId, tier: p.tier, status: 'active',
        amount_inr: p.amount / 100, razorpay_id: razorpay_payment_id,
        started_at: now.toISOString(), expires_at: expires.toISOString(),
      }),
    });
    if (!insRes.ok) {
      const detail = await insRes.text();
      return cors(j({ valid: false, error: 'Subscription insert failed', status: insRes.status, detail }), 500, origin);
    }
    await sb(`profiles?id=eq.${userId}`, {
      method: 'PATCH', headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({ subscription_tier: p.tier, subscription_end: expires.toISOString() }),
    });
  } catch (e) {
    return cors(j({ valid: false, error: 'Supabase write error', detail: e.message }), 500, origin);
  }

  return cors(j({ valid: true, tier: p.tier, plan, expires_at: expires.toISOString() }), 200, origin);
}

// ── Helpers ─────────────────────────────────────────────────────────────────
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
