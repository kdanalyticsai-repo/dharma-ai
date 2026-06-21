// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

bool get pwaInstallAvailable {
  try {
    return js.context['_dharmaIsInstallable'] == true;
  } catch (_) {
    return false;
  }
}

void pwaInstall() {
  try {
    js.context.callMethod('dharmaInstallPWA', []);
  } catch (_) {}
}
