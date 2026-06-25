// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

bool get pwaInstallAvailable {
  try {
    final v = js.context['_dharmaIsInstallable'];
    return v != null && v == true;
  } catch (_) {
    return false;
  }
}

void pwaInstall() {
  try {
    if (js.context.hasProperty('dharmaInstallPWA')) {
      js.context.callMethod('dharmaInstallPWA', []);
    }
  } catch (_) {}
}
