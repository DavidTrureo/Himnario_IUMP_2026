import os
import math
import struct
import wave
import subprocess

os.makedirs('assets/audio', exist_ok=True)

sample_rate = 44100
duration = 3.2 # 3.2 segundos exactos
total_samples = int(sample_rate * duration)

# 1. Notas del Arpegio Celestial Dulce (Cmaj9: C5, E5, G5, B5, E6, G6, C7)
arpeggio_notes = [
    (523.25,  0.00, 0.45), # C5
    (659.25,  0.14, 0.40), # E5
    (783.99,  0.28, 0.38), # G5
    (987.77,  0.42, 0.35), # B5 (Dulcisimo)
    (1318.51, 0.56, 0.32), # E6
    (1567.98, 0.70, 0.28), # G6
    (2093.00, 0.85, 0.22), # C7 (Destello cristalino)
]

# 2. Acorde Cálido de Fondo (Pad Celestial Suave)
pad_notes = [
    (261.63, 0.30), # C4
    (392.00, 0.25), # G4
    (659.25, 0.20), # E5
]

audio_samples = []

for i in range(total_samples):
    t = i / sample_rate
    sample = 0.0

    # A) Generar Pad Cálido Celestial de Fondo
    for freq, amp in pad_notes:
        # Envolvente ultrasuave para el pad: Entrada en 0.4s, salida progresiva
        pad_attack = math.sin(min(math.pi / 2, (t / 0.4) * (math.pi / 2))) if t < 0.4 else 1.0
        pad_decay = math.exp(-1.1 * t)
        pad_env = pad_attack * pad_decay * amp * 0.25
        # Senos puros con tremolo fino (4Hz)
        tremolo = 1.0 + 0.08 * math.sin(2 * math.pi * 4.0 * t)
        sample += math.sin(2 * math.pi * freq * t) * pad_env * tremolo

    # B) Generar Campanas Tubulares / Celesta Cristalina (Física Acústica Real)
    # Ratios de parciales armónicos de campana metálica de cristal: 1.0, 2.756, 5.404
    for freq, delay, amp in arpeggio_notes:
        if t >= delay:
            dt = t - delay
            # Envolvente de campana cristalina: Ataque inmediato (4ms) y decaimiento armónico exponencial
            attack = dt / 0.004 if dt < 0.004 else 1.0
            decay = math.exp(-2.2 * dt)
            env = attack * decay * amp

            # Múltiples armónicos puros para lograr el tono cristalino, dulce y claro
            partial1 = math.sin(2 * math.pi * freq * dt)
            partial2 = 0.22 * math.sin(2 * math.pi * (freq * 2.756) * dt) * math.exp(-4.0 * dt)
            partial3 = 0.08 * math.sin(2 * math.pi * (freq * 5.404) * dt) * math.exp(-7.0 * dt)

            bell_sound = (partial1 + partial2 + partial3) * env
            sample += bell_sound * 0.55

    # C) Fade Out Progresivo Garantizado (Evita cualquier corte o sonido tosco al final)
    if t > 2.0:
        fade_out = max(0.0, 1.0 - (t - 2.0) / 1.2)
        # Aplicar curva suave cuadrática al desvanecimiento
        sample *= (fade_out * fade_out)

    # Limitar de forma limpia entre -0.9 y +0.9
    sample = max(-0.85, min(0.85, sample))
    audio_samples.append(struct.pack('<h', int(sample * 32767)))

wav_path = 'assets/audio/splash_chime_sweet.wav'
with wave.open(wav_path, 'w') as wav_file:
    wav_file.setnchannels(1)
    wav_file.setsampwidth(2)
    wav_file.setframerate(sample_rate)
    wav_file.writeframes(b''.join(audio_samples))

print(f"Generado {wav_path}")

# Convertir a MP3 de alta calidad (192kbps) con filtro afade de ffmpeg
mp3_path = 'assets/audio/splash_chime.mp3'
cmd = [
    'ffmpeg', '-y',
    '-i', wav_path,
    '-af', 'afade=t=out:st=2.0:d=1.2',
    '-b:a', '192k',
    mp3_path
]
subprocess.run(cmd)
print(f"Convertido exitosamente con desvanecimiento sedoso a {mp3_path}")
