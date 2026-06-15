// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const _key = 'dharma_google_intent';

/// Persist the user's form intent (signup|signin) before the OAuth redirect.
/// sessionStorage survives same-tab redirects but is cleared on tab close.
void storeGoogleIntent(String intent) {
  html.window.sessionStorage[_key] = intent;
}

/// Read and immediately clear the stored intent.  Returns null if not set.
String? consumeGoogleIntent() {
  final v = html.window.sessionStorage[_key];
  if (v != null) html.window.sessionStorage.remove(_key);
  return v;
}
