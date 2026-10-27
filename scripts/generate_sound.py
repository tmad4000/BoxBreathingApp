#!/usr/bin/env python3
"""Reproduce the app's short, original sound; no third-party recordings."""
import math, pathlib, struct, wave
path = pathlib.Path(__file__).resolve().parents[1] / 'assets/audio/chime.wav'
rate, duration = 44100, 0.35
samples = []
for i in range(int(rate * duration)):
    t = i / rate
    envelope = min(1, t / 0.012) * max(0, 1 - t / duration) ** 2
    value = .4 * envelope * (math.sin(2 * math.pi * 660 * t) + .25 * math.sin(2 * math.pi * 990 * t))
    samples.append(struct.pack('<h', round(32767 * value)))
with wave.open(str(path), 'wb') as output:
    output.setnchannels(1); output.setsampwidth(2); output.setframerate(rate)
    output.writeframes(b''.join(samples))
