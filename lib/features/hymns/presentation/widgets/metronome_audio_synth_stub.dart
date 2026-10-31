import 'package:flutter/services.dart';

void playMetronomeTick({required bool soundEnabled, bool accent = false, bool subdivision = false}) {
  if (!soundEnabled) return;
  try {
    SystemSound.play(SystemSoundType.click);
  } catch (_) {}
}

void unlockAudioContext() {}

void playMusicalTone(double frequency, {double durationSeconds = 1.5}) {
  try {
    SystemSound.play(SystemSoundType.click);
  } catch (_) {}
}
