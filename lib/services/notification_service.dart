import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Must be a top-level function — FCM plugin requirement for background messages.
@pragma('vm:entry-point')
Future<void> _bgMessageHandler(RemoteMessage message) async {}

class NotificationService {
  NotificationService._();

  // Web Push certificate (VAPID) key — injected at build time via --dart-define.
  // Generate in Firebase Console → Project Settings → Cloud Messaging →
  // Web configuration → Generate key pair. Add FIREBASE_VAPID_KEY to
  // run_dev.ps1, deploy.yml secrets, and (for AAB) build_release.ps1.
  static const _vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  // Emits a screen name whenever the user taps a notification.
  static final _tapController = StreamController<String>.broadcast();
  static Stream<String> get onNotificationTap => _tapController.stream;

  // Set when app was terminated and launched via a notification tap. Consumed once.
  // Always null on web (no terminated-app concept in browsers).
  static String? _pendingScreen;
  static String? get pendingScreen {
    final s = _pendingScreen;
    _pendingScreen = null;
    return s;
  }

  static Future<void> initialize() async {
    // Background handler runs in a separate isolate (Android only).
    // Web background notifications are handled by firebase-messaging-sw.js.
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_bgMessageHandler);
    }

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

    // App was terminated → user taps notification to launch it (Android only).
    if (!kIsWeb) {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial?.data['screen'] != null) {
        _pendingScreen = initial!.data['screen'];
      }
    }

    // If user is already signed in at startup, save token now.
    await _saveFcmToken();
  }

  static Future<void> _saveFcmToken() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      // Web requires the VAPID key; skip silently if it hasn't been configured.
      if (kIsWeb && _vapidKey.isEmpty) return;
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? _vapidKey : null,
      );
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
