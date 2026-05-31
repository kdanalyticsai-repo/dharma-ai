import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dharma_ai/config/supabase_config.dart';

/// Thin helper around the Supabase client used by the data services.
/// Returns null / false whenever Supabase isn't configured or the user
/// isn't signed in — callers then fall back to local storage.
class SupabaseSync {
  static SupabaseClient? get client {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static String? get userId => client?.auth.currentUser?.id;

  static bool get isSignedIn => userId != null;
}
