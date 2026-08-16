import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  // v7.4.0: formats: [BarcodeFormat.qrCode] evita el bug de NullPointerException
  // en ML Kit al inicializar — solo carga el modelo para QR, no todos los formatos.
  // autoStart: false + delay manual para dejar que CameraX se estabilice.
  MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
    detectionSpeed: DetectionSpeed.normal,
    autoStart: false,
    formats: [BarcodeFormat.qrCode], // ← clave para evitar la NPE en Samsung
  );

  bool _isProcessing = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  String _nativeErrorMessage = '';
  final TextEditingController _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Delay de 500ms para que el sistema inicialice la cámara limpiamente
    Future.delayed(const Duration(milliseconds: 500), _startCamera);
  }

  Future<void> _startCamera() async {
    if (!mounted) return;
    try {
      await _controller.start();
      _retryCount = 0;
      if (mounted) setState(() => _nativeErrorMessage = '');
    } catch (e, st) {
      final buf = StringBuffer();
      buf.writeln('=== ERROR NATIVO ===');
      buf.writeln('Tipo: ${e.runtimeType}');
      if (e is MobileScannerException) {
        buf.writeln('Código: ${e.errorCode.name}');
        buf.writeln('Mensaje: ${e.errorDetails?.message ?? "sin mensaje"}');
        buf.writeln('Detalles: ${e.errorDetails?.details ?? "sin detalles"}');
      } else {
        buf.writeln('Excepción: $e');
      }
      buf.writeln('--- StackTrace (600 chars) ---');
      final stStr = st.toString();
      buf.write(stStr.substring(0, stStr.length.clamp(0, 600)));
      debugPrint(buf.toString());
      if (mounted) setState(() => _nativeErrorMessage = buf.toString());
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (!mounted || _retryCount >= _maxRetries) return;
    _retryCount++;
    debugPrint('Camera retry attempt $_retryCount/$_maxRetries');
    Future.delayed(Duration(milliseconds: 800 * _retryCount), _startCamera);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    switch (state) {
      case AppLifecycleState.resumed:
        Future.delayed(const Duration(milliseconds: 400), _startCamera);
      case AppLifecycleState.paused:
        unawaited(_controller.stop());
      default:
        break;
    }
  }

  void _manualRetry() {
    _retryCount = 0;
    _controller.dispose();
    _controller = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
      detectionSpeed: DetectionSpeed.normal,
      autoStart: false,
      formats: [BarcodeFormat.qrCode],
    );
    if (mounted) setState(() => _nativeErrorMessage = '');
    Future.delayed(const Duration(milliseconds: 500), _startCamera);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      _controller.stop(); // Fuerza el apagado de la cámara, especialmente en web
    } catch (_) {}
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  // ────────────── DETECCIÓN ──────────────

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        final sessionId = _extractSessionId(raw);
        if (sessionId != null) {
          _isProcessing = true;
          unawaited(_controller.stop());
          if (mounted) context.pushReplacement('/culto-en-vivo/$sessionId');
          break;
        }
      }
    }
  }

  String? _extractSessionId(String input) {
    final clean = input.trim();
    final match = RegExp(r'culto-en-vivo/([a-zA-Z0-9_\-]+)').firstMatch(clean);
    if (match != null) return match.group(1);
    if (clean.length >= 6 && !clean.contains(' ')) return clean;
    return null;
  }

  // ────────────── ENTRADA MANUAL ──────────────

  void _showManualEntryDialog() {
    _manualController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: const Color(0xFF1E1B4B),
        title: Text('Código de Sesión',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _manualController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ej. 1723456789',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon:
                const Icon(Icons.qr_code_rounded, color: Colors.white54),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final id = _extractSessionId(_manualController.text);
              if (id != null) {
                Navigator.pop(ctx);
                context.pushReplacement('/culto-en-vivo/$id');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Unirse'),
          ),
        ],
      ),
    );
  }

  // ────────────── VISTA DE PERMISO DENEGADO ──────────────

  Widget _buildPermissionView() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_rounded,
                          color: Colors.amber, size: 60),
                      const SizedBox(height: 14),
                      Text('Se requiere acceso a la Cámara',
                          style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      Text(
                        '1. Toca "Abrir Ajustes"\n'
                        '2. Presiona "Permisos" → "Cámara"\n'
                        '3. Elige "Permitir solo con la app en uso"\n'
                        '4. Vuelve a la app',
                        style: GoogleFonts.nunito(
                            color: Colors.amber, fontSize: 13, height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await SystemNavigator.pop();
                          },
                          icon: const Icon(Icons.settings_rounded),
                          label: const Text('Abrir Ajustes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _manualRetry,
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.white70),
                          label: const Text('Reintentar',
                              style: TextStyle(color: Colors.white70)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _showManualEntryDialog,
                  icon:
                      const Icon(Icons.keyboard_rounded, color: Colors.amber),
                  label: const Text('Ingresar Código Manualmente',
                      style: TextStyle(
                          color: Colors.amber, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.black,
                    side: const BorderSide(color: Colors.amber),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────── VISTA DE ERROR GENÉRICO ──────────────

  Widget _buildGenericErrorView(MobileScannerException error) {
    final String nativeMsg =
        error.errorDetails?.message ?? 'sin mensaje';
    final String nativeDetails =
        error.errorDetails?.details?.toString() ?? 'sin detalles';
    final String fullDiag = _nativeErrorMessage.isNotEmpty
        ? _nativeErrorMessage
        : '=== ERROR NATIVO ===\n'
            'Código: ${error.errorCode.name}\n'
            'Mensaje: $nativeMsg\n'
            'Detalles: $nativeDetails';

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 52),
              const SizedBox(height: 12),
              Text('No se pudo iniciar la cámara',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('Código: ${error.errorCode.name}',
                  style:
                      GoogleFonts.nunito(color: Colors.amber, fontSize: 12)),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0000),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🔍 Diagnóstico:',
                        style: GoogleFonts.sourceCodePro(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    SelectableText(fullDiag,
                        style: GoogleFonts.sourceCodePro(
                            color: Colors.white70,
                            fontSize: 10,
                            height: 1.5)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: fullDiag));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Error copiado'),
                        duration: Duration(seconds: 2)));
                  },
                  icon: const Icon(Icons.copy_rounded,
                      color: Colors.white60, size: 15),
                  label: const Text('Copiar diagnóstico',
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _manualRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _showManualEntryDialog,
                icon:
                    const Icon(Icons.keyboard_rounded, color: Colors.amber),
                label: const Text('Ingresar Código Manualmente',
                    style: TextStyle(color: Colors.amber)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.amber),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────── OVERLAY DEL VISOR ──────────────

  Widget _buildScannerOverlay(BoxConstraints constraints) {
    return Stack(
      children: [
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border:
                  Border.all(color: const Color(0xFF6366F1), width: 3),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.of(context).padding.bottom + 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  'Apunta al código QR del Director de Culto',
                  style: GoogleFonts.outfit(
                      color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _showManualEntryDialog,
                icon: const Icon(Icons.keyboard_rounded,
                    color: Colors.white),
                label: const Text('Ingresar Código Manualmente',
                    style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.6),
                  side: const BorderSide(color: Colors.white70),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────── BUILD ──────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Escanear QR de Culto',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, child) {
              if (!state.isInitialized || state.error != null) {
                return const SizedBox.shrink();
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      state.torchState == TorchState.on
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      color: Colors.amber,
                    ),
                    onPressed: () => unawaited(_controller.toggleTorch()),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cameraswitch_rounded),
                    onPressed: () => unawaited(_controller.switchCamera()),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        errorBuilder: (context, error) {
          if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
            return _buildPermissionView();
          }
          return _buildGenericErrorView(error);
        },
        overlayBuilder: (context, constraints) =>
            _buildScannerOverlay(constraints),
      ),
    );
  }
}
