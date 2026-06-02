// Platform-conditional Razorpay checkout entry point.
// Web → razorpay_web.dart (JS interop); other platforms → stub.
export 'razorpay_result.dart';
export 'razorpay_stub.dart' if (dart.library.js) 'razorpay_web.dart';
