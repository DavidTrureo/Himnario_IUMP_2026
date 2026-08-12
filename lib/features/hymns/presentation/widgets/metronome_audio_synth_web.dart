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

void playMetronomeTick({required bool soundEnabled, bool accent = false}) {
  if (!soundEnabled) return;
  try {
    final freq = accent ? 2600 : 2200;
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

void startMicrophonePitchDetector(void Function(double frequencyHz) onPitchDetected) {
  try {
    js.context['_onPitchFromJS'] = (dynamic hz) {
      if (hz is num && hz > 30 && hz < 2500) {
        onPitchDetected(hz.toDouble());
      }
    };

    js.context.callMethod('eval', [
      '''
      (function() {
        window._pitchDetectorActive = true;

        if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
          navigator.mediaDevices.getUserMedia({ audio: true }).then(function(stream) {
            if (!window._metroCtx) {
              window._metroCtx = new (window.AudioContext || window.webkitAudioContext)();
            }
            var audioCtx = window._metroCtx;
            if (audioCtx.state === 'suspended') audioCtx.resume();

            var analyser = audioCtx.createAnalyser();
            analyser.fftSize = 2048;
            var source = audioCtx.createMediaStreamSource(stream);
            source.connect(analyser);

            var buf = new Float32Array(2048);

            function autoCorrelate(buf, sampleRate) {
              var SIZE = buf.length;
              var rms = 0;
              for (var i = 0; i < SIZE; i++) {
                var val = buf[i];
                rms += val * val;
              }
              rms = Math.sqrt(rms / SIZE);
              if (rms < 0.015) return -1;

              var r1 = 0, r2 = SIZE - 1, thres = 0.2;
              for (var i = 0; i < SIZE / 2; i++) {
                if (Math.abs(buf[i]) < thres) { r1 = i; break; }
              }
              for (var i = 1; i < SIZE / 2; i++) {
                if (Math.abs(buf[SIZE - i]) < thres) { r2 = SIZE - i; break; }
              }

              buf = buf.slice(r1, r2);
              SIZE = buf.length;

              var c = new Float32Array(SIZE);
              for (var i = 0; i < SIZE; i++) {
                for (var j = 0; j < SIZE - i; j++) {
                  c[i] = c[i] + buf[j] * buf[j + i];
                }
              }

              var d = 0;
              while (c[d] > c[d + 1]) d++;
              var maxval = -1, maxpos = -1;
              for (var i = d; i < SIZE; i++) {
                if (c[i] > maxval) {
                  maxval = c[i];
                  maxpos = i;
                }
              }
              var T0 = maxpos;
              if (T0 <= 0) return -1;

              var x1 = c[T0 - 1], x2 = c[T0], x3 = c[T0 + 1];
              var a = (x1 + x3 - 2 * x2) / 2;
              var b = (x3 - x1) / 2;
              if (a) T0 = T0 - b / (2 * a);

              return sampleRate / T0;
            }

            function updatePitch() {
              if (!window._pitchDetectorActive) return;
              analyser.getFloatTimeDomainData(buf);
              var pitch = autoCorrelate(buf, audioCtx.sampleRate);
              if (pitch > 30 && pitch < 2500) {
                if (window._onPitchFromJS) {
                  window._onPitchFromJS(pitch);
                }
              }
              requestAnimationFrame(updatePitch);
            }
            updatePitch();
          }).catch(function(err) {
            console.log("Mic pitch error: ", err);
          });
        }
      })();
      '''
    ]);
  } catch (_) {}
}

void stopMicrophonePitchDetector() {
  try {
    js.context.callMethod('eval', [
      '''
      (function() {
        window._pitchDetectorActive = false;
      })();
      '''
    ]);
  } catch (_) {}
}
