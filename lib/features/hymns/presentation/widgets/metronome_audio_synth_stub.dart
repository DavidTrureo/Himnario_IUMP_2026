import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_streamer/audio_streamer.dart';
import '../../../../core/services/yin_pitch_engine.dart';

AudioPlayer? _nativePlayer;
AudioPlayer? _nativeTonePlayer;
StreamSubscription<List<double>>? _audioStreamSub;

Uint8List _generateClaveWavBytes({required double frequency, required double durationSeconds, double sampleRate = 22050}) {
  final numSamples = (durationSeconds * sampleRate).toInt();
  final dataSize = numSamples * 2;
  final fileSize = 36 + dataSize;
  
  final bytes = ByteData(8 + fileSize);
  
  bytes.setUint8(0, 0x52); bytes.setUint8(1, 0x49); bytes.setUint8(2, 0x46); bytes.setUint8(3, 0x46);
  bytes.setUint32(4, fileSize, Endian.little);
  bytes.setUint8(8, 0x57); bytes.setUint8(9, 0x41); bytes.setUint8(10, 0x56); bytes.setUint8(11, 0x45);
  
  bytes.setUint8(12, 0x66); bytes.setUint8(13, 0x6D); bytes.setUint8(14, 0x74); bytes.setUint8(15, 0x20);
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate.toInt(), Endian.little);
  bytes.setUint32(28, (sampleRate * 2).toInt(), Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  
  bytes.setUint8(36, 0x64); bytes.setUint8(37, 0x61); bytes.setUint8(38, 0x74); bytes.setUint8(39, 0x61);
  bytes.setUint32(40, dataSize, Endian.little);
  
  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    final env = math.exp(-t * 90.0);
    final fadeOut = (1.0 - (i / numSamples)).clamp(0.0, 1.0);
    final sample = (math.sin(2 * math.pi * frequency * t) * 32767 * env * fadeOut).toInt();
    bytes.setInt16(44 + i * 2, sample.clamp(-32768, 32767), Endian.little);
  }
  
  return bytes.buffer.asUint8List();
}

Uint8List _generateAcousticToneWavBytes({required double frequency, required double durationSeconds, double sampleRate = 22050}) {
  final numSamples = (durationSeconds * sampleRate).toInt();
  final dataSize = numSamples * 2;
  final fileSize = 36 + dataSize;
  
  final bytes = ByteData(8 + fileSize);
  
  bytes.setUint8(0, 0x52); bytes.setUint8(1, 0x49); bytes.setUint8(2, 0x46); bytes.setUint8(3, 0x46);
  bytes.setUint32(4, fileSize, Endian.little);
  bytes.setUint8(8, 0x57); bytes.setUint8(9, 0x41); bytes.setUint8(10, 0x56); bytes.setUint8(11, 0x45);
  
  bytes.setUint8(12, 0x66); bytes.setUint8(13, 0x6D); bytes.setUint8(14, 0x74); bytes.setUint8(15, 0x20);
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate.toInt(), Endian.little);
  bytes.setUint32(28, (sampleRate * 2).toInt(), Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  
  bytes.setUint8(36, 0x64); bytes.setUint8(37, 0x61); bytes.setUint8(38, 0x74); bytes.setUint8(39, 0x61);
  bytes.setUint32(40, dataSize, Endian.little);
  
  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    final env = math.exp(-t * 1.8);
    final fadeOut = (1.0 - (i / numSamples)).clamp(0.0, 1.0);
    final wave = (math.sin(2 * math.pi * frequency * t) * 0.5) +
                 (math.sin(2 * math.pi * frequency * 2 * t) * 0.3) +
                 (math.sin(2 * math.pi * frequency * 3 * t) * 0.2);
    final sample = (wave * 32767 * env * fadeOut).toInt();
    bytes.setInt16(44 + i * 2, sample.clamp(-32768, 32767), Endian.little);
  }
  
  return bytes.buffer.asUint8List();
}

