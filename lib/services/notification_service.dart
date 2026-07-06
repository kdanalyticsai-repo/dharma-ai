import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Must be a top-level function — FCM plugin requirement for background messages.
@pragma('vm:entry-point')
Future<void> _bgMessageHandler(RemoteMessage message) async {}

class NotificationService {
  NotificationService._();

  // Emits a screen name whenever the user taps a notification (background state).
  static final _tapController = StreamController<String>.broadcast();
  static Stream<String> get onNotificationTap => _tapController.stream;

  // Set when app was terminated and launched via a notification tap. Consumed once.
  static String? _pendingScreen;
  static String? get pendingScreen {
    final s = _pendingScreen;
    _pendingScreen = null;
    return s;
  }

  static Future<void> initialize() async {
    if (kIsWeb) return;

    FirebaseMessaging.onBackgroundMessage(_bgMessageHandler);

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Save token whenever the user signs in (covers both cold start and re-auth).
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.session != null) await _saveFcmToken();
    });

    // Keep the stored token current if FCM rotates it.
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => _saveFcmToken());

    // App in background → user taps notification.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final screen = message.data['screen'];
      if (screen != null) _tapController.add(screen);
    });

    // App was terminated → user taps notification to launch it.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial?.data['screen'] != null) {
      _pendingScreen = initial!.data['screen'];
    }

    // If user is already signed in at startup, save token now.
    await _saveFcmToken();
  }

  static Future<void> _saveFcmToken() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', uid);
    } catch (_) {
      // Non-fatal: push notifications degrade silently.
    }
  }
}
