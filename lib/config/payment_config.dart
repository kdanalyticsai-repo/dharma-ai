/// Payment backend config. The Razorpay endpoints live on the same Cloudflare
/// Worker as the OpenAI proxy (so the Razorpay secret stays server-side),
/// addressed via the OPENAI_WORKER_URL build define.
class PaymentConfig {
  static const String workerUrl = String.fromEnvironment(
    'OPENAI_WORKER_URL',
    defaultValue: '',
  );

  static bool get isConfigured =>
      workerUrl.startsWith('http') && workerUrl != 'YOUR_CLOUDFLARE_WORKER_URL';

  static String get orderUrl => '$workerUrl/razorpay/order';
  static String get verifyUrl => '$workerUrl/razorpay/verify';
  static String get redeemUrl => '$workerUrl/razorpay/redeem';
}
