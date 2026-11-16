import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalBrowserHelper {
  static const _channel = MethodChannel('org.iump.himnario2026/browser');

  static Future<bool> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (kIsWeb) {
      return await launchUrl(uri, webOnlyWindowName: '_blank');
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await _channel.invokeMethod<bool>('openInBrowser', {'url': url});
        if (result == true) return true;
      } catch (e) {
        debugPrint('>>> Error en canal nativo de navegador: $e');
      }
    }

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }
}
