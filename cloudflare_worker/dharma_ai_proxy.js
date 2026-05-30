// DharmaAI — Cloudflare Worker Proxy
// Keeps OpenAI API key server-side, never exposed to browser
//
// Setup:
//   1. Deploy this to Cloudflare Workers
//   2. Add secret: wrangler secret put OPENAI_API_KEY
//      OR in dashboard: Settings → Variables → Add OPENAI_API_KEY
//   3. Update Flutter app to call this worker URL instead of OpenAI directly

export default {
  async fetch(request, env) {

    // Allow only POST requests
    if (request.method === 'OPTIONS') {
      return corsResponse('', 204);
    }
    if (request.method !== 'POST') {
      return corsResponse(JSON.stringify({ error: 'Method not allowed' }), 405);
    }

    // Only allow requests from your app domain
    const origin = request.headers.get('Origin') || '';
    const allowed = ['http://localhost:3456', 'https://dharmaai.kdaanalytics.com'];
    if (!allowed.some(o => origin.startsWith(o))) {
      return corsResponse(JSON.stringify({ error: 'Forbidden' }), 403);
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
      return corsResponse(JSON.stringify(data), openaiRes.status);

    } catch (e) {
      return corsResponse(JSON.stringify({ error: 'Proxy error', detail: e.message }), 500);
    }
  }
};

function corsResponse(body, status = 200) {
  return new Response(body, {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
  });
}
