import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'razorpay_result.dart';

/// Opens the Razorpay checkout (loaded via web/index.html) and completes when
/// the user pays, cancels, or the payment fails.
Future<RazorpayResult> openCheckout(Map<String, dynamic> options) {
  final completer = Completer<RazorpayResult>();

  void onSuccess(String paymentId, String orderId, String signature) {
    if (!completer.isCompleted) {
      completer.complete(RazorpayResult.success(paymentId, orderId, signature));
    }
  }

  void onFailure(String reason) {
    if (!completer.isCompleted) {
      completer.complete(RazorpayResult.failure(reason));
    }
  }

  try {
    js.context.callMethod('dharmaOpenRazorpay', [
      jsonEncode(options),
      js_util.allowInterop(onSuccess),
      js_util.allowInterop(onFailure),
    ]);
  } catch (e) {
    if (!completer.isCompleted) {
      completer.complete(RazorpayResult.failure('bridge_error: $e'));
    }
  }

  return completer.future;
}
