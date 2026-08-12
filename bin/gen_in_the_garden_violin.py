import wave
import struct
import math
import random
import os
import subprocess

sr = 44100

def note_freq(name):
    notes = {'C':-9, 'C#':-8, 'Db':-8, 'D':-7, 'D#':-6, 'Eb':-6, 'E':-5, 'F':-4, 'F#':-3, 'Gb':-3,
             'G':-2, 'G#':-1, 'Ab':-1, 'A':0, 'A#':1, 'Bb':1, 'B':2}
    pitch = name[:-1]
    octave = int(name[-1])
    semitones = notes[pitch] + (octave - 4) * 12
    return 440.0 * (2.0 ** (semitones / 12.0))

# Chorus melody of "In The Garden" (En el Jardín / A solas al huerto yo voy):
# "Y Él ca-mi-na con-mi-go, y ha-bla con-mi-go, y me di-ce que su-yo soy..."
melody = [
    ("F#4", 0.42), ("F#4", 0.42), ("G4", 0.42), ("A4", 0.84), ("F#4", 0.42),
    ("E4", 0.42),  ("E4", 0.42),  ("F#4", 0.42), ("G4", 0.84), ("E4", 0.42),
    ("D4", 0.40),  ("E4", 0.40),  ("F#4", 0.40), ("G4", 0.40), ("A4", 0.60), ("B4", 0.60),
    ("A4", 1.30),
]

total_duration = sum(d for _, d in melody) + 1.2
total_samples = int(sr * total_duration)
samples = [0.0] * total_samples

current_sample = 0
for note, dur in melody:
    freq = note_freq(note)
    dur_samples = int(sr * (dur + 0.08)) # Legato bow transition
    
    for i in range(dur_samples):
        t = i / sr
        
        # Vibrato acústico de violín (5.5 Hz con entrada sutil)
        vibrato_fade = min(max((t - 0.10) / 0.20, 0.0), 1.0)
        f_mod = freq * (1.0 + 0.007 * vibrato_fade * math.sin(2.0 * math.pi * 5.5 * t))
        
        phase = 2.0 * math.pi * f_mod * t
        
        # Armónicos ricos de violín de madera acústico
        val = (
            1.00 * math.sin(phase) +
            0.60 * math.sin(2.0 * phase) +
            0.40 * math.sin(3.0 * phase) +
            0.25 * math.sin(4.0 * phase) +
            0.15 * math.sin(5.0 * phase) +
            0.08 * math.sin(6.0 * phase)
        )
        
        # Ruido de fricción del arco de cerda sobre cuerda de acero
        val += (random.random() * 2.0 - 1.0) * 0.015
        
        # Envolvente del frotado de arco (Ataque sutil, sustain, release)
        attack_len = 0.07
        release_len = 0.10
        if t < attack_len:
            env = math.sin((t / attack_len) * (math.pi / 2.0))
        elif t > (dur + 0.08 - release_len):
            rem = (dur + 0.08 - t) / release_len
            env = math.sin(max(rem, 0.0) * (math.pi / 2.0))
        else:
            env = 1.0
            
        target_idx = current_sample + i
        if target_idx < total_samples:
            samples[target_idx] += val * env

    current_sample += int(sr * dur)

# Simulación de Reverberación de Sala Acústica
delay1 = int(sr * 0.040)
delay2 = int(sr * 0.085)
reverb_samples = list(samples)
for i in range(total_samples):
    if i >= delay1:
        reverb_samples[i] += samples[i - delay1] * 0.32
    if i >= delay2:
        reverb_samples[i] += samples[i - delay2] * 0.18

# Fade out final
fade_samples = int(sr * 1.4)
for i in range(total_samples):
    if i >= total_samples - fade_samples:
        factor = (total_samples - i) / fade_samples
        reverb_samples[i] *= factor

# Normalización
max_val = max(abs(x) for x in reverb_samples) or 1.0
norm_samples = [x / max_val * 0.85 for x in reverb_samples]

# Escribir archivo WAV
wav_path = "assets/audio/in_the_garden_violin.wav"
with wave.open(wav_path, "w") as wav_file:
    wav_file.setnchannels(1)
    wav_file.setsampwidth(2)
    wav_file.setframerate(sr)
    for s in norm_samples:
        val_int = int(s * 32767.0)
        val_int = max(-32768, min(32767, val_int))
        wav_file.writeframes(struct.pack("<h", val_int))

print("WAV generado exitosamente:", wav_path)
