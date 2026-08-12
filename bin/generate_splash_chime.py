import os
import math
import struct
import wave
import subprocess

os.makedirs('assets/audio', exist_ok=True)

sample_rate = 44100
duration = 3.2 # 3.2 segundos (duración perfecta del splash)
total_samples = int(sample_rate * duration)

# Acorde Dulce y Celestial: Fmaj9 / C (Fa, La, Do, Mi, Sol, Do)
# Sensación de dulzura, paz, calor y solemnidad
notes = [
    (261.63, 0.00, 0.18, 1.2),  # C4 (Graves calientes)
    (349.23, 0.08, 0.22, 1.0),  # F4
    (440.00, 0.16, 0.25, 0.9),  # A4
    (523.25, 0.24, 0.28, 0.8),  # C5
    (659.25, 0.32, 0.30, 0.7),  # E5 (Nota dulcísima)
    (783.99, 0.40, 0.32, 0.6),  # G5
    (1046.50, 0.50, 0.35, 0.5), # C6 (Campanita celestial)
    (1318.51, 0.62, 0.22, 0.4), # E6 (Brillo final suave)
]

audio_data = []

for i in range(total_samples):
    t = i / sample_rate
    sample = 0.0

    for freq, delay, amp, decay_rate in notes:
        if t >= delay:
            dt = t - delay
            # Envolvente ultrasuave: ataque suave de 80ms y decaimiento armónico sedoso
            attack = math.sin(min(math.pi / 2, (dt / 0.08) * (math.pi / 2)))
            decay = math.exp(-decay_rate * dt)
            envelope = attack * decay * amp
            
            # Síntesis dulce de Campana de Cristal / Celesta: Seno Puro + Armónico Cálido
            wave_val = (
                0.82 * math.sin(2 * math.pi * freq * dt) +
                0.15 * math.sin(2 * math.pi * (freq * 2.001) * dt) + # Vibrato sutil
                0.03 * math.sin(2 * math.pi * (freq * 3.0) * dt)
            )
            sample += wave_val * envelope

    # Normalizar suavemente a -3dB para máxima dulzura sin distorsión
    sample = max(-0.9, min(0.9, sample * 0.65))
    packed_value = struct.pack('<h', int(sample * 32767))
    audio_data.append(packed_value)

wav_path = 'assets/audio/splash_chime.wav'
with wave.open(wav_path, 'w') as wav_file:
    wav_file.setnchannels(1)
    wav_file.setsampwidth(2)
    wav_file.setframerate(sample_rate)
    wav_file.writeframes(b''.join(audio_data))

print(f'Generado exitosamente {wav_path}')

# Convertir a mp3
subprocess.run(['ffmpeg', '-i', 'assets/audio/splash_chime.wav', '-b:a', '192k', 'assets/audio/splash_chime.mp3', '-y'])
print('Convertido exitosamente a assets/audio/splash_chime.mp3')
