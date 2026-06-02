/// Result of a Razorpay checkout attempt.
class RazorpayResult {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? error;

  const RazorpayResult.success(this.paymentId, this.orderId, this.signature)
      : success = true,
        error = null;

  const RazorpayResult.failure(this.error)
      : success = false,
        paymentId = null,
        orderId = null,
        signature = null;
}