void playMetronomeTick({required bool soundEnabled, bool accent = false}) async {
  if (!soundEnabled) return;
  try {
    _nativePlayer ??= AudioPlayer();
    final freq = accent ? 2600.0 : 2200.0;
    final wavBytes = _generateClaveWavBytes(frequency: freq, durationSeconds: 0.04);
    final base64Wav = base64Encode(wavBytes);
    final dataUrl = 'data:audio/wav;base64,$base64Wav';
    
    await _nativePlayer!.stop();
    await _nativePlayer!.setAudioSource(AudioSource.uri(Uri.parse(dataUrl)));
    _nativePlayer!.play();
  } catch (_) {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }
}

void unlockAudioContext() {}

void playMusicalTone(double frequency, {double durationSeconds = 1.5}) async {
  try {
    _nativeTonePlayer ??= AudioPlayer();
    final wavBytes = _generateAcousticToneWavBytes(frequency: frequency, durationSeconds: durationSeconds);
    final base64Wav = base64Encode(wavBytes);
    final dataUrl = 'data:audio/wav;base64,$base64Wav';
    
    await _nativeTonePlayer!.setAudioSource(AudioSource.uri(Uri.parse(dataUrl)));
    _nativeTonePlayer!.play();
  } catch (_) {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }
}

// Algoritmo de Autocorrelación Preciso Estándar para Instrumentos
double _autoCorrelateFloat(List<double> samples, int sampleRate) {
  if (samples.length < 256) return -1.0;
  final numSamples = samples.length;

  double rms = 0;
  for (int i = 0; i < numSamples; i++) {
    final val = samples[i];
    rms += val * val;
  }
  rms = math.sqrt(rms / numSamples);
  if (rms < 0.005) return -1.0; // Umbral de silencio bajo

  int size = numSamples;
  int r1 = 0, r2 = size - 1;
  const thres = 0.2;
  for (int i = 0; i < size ~/ 2; i++) {
    if (samples[i].abs() < thres) { r1 = i; break; }
  }
  for (int i = 1; i < size ~/ 2; i++) {
    if (samples[size - i].abs() < thres) { r2 = size - i; break; }
  }

  final sliced = samples.sublist(r1, r2);
  size = sliced.length;
  if (size < 60) return -1.0;

  final c = Float32List(size);
  for (int i = 0; i < size; i++) {
    for (int j = 0; j < size - i; j++) {
      c[i] = c[i] + sliced[j] * sliced[j + i];
    }
  }

  int d = 0;
  while (d < size - 1 && c[d] > c[d + 1]) {
    d++;
  }
  double maxval = -1;
  int maxpos = -1;
  for (int i = d; i < size; i++) {
    if (c[i] > maxval) {
      maxval = c[i];
      maxpos = i;
    }
  }

  int t0 = maxpos;
  if (t0 <= 0 || t0 >= size - 1) return -1.0;

  final x1 = c[t0 - 1], x2 = c[t0], x3 = c[t0 + 1];
  final a = (x1 + x3 - 2 * x2) / 2;
  final b = (x3 - x1) / 2;
  double refinedT0 = t0.toDouble();
  if (a != 0) refinedT0 = t0 - b / (2 * a);

  return sampleRate / refinedT0;
}

YinPitchEngine? _yinPitchEngine;

void startMicrophonePitchDetector(void Function(double frequencyHz) onPitchDetected) async {
  try {
    stopMicrophonePitchDetector();
    _yinPitchEngine = YinPitchEngine();
    await _yinPitchEngine!.start(onPitchDetected);

    final streamer = AudioStreamer();
    _audioStreamSub = streamer.audioStream.listen((buffer) {
      final sampleRate = (streamer.sampleRate ?? 44100).toDouble();
      _yinPitchEngine?.processBuffer(buffer, sampleRate);
    }, onError: (_) {
      stopMicrophonePitchDetector();
    });
  } catch (_) {}
}

void stopMicrophonePitchDetector() {
  try {
    _audioStreamSub?.cancel();
    _audioStreamSub = null;
    _yinPitchEngine?.stop();
    _yinPitchEngine = null;
  } catch (_) {}
}
