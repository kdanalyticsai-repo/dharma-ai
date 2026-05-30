// DharmaAI — Cloudflare Worker Proxy
// Keeps OpenAI API key server-side, never exposed to browser
//
// Setup:
//   1. wrangler deploy
//   2. wrangler secret put OPENAI_API_KEY
//   3. Set ALLOWED_ORIGINS in wrangler.toml [vars] (comma-separated, no spaces)
//      e.g. "http://localhost:3456,https://dharmaai.kdaanalytics.com"

export default {
  async fetch(request, env) {

    // Allow only POST requests
    if (request.method === 'OPTIONS') {
      return corsResponse('', 204, allowedOrigin(request, env));
    }
    if (request.method !== 'POST') {
      return corsResponse(JSON.stringify({ error: 'Method not allowed' }), 405, null);
    }

    // Only allow requests from origins listed in ALLOWED_ORIGINS env var
    const origin = request.headers.get('Origin') || '';
    const allowed = (env.ALLOWED_ORIGINS || '').split(',').filter(Boolean);
    if (!allowed.some(o => origin === o)) {
      return corsResponse(JSON.stringify({ error: 'Forbidden' }), 403, null);
    }

    try {
      const body = await request.json();

      const openaiRes = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
        },
        body: JSON.stringify(body),
      });

      const data = await openaiRes.json();
      return corsResponse(JSON.stringify(data), openaiRes.status, origin);

    } catch (e) {
      return corsResponse(JSON.stringify({ error: 'Proxy error', detail: e.message }), 500, null);
    }
  }
};

function allowedOrigin(request, env) {
  const origin = request.headers.get('Origin') || '';
  const allowed = (env.ALLOWED_ORIGINS || '').split(',').filter(Boolean);
  return allowed.includes(origin) ? origin : null;
}

function corsResponse(body, status = 200, origin = null) {
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
  if (origin) headers['Access-Control-Allow-Origin'] = origin;
  return new Response(body, { status, headers });
}
