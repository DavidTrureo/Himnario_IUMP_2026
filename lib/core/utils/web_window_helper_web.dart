// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:convert';
import 'dart:js' as js;

/// Web implementation using BroadcastChannel and window.open
class WebWindowHelper {
  static html.BroadcastChannel? _channel;

  static void openProjectorWindow(String url) {
    try {
      js.context.callMethod('eval', [
        '''
        (async function() {
          try {
            if (window.getScreenDetails) {
              const screenDetails = await window.getScreenDetails();
              const screens = screenDetails.screens || [];
              const currentScreen = screenDetails.currentScreen;
              let targetScreen = screens.find(s => s.isInternal === false) || screens.find(s => s !== currentScreen);
              if (targetScreen) {
                const left = targetScreen.availLeft;
                const top = targetScreen.availTop;
                const width = targetScreen.availWidth;
                const height = targetScreen.availHeight;
                window.open('$url', 'ProjectorView', `left=\${left},top=\${top},width=\${width},height=\${height},menubar=no,toolbar=no,popup=1,fullscreen=yes`);
                return;
              }
            }
          } catch (e) {}
          window.open('$url', 'ProjectorView', 'width=1280,height=720,menubar=no,toolbar=no,popup=1,fullscreen=yes');
        })();
        '''
      ]);
      return;
    } catch (_) {}

    // Fallback: Abre una nueva ventana en el monitor principal
    html.window.open(url, 'ProjectorView', 'width=1280,height=720,menubar=no,toolbar=no,popup=1,fullscreen=yes');
  }

  static void broadcastProjectorState(int slideIndex, String theme, double fontSize, {bool isBlank = false, String? hymnId, String? collection}) {
    _channel ??= html.BroadcastChannel('projector_channel');
    final data = jsonEncode({
      'slideIndex': slideIndex,
      'theme': theme,
      'fontSize': fontSize,
      'isBlank': isBlank,
      if (hymnId != null) 'hymnId': hymnId,
      if (collection != null) 'collection': collection,
    });
    _channel!.postMessage(data);
  }

  static void listenToProjectorState(Function(int slideIndex, String theme, double fontSize, bool isBlank, String? hymnId, String? collection) onStateChanged) {
    _channel ??= html.BroadcastChannel('projector_channel');
    _channel!.onMessage.listen((event) {
      if (event.data is String) {
        try {
          final data = jsonDecode(event.data as String);
          if (data is Map && data.containsKey('slideIndex')) {
            onStateChanged(
              data['slideIndex'] as int,
              data.containsKey('theme') ? data['theme'] as String : 'darkPremium',
              data.containsKey('fontSize') ? (data['fontSize'] as num).toDouble() : 40.0,
              data.containsKey('isBlank') ? data['isBlank'] as bool : false,
              data['hymnId'] as String?,
              data['collection'] as String?,
            );
          }
        } catch (_) {}
      }
    });
  }

  static void dispose() {
    _channel?.close();
    _channel = null;
  }
}
