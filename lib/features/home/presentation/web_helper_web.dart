// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:js' as js;

String get initialWebHash {
  try {
    final jsHash = js.context['_initialWebHash'] as String?;
    if (jsHash != null && jsHash.isNotEmpty) return jsHash;
  } catch (_) {}
  try {
    final locHash = html.window.location.hash;
    if (locHash.isNotEmpty) return locHash;
  } catch (_) {}
  return '';
}

void captureWebHash() {} // No-op, ya se capturó en index.html
