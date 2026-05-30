class GeminiConfig {
  // SECURITY: never hard-code a real key here — this file is committed.
  // Inject at build/run time: --dart-define=GEMINI_API_KEY=xxx
  // (see run_dev.ps1 for local dev, GitHub Secrets for CI).
  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'YOUR_GEMINI_API_KEY',
  );

  static const String model = 'gemini-1.5-flash-latest';
  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1/models';

  // AQ. keys use header auth — key goes in x-goog-api-key, NOT ?key= param
  static String get generateContentUrl => '$baseUrl/$model:generateContent';

  static bool get isConfigured => apiKey.isNotEmpty && apiKey != 'YOUR_GEMINI_API_KEY';
}
