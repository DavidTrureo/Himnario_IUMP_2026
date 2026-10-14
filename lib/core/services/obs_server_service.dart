import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final obsServerProvider = Provider<ObsServerService>((ref) {
  return ObsServerService();
});

class ObsServerService {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  bool get isRunning => _server != null;
  String? currentIp;

  Future<void> startServer() async {
    if (_server != null) return;

    try {
      // Find local IP
      currentIp = await _getLocalIp();
      
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      print('OBS Server started on port 8080');

      _server!.listen((HttpRequest request) {
        if (request.uri.path == '/ws') {
          WebSocketTransformer.upgrade(request).then((WebSocket ws) {
            _clients.add(ws);
            ws.listen(
              (data) {},
              onDone: () => _clients.remove(ws),
              onError: (e) => _clients.remove(ws),
            );
          });
        } else if (request.uri.path == '/') {
          // Serve the HTML file
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write(_htmlContent(currentIp ?? 'localhost'))
            ..close();
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
        }
      });
    } catch (e) {
      print('Error starting OBS server: $e');
    }
  }

  Future<void> stopServer() async {
    for (final client in _clients) {
      client.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    currentIp = null;
  }

  void broadcastLyric(String lyric) {
    // Escape backslashes, newlines, and quotes
    final escapedLyric = lyric
      .replaceAll('\\', '\\\\')
      .replaceAll('\n', '\\n')
      .replaceAll('"', '\\"');
      
    final json = '{"lyric": "$escapedLyric"}';
    for (final client in _clients) {
      client.add(json);
    }
  }

  Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLinkLocal: false);
      for (var interface in interfaces) {
        for (var address in interface.addresses) {
          if (!address.isLoopback) {
            return address.address;
          }
        }
      }
    } catch (e) {
      print('Error getting IP: $e');
    }
    return null;
  }

  String _htmlContent(String ip) {
    return '''
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OBS Lyrics Overlay</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Nunito:wght@700&display=swap');
        
        body {
            margin: 0;
            padding: 0;
            background-color: transparent;
            overflow: hidden;
            display: flex;
            align-items: flex-end; /* Alinear al fondo */
            justify-content: center;
            height: 100vh;
        }

        #lyric-container {
            width: 90%;
            text-align: center;
            margin-bottom: 50px; /* Margen inferior */
        }

        #lyric-text {
            font-family: 'Nunito', sans-serif;
            font-size: 50px;
            color: white;
            font-weight: bold;
            text-shadow: 
                3px 3px 0 #000,
                -1px -1px 0 #000,
                1px -1px 0 #000,
                -1px 1px 0 #000,
                1px 1px 0 #000,
                0px 5px 15px rgba(0,0,0,0.8);
            opacity: 0;
            transform: translateY(20px);
            transition: opacity 0.5s ease, transform 0.5s ease;
        }

        .show {
            opacity: 1 !important;
            transform: translateY(0) !important;
        }
    </style>
</head>
<body>
    <div id="lyric-container">
        <div id="lyric-text"></div>
    </div>

    <script>
        const lyricText = document.getElementById('lyric-text');
        
        function connect() {
            // Conectar al WebSocket del teléfono
            const ws = new WebSocket('ws://' + window.location.host + '/ws');
            
            ws.onmessage = function(event) {
                const data = JSON.parse(event.data);
                
                if (data.lyric === "") {
                    // Ocultar letra
                    lyricText.classList.remove('show');
                } else {
                    // Ocultar suavemente, cambiar texto y mostrar suavemente
                    lyricText.classList.remove('show');
                    setTimeout(() => {
                        lyricText.innerHTML = data.lyric.replace(/\\n/g, '<br>');
                        lyricText.classList.add('show');
                    }, 500); // Esperar a que termine la animación de salida
                }
            };

            ws.onclose = function() {
                console.log('Desconectado. Reconectando en 2 segundos...');
                setTimeout(connect, 2000);
            };
        }

        connect();
    </script>
</body>
</html>
''';
  }
}
