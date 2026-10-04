import 'metronome_audio_synth_stub.dart'
    if (dart.library.html) 'metronome_audio_synth_web.dart';

void playAudioTick({required bool soundEnabled, bool accent = false, bool subdivision = false}) {
  playMetronomeTick(soundEnabled: soundEnabled, accent: accent, subdivision: subdivision);
}

void prepareAudioContext() {
  unlockAudioContext();
}

void playTonePitch(double frequency, {double durationSeconds = 1.5}) {
  playMusicalTone(frequency, durationSeconds: durationSeconds);
}
