import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dharma_ai/config/payment_config.dart';
import 'package:dharma_ai/services/razorpay/razorpay_checkout.dart';

/// Orchestrates a Razorpay web payment:
///   1. ask the Worker to create an order (server sets the price),
///   2. open the Razorpay checkout in the browser,
///   3. ask the Worker to verify the signature + grant the subscription.
/// Returns true only when the Worker confirms the payment is valid.
class RazorpayService {
  /// Buy a subscription for yourself. [plan] is 'monthly'|'quarterly'|'annual'.
  /// Returns true once the Worker confirms + grants it.
  Future<bool> checkout({
    required String plan,
    required String userId,
    String? email,
    String? name,
  }) async {
    final v = await _run(plan: plan, userId: userId, email: email, name: name);
    return v?['valid'] == true;
  }

  /// Buy a subscription as a GIFT. Returns the generated gift code to share,
  /// or null if the payment was cancelled.
  Future<String?> giftCheckout({
    required String plan,
    required String userId,
    String? email,
    String? name,
  }) async {
    final v = await _run(plan: plan, userId: userId, email: email, name: name, gift: true);
    return v?['code'] as String?;
  }

  /// Redeem a gift code — the Worker grants the subscription to [userId].
  /// Returns the verify JSON ({ tier, plan, expires_at }).
  Future<Map<String, dynamic>> redeem({required String code, required String userId}) async {
    if (!PaymentConfig.isConfigured) throw Exception('Payments are not configured.');
    final res = await http.post(
      Uri.parse(PaymentConfig.redeemUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'user_id': userId}),
    );
    final v = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || v['valid'] != true) {
      throw Exception(v['error']?.toString() ?? 'Could not redeem this code.');
    }
    return v;
  }

  // Shared order → checkout → verify flow. Returns the verify JSON, or null
  // if the user cancelled. Throws (with the server reason) on failure.
  Future<Map<String, dynamic>?> _run({
    required String plan,
    required String userId,
    String? email,
    String? name,
    bool gift = false,
  }) async {
    if (!PaymentConfig.isConfigured) {
      throw Exception('Payments are not configured.');
    }

    final orderRes = await http.post(
      Uri.parse(PaymentConfig.orderUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'plan': plan, 'user_id': userId, if (gift) 'gift': true}),
    );
    if (orderRes.statusCode != 200) {
      throw Exception('Could not start payment. Please try again.');
    }
    final order = jsonDecode(orderRes.body) as Map<String, dynamic>;

    final result = await openCheckout({
      'order_id': order['order_id'],
      'amount': order['amount'],
      'currency': order['currency'],
      'key_id': order['key_id'],
      'plan_label': order['plan_label'],
      'email': email ?? '',
      'name': name ?? '',
    });
    if (!result.success) return null; // cancelled

    final verifyRes = await http.post(
      Uri.parse(PaymentConfig.verifyUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'razorpay_order_id': result.orderId,
        'razorpay_payment_id': result.paymentId,
        'razorpay_signature': result.signature,
      }),
    );
    final v = jsonDecode(verifyRes.body) as Map<String, dynamic>;
    if (verifyRes.statusCode != 200 || v['valid'] != true) {
      throw Exception(v['error']?.toString() ?? 'Payment verification failed.');
    }
    return v;
  }
}
