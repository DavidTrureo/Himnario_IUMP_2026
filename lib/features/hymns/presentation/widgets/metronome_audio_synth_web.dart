// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void unlockAudioContext() {
  try {
    js.context.callMethod('eval', [
      '''
      (function() {
        try {
          if (!window._metroCtx) {
            window._metroCtx = new (window.AudioContext || window.webkitAudioContext)();
          }
          if (window._metroCtx.state === 'suspended') {
            window._metroCtx.resume();
          }
        } catch(e) {}
      })();
      '''
    ]);
  } catch (_) {}
}

void playMetronomeTick({required bool soundEnabled, bool accent = false, bool subdivision = false}) {
  if (!soundEnabled) return;
  try {
    int freq = 2200;
    if (accent) freq = 2600;
    if (subdivision) freq = 1200;

    js.context.callMethod('eval', [
      '''
      (function() {
        try {
          if (!window._metroCtx) {
            window._metroCtx = new (window.AudioContext || window.webkitAudioContext)();
          }
          if (window._metroCtx.state === 'suspended') {
            window._metroCtx.resume();
          }
          var osc = window._metroCtx.createOscillator();
          var gain = window._metroCtx.createGain();
          osc.type = 'sine';
          osc.frequency.value = $freq;
          var now = window._metroCtx.currentTime;
          gain.gain.setValueAtTime(0.0, now);
          gain.gain.linearRampToValueAtTime(0.9, now + 0.001);
          gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.038);
          gain.gain.setValueAtTime(0.0, now + 0.04);
          osc.connect(gain);
          gain.connect(window._metroCtx.destination);
          osc.start(now);
          osc.stop(now + 0.04);
        } catch(e) {}
      })();
      '''
    ]);
  } catch (_) {}
}

void playMusicalTone(double frequency, {double durationSeconds = 1.5}) {
  try {
    js.context.callMethod('eval', [
      '''
      (function() {
        try {
          if (!window._metroCtx) {
            window._metroCtx = new (window.AudioContext || window.webkitAudioContext)();
          }
          if (window._metroCtx.state === 'suspended') {
            window._metroCtx.resume();
          }
          var now = window._metroCtx.currentTime;
          var freqs = [$frequency, $frequency * 2, $frequency * 3];
          var gains = [0.5, 0.3, 0.2];
          
          freqs.forEach(function(f, idx) {
            var osc = window._metroCtx.createOscillator();
            var g = window._metroCtx.createGain();
            osc.type = 'triangle';
            osc.frequency.value = f;
            g.gain.setValueAtTime(0.0, now);
            g.gain.linearRampToValueAtTime(gains[idx], now + 0.01);
            g.gain.exponentialRampToValueAtTime(0.0001, now + $durationSeconds);
            g.gain.setValueAtTime(0.0, now + $durationSeconds + 0.01);
            osc.connect(g);
            g.connect(window._metroCtx.destination);
            osc.start(now);
            osc.stop(now + $durationSeconds + 0.01);
          });
        } catch(e) {}
      })();
      '''
    ]);
  } catch (_) {}
}
