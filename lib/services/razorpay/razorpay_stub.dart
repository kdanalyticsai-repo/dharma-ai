import 'razorpay_result.dart';

/// Non-web fallback. Razorpay web checkout only runs on the web build;
/// on Android the app will use Google Play Billing instead.
Future<RazorpayResult> openCheckout(Map<String, dynamic> options) async {
  return const RazorpayResult.failure('Web checkout is not available on this platform.');
}
