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
