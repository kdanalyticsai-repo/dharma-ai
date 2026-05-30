class OpenAIConfig {
  // SECURITY: never hard-code a real key here — this file is committed.
  // In production, requests go through the Cloudflare Worker so the key
  // stays server-side. This apiKey is only a local-dev fallback and must be
  // supplied via --dart-define=OPENAI_API_KEY=xxx (see run_dev.ps1).
  static const String apiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: 'YOUR_OPENAI_API_KEY',
  );

  static const String model = 'gpt-4o-mini';

  // Production: Cloudflare Worker URL (key hidden server-side)
  // Development: Direct OpenAI (key in env var)
  static const String _workerUrl = 'YOUR_CLOUDFLARE_WORKER_URL'; // e.g. https://dharma-ai-proxy.yourname.workers.dev
  static const String _directUrl = 'https://api.openai.com/v1/chat/completions';

  static bool get _workerConfigured => _workerUrl != 'YOUR_CLOUDFLARE_WORKER_URL';

  // Uses Worker in prod, direct API in dev
  static String get baseUrl => _workerConfigured ? _workerUrl : _directUrl;

  // Worker handles auth server-side; direct needs Bearer token
  static Map<String, String> get headers => _workerConfigured
      ? {'Content-Type': 'application/json'}
      : {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'};

  static bool get isConfigured => _workerConfigured || apiKey.startsWith('sk-');
}
