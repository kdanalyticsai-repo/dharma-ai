import 'package:shared_preferences/shared_preferences.dart';
import 'package:dharma_ai/services/supabase_sync.dart';

enum SubscriptionTier { free, sadhaka, annual }

class PurchaseService {
  static const String _subKey = 'dharma_sub_tier';

  // Pricing (INR) — matches the paywall screen.
  static const int _sadhakaInr = 201;
  static const int _annualInr = 1100;

  // Check active subscription status.
  // When signed in, the profiles.subscription_tier row is the source of
  // truth (syncs across devices); otherwise fall back to local storage.
  Future<SubscriptionTier> getActiveSubscription() async {
    final remote = await _fetchRemoteTier();
    if (remote != null) {
      // Keep local cache in sync for offline/fast startup.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_subKey, _tierToString(remote));
      return remote;
    }
    final prefs = await SharedPreferences.getInstance();
    return _tierFromString(prefs.getString(_subKey) ?? 'free');
  }

  Future<bool> purchaseSadhaka() async {
    await Future.delayed(const Duration(milliseconds: 1200)); // Simulate gateway
    await _persist(SubscriptionTier.sadhaka, _sadhakaInr,
        const Duration(days: 30));
    return true;
  }

  Future<bool> purchaseAnnual() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    await _persist(SubscriptionTier.annual, _annualInr,
        const Duration(days: 365));
    return true;
  }

  // Reset subscription status (downgrade to free).
  Future<bool> resetSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subKey, 'free');

    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    if (client != null && uid != null) {
      try {
        await client.from('subscriptions').update({'status': 'cancelled'})
            .eq('user_id', uid).eq('status', 'active');
        await client.from('profiles').update({
          'subscription_tier': 'free',
          'subscription_end': null,
        }).eq('id', uid);
      } catch (e) {
        // Non-blocking — local state already updated.
      }
    }
    return true;
  }

  // ── Persistence helpers ─────────────────────────────────────

  Future<void> _persist(SubscriptionTier tier, int amountInr, Duration period) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subKey, _tierToString(tier));

    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    if (client == null || uid == null) return; // local-only when signed out

    final now = DateTime.now();
    final expiresAt = now.add(period);
    try {
      // Mark any previous active subscriptions as expired, then add the new one.
      await client.from('subscriptions').update({'status': 'expired'})
          .eq('user_id', uid).eq('status', 'active');
      await client.from('subscriptions').insert({
        'user_id': uid,
        'tier': _tierToString(tier),
        'status': 'active',
        'amount_inr': amountInr,
        'started_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      });
      // Profile tier is the quick-lookup source of truth.
      await client.from('profiles').update({
        'subscription_tier': _tierToString(tier),
        'subscription_end': expiresAt.toIso8601String(),
      }).eq('id', uid);
    } catch (e) {
      // Non-blocking — local state already reflects the purchase.
    }
  }

  Future<SubscriptionTier?> _fetchRemoteTier() async {
    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    if (client == null || uid == null) return null;
    try {
      final row = await client.from('profiles')
          .select('subscription_tier')
          .eq('id', uid)
          .maybeSingle();
      if (row == null) return null;
      return _tierFromString(row['subscription_tier'] as String? ?? 'free');
    } catch (_) {
      return null;
    }
  }

  // Gift subscription to friend (still a mock code generator).
  Future<String> purchaseGiftCode(String friendName) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    return 'DHARMA-GIFT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  String _tierToString(SubscriptionTier t) => t.name; // free | sadhaka | annual

  SubscriptionTier _tierFromString(String s) {
    switch (s) {
      case 'sadhaka':
        return SubscriptionTier.sadhaka;
      case 'annual':
        return SubscriptionTier.annual;
      default:
        return SubscriptionTier.free;
    }
  }
}
