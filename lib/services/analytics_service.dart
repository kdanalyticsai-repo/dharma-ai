import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Firebase Analytics. Every call is guarded so analytics
/// can never crash the app (e.g. if Firebase failed to initialise, or on a
/// platform that isn't configured yet). Works on web now and Android later.
class Analytics {
  static FirebaseAnalytics? _fa;

  /// Call once after Firebase.initializeApp succeeds.
  static void attach() {
    try {
      _fa = FirebaseAnalytics.instance;
    } catch (e) {
      debugPrint('Analytics attach skipped: $e');
    }
  }

  /// A navigator observer that auto-logs screen_view on route changes.
  static FirebaseAnalyticsObserver? get observer =>
      _fa == null ? null : FirebaseAnalyticsObserver(analytics: _fa!);

  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    try {
      await _fa?.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('Analytics log "$name" failed: $e');
    }
  }

  // ── Conversion funnel events ─────────────────────────────────
  static Future<void> signUp(String method) => _log('sign_up', {'method': method});
  static Future<void> login(String method) => _log('login', {'method': method});
  static Future<void> paywallView() => _log('paywall_view');
  static Future<void> purchaseSuccess(String plan, num amountInr) =>
      _log('purchase_success', {'plan': plan, 'amount_inr': amountInr});
}
