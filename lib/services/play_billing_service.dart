import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dharma_ai/config/payment_config.dart';
import 'package:dharma_ai/services/supabase_sync.dart';

// Play product IDs — must match what's created in Play Console (Step 6).
// These are consumable in-app products: user buys once → N days granted → consumed.
const Set<String> kPlayProductIds = {
  'dharmaai_monthly',
  'dharmaai_quarterly',
  'dharmaai_annual',
};

class PlayBillingResult {
  final bool success;
  final String? error; // null when user merely cancelled (no error to show)
  const PlayBillingResult({required this.success, this.error});
}

/// Singleton that owns the IAP purchase stream.
/// Call [initialize] once (e.g. in the paywall's initState) and [dispose] on teardown.
class PlayBillingService {
  static final PlayBillingService _i = PlayBillingService._();
  factory PlayBillingService() => _i;
  PlayBillingService._();

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Completer<PlayBillingResult>? _pending;

  void initialize() {
    if (kIsWeb) return;
    _sub?.cancel();
    _sub = _iap.purchaseStream.listen(_onPurchaseUpdate);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  /// Initiate a purchase for [productId] (one of [kPlayPlans] keys).
  /// Returns a [PlayBillingResult] after the purchase + server verification.
  Future<PlayBillingResult> purchase(String productId) async {
    if (kIsWeb) {
      return const PlayBillingResult(success: false, error: 'Play Billing unavailable on web');
    }
    if (!await _iap.isAvailable()) {
      return const PlayBillingResult(success: false, error: 'Google Play is not available');
    }

    final response = await _iap.queryProductDetails({productId});
    if (response.productDetails.isEmpty) {
      return const PlayBillingResult(success: false, error: 'Product unavailable — please try again');
    }

    _pending = Completer<PlayBillingResult>();
    await _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: response.productDetails.first),
    );
    return _pending!.future;
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          continue; // waiting for user to confirm in Play UI

        case PurchaseStatus.purchased:
          final result = await _verifyAndGrant(p);
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          _complete(result);

        case PurchaseStatus.canceled:
          _complete(const PlayBillingResult(success: false)); // no error — user cancelled

        case PurchaseStatus.error:
          final msg = p.error?.message ?? 'Purchase failed';
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          _complete(PlayBillingResult(success: false, error: msg));

        case PurchaseStatus.restored:
          break; // not used (consumables don't restore)
      }
    }
  }

  void _complete(PlayBillingResult result) {
    _pending?.complete(result);
    _pending = null;
  }

  Future<PlayBillingResult> _verifyAndGrant(PurchaseDetails purchase) async {
    final userId = SupabaseSync.userId;
    if (userId == null) {
      return const PlayBillingResult(success: false, error: 'Not signed in');
    }

    String? purchaseToken;
    if (purchase is GooglePlayPurchaseDetails) {
      purchaseToken = purchase.billingClientPurchase.purchaseToken;
    }
    if (purchaseToken == null) {
      return const PlayBillingResult(success: false, error: 'Invalid purchase token');
    }

    final accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken ?? '';

    try {
      final res = await http.post(
        Uri.parse('${PaymentConfig.workerUrl}/play/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'purchase_token': purchaseToken,
          'product_id': purchase.productID,
          'user_id': userId,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['valid'] == true) {
        return const PlayBillingResult(success: true);
      }
      return PlayBillingResult(
        success: false,
        error: body['error']?.toString() ?? 'Verification failed',
      );
    } catch (e) {
      return PlayBillingResult(success: false, error: 'Network error: $e');
    }
  }
}
