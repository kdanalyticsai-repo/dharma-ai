import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dharma_ai/services/purchase_service.dart';

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService();
});

class PurchaseNotifier extends StateNotifier<SubscriptionTier> {
  final PurchaseService _service;

  PurchaseNotifier(this._service) : super(SubscriptionTier.free) {
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    state = await _service.getActiveSubscription();
  }

  // Re-read the active tier (e.g. after a web Razorpay payment the Worker
  // has written the subscription to Supabase).
  Future<void> refresh() async {
    state = await _service.getActiveSubscription();
  }

  Future<bool> buySadhaka() async {
    final success = await _service.purchaseSadhaka();
    if (success) state = SubscriptionTier.sadhaka;
    return success;
  }

  Future<bool> buyQuarterly() async {
    final success = await _service.purchaseQuarterly();
    if (success) state = SubscriptionTier.sadhaka; // same tier/features, 3-month billing
    return success;
  }

  Future<bool> buyAnnual() async {
    final success = await _service.purchaseAnnual();
    if (success) state = SubscriptionTier.annual;
    return success;
  }

  Future<void> downgrade() async {
    final success = await _service.resetSubscription();
    if (success) state = SubscriptionTier.free;
  }
}

final purchaseProvider = StateNotifierProvider<PurchaseNotifier, SubscriptionTier>((ref) {
  final service = ref.watch(purchaseServiceProvider);
  return PurchaseNotifier(service);
});

// Exact active billing plan (free|monthly|quarterly|annual) for the paywall UI.
// Re-reads whenever the tier changes.
final activePlanProvider = FutureProvider<String>((ref) async {
  ref.watch(purchaseProvider);
  return ref.read(purchaseServiceProvider).getActivePlan();
});

// When the current premium access ends (for the paywall status line).
final subscriptionEndProvider = FutureProvider<DateTime?>((ref) async {
  ref.watch(purchaseProvider);
  return ref.read(purchaseServiceProvider).getSubscriptionEnd();
});

// ── Shared subscription status messaging ────────────────────────────────────
// Used everywhere we show the subscription end date so the wording is
// identical: active plans show "active until …"; lapsed plans show that the
// user has defaulted to Free.
String _formatSubDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// True once the subscription end date has passed.
bool isSubscriptionExpired(DateTime? end) =>
    end != null && end.isBefore(DateTime.now());

/// The status line to show wherever the subscription end date appears.
/// Returns null for users who never subscribed (no end date).
/// [planLabel] (e.g. "Sadhaka Annual") is used when known; otherwise a generic
/// wording is used.
String? subscriptionStatusLine(DateTime? end, {String? planLabel}) {
  if (end == null) return null;
  final d = _formatSubDate(end);
  if (isSubscriptionExpired(end)) {
    return planLabel != null
        ? 'Your $planLabel ended on $d — you\'re now on the Free plan.'
        : 'Your subscription ended on $d — you\'re now on the Free plan.';
  }
  return planLabel != null
      ? '$planLabel active until $d · won\'t auto-renew'
      : 'Valid until $d';
}
