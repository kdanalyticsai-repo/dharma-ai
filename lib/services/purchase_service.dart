import 'package:shared_preferences/shared_preferences.dart';

enum SubscriptionTier { free, sadhaka, annual }

class PurchaseService {
  static const String _subKey = 'dharma_sub_tier';

  // Check active subscription status
  Future<SubscriptionTier> getActiveSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_subKey) ?? 'free';
    if (val == 'sadhaka') return SubscriptionTier.sadhaka;
    if (val == 'annual') return SubscriptionTier.annual;
    return SubscriptionTier.free;
  }

  // Set active subscription status (simulate purchase)
  Future<bool> purchaseSadhaka() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.delayed(const Duration(milliseconds: 1200)); // Simulate RevenueCat / Apple Billing
    return prefs.setString(_subKey, 'sadhaka');
  }

  Future<bool> purchaseAnnual() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.delayed(const Duration(milliseconds: 1200));
    return prefs.setString(_subKey, 'annual');
  }

  // Reset subscription status
  Future<bool> resetSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_subKey, 'free');
  }

  // Gift subscription to friend (simulate code generation)
  Future<String> purchaseGiftCode(String friendName) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final randomCode = 'DHARMA-GIFT-${DateTime.now().millisecond}';
    return randomCode;
  }
}
