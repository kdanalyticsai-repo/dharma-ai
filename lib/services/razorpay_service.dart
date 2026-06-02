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
  /// [plan] is 'monthly' | 'quarterly' | 'annual'.
  Future<bool> checkout({
    required String plan,
    required String userId,
    String? email,
    String? name,
  }) async {
    if (!PaymentConfig.isConfigured) {
      throw Exception('Payments are not configured.');
    }

    // 1. Create the order on the server.
    final orderRes = await http.post(
      Uri.parse(PaymentConfig.orderUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'plan': plan, 'user_id': userId}),
    );
    if (orderRes.statusCode != 200) {
      throw Exception('Could not start payment. Please try again.');
    }
    final order = jsonDecode(orderRes.body) as Map<String, dynamic>;

    // 2. Open the Razorpay checkout.
    final result = await openCheckout({
      'order_id': order['order_id'],
      'amount': order['amount'],
      'currency': order['currency'],
      'key_id': order['key_id'],
      'plan_label': order['plan_label'],
      'email': email ?? '',
      'name': name ?? '',
    });
    if (!result.success) return false; // cancelled or failed

    // 3. Verify server-side — the Worker grants the subscription.
    final verifyRes = await http.post(
      Uri.parse(PaymentConfig.verifyUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'razorpay_order_id': result.orderId,
        'razorpay_payment_id': result.paymentId,
        'razorpay_signature': result.signature,
      }),
    );
    if (verifyRes.statusCode != 200) return false;
    final v = jsonDecode(verifyRes.body) as Map<String, dynamic>;
    return v['valid'] == true;
  }
}
