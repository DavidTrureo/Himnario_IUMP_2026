// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:convert';
import 'dart:js_util' as js_util;

/// Web implementation using BroadcastChannel and window.open
class WebWindowHelper {
  static html.BroadcastChannel? _channel;

  static void openProjectorWindow(String url) async {
    try {
      if (js_util.hasProperty(html.window, 'getScreenDetails')) {
        final screenDetails = await js_util.promiseToFuture(
            js_util.callMethod(html.window, 'getScreenDetails', []));
        final screens = js_util.getProperty(screenDetails, 'screens') as List;
        final currentScreen = js_util.getProperty(screenDetails, 'currentScreen');

        Object? targetScreen;
        for (var s in screens) {
          if (js_util.getProperty(s, 'isInternal') == false) {
            targetScreen = s;
            break;
          }
        }
        
        if (targetScreen == null) {
          for (var s in screens) {
            if (s != currentScreen) {
              targetScreen = s;
              break;
            }
          }
        }

        if (targetScreen != null) {
          final left = js_util.getProperty(targetScreen, 'availLeft');
          final top = js_util.getProperty(targetScreen, 'availTop');
          final width = js_util.getProperty(targetScreen, 'availWidth');
          final height = js_util.getProperty(targetScreen, 'availHeight');

          html.window.open(url, 'ProjectorView', 'left=$left,top=$top,width=$width,height=$height,menubar=no,toolbar=no,popup=1,fullscreen=yes');
          return;
        }
      }
    } catch (e) {
      // Ignorar si el navegador no soporta la API o deniegan el permiso
    }

    // Abre una nueva ventana en el monitor principal por defecto
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
