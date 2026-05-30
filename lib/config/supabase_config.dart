class SupabaseConfig {
  // Get these from: supabase.com → Project → Settings → API
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'YOUR_SUPABASE_URL', // e.g. https://xxxx.supabase.co
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseUrl.startsWith('https://') &&
      supabaseAnonKey.isNotEmpty &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY';
}
