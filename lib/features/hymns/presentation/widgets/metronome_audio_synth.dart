import 'metronome_audio_synth_stub.dart'
    if (dart.library.html) 'metronome_audio_synth_web.dart';

void playAudioTick({required bool soundEnabled, bool accent = false}) {
  playMetronomeTick(soundEnabled: soundEnabled, accent: accent);
}

void prepareAudioContext() {
  unlockAudioContext();
}

void playTonePitch(double frequency, {double durationSeconds = 1.5}) {
  playMusicalTone(frequency, durationSeconds: durationSeconds);
}

void listenToPitch(void Function(double frequencyHz) onPitchDetected) {
  startMicrophonePitchDetector(onPitchDetected);
}

void stopPitchDetector() {
  stopMicrophonePitchDetector();
}
