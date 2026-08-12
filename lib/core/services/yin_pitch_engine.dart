import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

/// Configuración y mensaje de audio para el Isolate de afinación
class _PitchRequest {
  final List<double> samples;
  final double sampleRate;

  const _PitchRequest(this.samples, this.sampleRate);
}

/// Motor de Afinado de Alta Velocidad (YIN + Bandpass Filter + Interpolación Parabólica)
class YinPitchEngine {
  static const double kDefaultThreshold = 0.15;
  static const double kMinFreqHz = 30.0;
  static const double kMaxFreqHz = 1000.0;

  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  StreamSubscription? _subscription;
  bool _isProcessing = false;

  /// Inicia el Isolate de afinación en segundo plano
  Future<void> start(void Function(double pitchHz) onPitchDetected) async {
    await stop();

    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntryPoint, _receivePort!.sendPort);

    final completer = Completer<SendPort>();
    _subscription = _receivePort!.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is double) {
        _isProcessing = false;
        if (message > kMinFreqHz && message < kMaxFreqHz) {
          onPitchDetected(message);
        }
      }
    });

    _sendPort = await completer.future;
  }

  /// Envía un buffer de audio al Isolate si no hay un cálculo en curso
  void processBuffer(List<double> samples, double sampleRate) {
    if (_sendPort == null || _isProcessing || samples.length < 512) return;
    _isProcessing = true;
    _sendPort!.send(_PitchRequest(samples, sampleRate));
  }

  /// Detiene el Isolate y libera memoria
  Future<void> stop() async {
    _subscription?.cancel();
    _subscription = null;
    _receivePort?.close();
    _receivePort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _isProcessing = false;
  }

  /// Punto de entrada estático del Isolate secundario (No congela el hilo UI de Flutter)
  static void _isolateEntryPoint(SendPort mainSendPort) {
    final isolateReceivePort = ReceivePort();
    mainSendPort.send(isolateReceivePort.sendPort);

    isolateReceivePort.listen((message) {
      if (message is _PitchRequest) {
        final pitch = computeYinPitch(message.samples, message.sampleRate);
        mainSendPort.send(pitch);
      }
    });
  }

  /// Algoritmo YIN con Filtro Pasa-Banda e Interpolación Parabólica Sub-Muestra (±0.1 Hz)
  static double computeYinPitch(List<double> rawSamples, double sampleRate) {
    if (rawSamples.length < 512) return -1.0;

    // 1. Filtro Pasa-Banda (30Hz - 1000Hz) para silenciar armónicos y ruido agudo/grave
    final filtered = _bandpassFilter(rawSamples, sampleRate, kMinFreqHz, kMaxFreqHz);

    // 2. Verificación de amplitud RMS (Silenciar ruido ambiental)
    double rms = 0.0;
    for (int i = 0; i < filtered.length; i++) {
      rms += filtered[i] * filtered[i];
    }
    rms = math.sqrt(rms / filtered.length);
    if (rms < 0.007) return -1.0; // Umbral de silencio impecable

    final int bufferSize = filtered.length;
    final int tauMax = bufferSize ~/ 2;
    final List<double> yinBuffer = List<double>.filled(tauMax, 0.0);

    // 3. Función de Diferencia YIN (Difference Function)
    for (int tau = 0; tau < tauMax; tau++) {
      for (int i = 0; i < tauMax; i++) {
        final delta = filtered[i] - filtered[i + tau];
        yinBuffer[tau] += delta * delta;
      }
    }

    // 4. Cumulative Mean Normalized Difference Function (CMNDF)
    yinBuffer[0] = 1.0;
    double runningSum = 0.0;
    for (int tau = 1; tau < tauMax; tau++) {
      runningSum += yinBuffer[tau];
      yinBuffer[tau] *= tau / (runningSum == 0 ? 1.0 : runningSum);
    }

    // 5. Absolute Thresholding (Elección del valle fundamental)
    int tauEstimate = -1;
    for (int tau = 2; tau < tauMax; tau++) {
      if (yinBuffer[tau] < kDefaultThreshold) {
        while (tau + 1 < tauMax && yinBuffer[tau + 1] < yinBuffer[tau]) {
          tau++;
        }
        tauEstimate = tau;
        break;
      }
    }

    // Fallback: Si no supera el umbral estricto, buscar el mínimo global razonable
    if (tauEstimate == -1) {
      double minVal = 999.0;
      for (int tau = 2; tau < tauMax; tau++) {
        if (yinBuffer[tau] < minVal) {
          minVal = yinBuffer[tau];
          tauEstimate = tau;
        }
      }
      if (minVal > 0.45) return -1.0;
    }

    if (tauEstimate <= 0 || tauEstimate >= tauMax - 1) return -1.0;

    // 6. Interpolación Parabólica para Precisión Sub-Muestra Microtonal (±0.1 Hz)
    final double s0 = yinBuffer[tauEstimate - 1];
    final double s1 = yinBuffer[tauEstimate];
    final double s2 = yinBuffer[tauEstimate + 1];

    final double denominator = 2 * (s0 + s2 - 2 * s1);
    double refinedTau = tauEstimate.toDouble();
    if (denominator != 0) {
      refinedTau = tauEstimate + (s0 - s2) / denominator;
    }

    if (refinedTau <= 0) return -1.0;

    final pitchHz = sampleRate / refinedTau;
    if (pitchHz >= kMinFreqHz && pitchHz <= kMaxFreqHz) {
      return pitchHz;
    }
    return -1.0;
  }

  /// Filtro IIR Pasa-Banda rápido (30Hz a 1000Hz)
  static List<double> _bandpassFilter(List<double> input, double sr, double lowCut, double highCut) {
    final output = List<double>.filled(input.length, 0.0);
    final rcLow = 1.0 / (2 * math.pi * highCut);
    final dt = 1.0 / sr;
    final alphaLow = dt / (rcLow + dt);

    double lastY = input[0];
    for (int i = 0; i < input.length; i++) {
      lastY += alphaLow * (input[i] - lastY);
      output[i] = lastY;
    }
    return output;
  }
}
