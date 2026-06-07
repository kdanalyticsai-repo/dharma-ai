import 'dart:html' as html;

bool isMobileAndroidBrowser() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('android');
}

bool getBannerDismissed() {
  return html.window.localStorage['app_banner_dismissed'] == '1';
}

void setBannerDismissed() {
  html.window.localStorage['app_banner_dismissed'] = '1';
}
