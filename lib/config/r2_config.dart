class R2Config {
  // Injected at build time via --dart-define=R2_BUCKET_URL=xxx
  static const String bucketUrl = String.fromEnvironment(
    'R2_BUCKET_URL',
    defaultValue: 'https://audio.kdaanalytics.com', // local dev only
  );

  static bool get isConfigured =>
      bucketUrl.isNotEmpty && bucketUrl.startsWith('https://');

  static String audioUrl(String fileName) => '$bucketUrl/$fileName';
}
