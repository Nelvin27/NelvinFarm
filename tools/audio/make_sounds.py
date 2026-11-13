#!/usr/bin/env python3
"""Synthesizes all of Clover Patch's sound effects as 16-bit mono WAV files: soft mallet tones and noise bursts.

    python3 tools/audio/make_sounds.py

Writes into Clover-Patch-3D/assets/audio/. Deterministic: the same script gives the same files.
"""
import math, os, random, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Clover-Patch-3D", "assets", "audio")
rng = random.Random(7)


def save(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s / peak * 0.8)) * 32767)) for s in samples))


def noise(n, smooth):
    """Low-passed white noise; higher `smooth` is duller."""
    out, y = [], 0.0
    for _ in range(n):
        y += (rng.uniform(-1, 1) - y) / smooth
        out.append(y)
    return out


def rustle():
    n = int(RATE * 0.42)
    hiss = noise(n, 2.2)
    out = []
    for i in range(n):
        t = i / RATE
        shake = 0.55 + 0.45 * math.sin(t * 2 * math.pi * 11)       # leaves brushing back and forth
        out.append(hiss[i] * shake * math.exp(-t * 6.5) * min(1, t * 90))
    return out


def bell():
    n = int(RATE * 1.9)
    partials = [(523.25, 1.0, 2.2), (1046.5, 0.5, 3.0), (1414.0, 0.32, 4.2), (2093.0, 0.2, 5.5), (2794.0, 0.1, 7.0)]
    return [sum(a * math.exp(-t * d) * math.sin(2 * math.pi * f * t) for f, a, d in partials) * min(1, t * 400)
            for t in (i / RATE for i in range(n))]


def splash():
    n = int(RATE * 0.5)
    spray = noise(n, 3.5)
    out = []
    for i in range(n):
        t = i / RATE
        plop = math.sin(2 * math.pi * (260 * math.exp(-t * 9) + 70) * t) * math.exp(-t * 14)
        out.append(plop * 0.9 + spray[i] * math.exp(-t * 9) * min(1, t * 60) * 0.8)
    return out


def quack():
    out = []
    for start, length, pitch in ((0.0, 0.13, 430), (0.17, 0.16, 400)):
        out += [0.0] * (int(start * RATE) - len(out))
        n = int(length * RATE)
        for i in range(n):
            t = i / RATE
            f = pitch * (1.12 - 0.3 * t / length)
            saw = 2 * ((f * t) % 1) - 1
            nasal = math.sin(2 * math.pi * 1250 * t) * 0.35
            env = math.sin(math.pi * i / n) ** 0.6
            out.append((saw * 0.7 + nasal * saw) * env)
    return out


def chime():
    notes = [(0.0, 659.25), (0.09, 783.99), (0.18, 987.77), (0.3, 1318.5)]
    n = int(RATE * 1.1)
    out = [0.0] * n
    for start, f in notes:
        for i in range(int(start * RATE), n):
            t = i / RATE - start
            out[i] += math.exp(-t * 5.2) * (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(4 * math.pi * f * t)) * min(1, t * 300)
    return out


# --- Soft effects: marimba-like notes, short noise bursts, and little jingles. ---------------------------
def blip(notes, duty=0.5, decay=14.0, gap=0.0):
    """notes: (frequency, seconds) pairs played one after another; a tuple of two frequencies slides."""
    out = []
    for f, length in notes:
        n = int(length * RATE)
        phase = 0.0
        for i in range(n):
            t = i / RATE
            now = f[0] + (f[1] - f[0]) * i / n if isinstance(f, tuple) else f
            phase += now / RATE
            w = 2 * math.pi * phase
            # A struck wooden or glass bar: a pure tone with a bright overtone that dies quickly.
            tone = math.sin(w) + duty * 0.5 * math.sin(2 * w) + 0.35 * math.sin(4 * w) * math.exp(-t * 30)
            out.append(tone * math.exp(-t * decay) * min(1, t * 400))
        out += [0.0] * int(gap * RATE)
    return out


def burst(length, smooth, decay, volume=1.0):
    n = int(length * RATE)
    hiss = noise(n, smooth)
    return [hiss[i] * math.exp(-i / RATE * decay) * min(1, i / RATE * 300) * volume for i in range(n)]


def mix(*parts):
    """Each part is (start seconds, samples)."""
    out = [0.0] * max(int(start * RATE) + len(samples) for start, samples in parts)
    for start, samples in parts:
        first = int(start * RATE)
        for i, sample in enumerate(samples):
            out[first + i] += sample
    return out


C5, D5, E5, G5, A5, B5, C6, D6, E6, G6, C7 = 523.25, 587.33, 659.25, 783.99, 880.0, 987.77, 1046.5, 1174.66, 1318.5, 1567.98, 2093.0

EFFECTS = {
    "step_grass": lambda: burst(0.09, 2.6, 38, 1.0),
    "step_wood": lambda: mix((0, blip([((210, 120), 0.07)], decay=40)), (0, burst(0.03, 1.3, 90, 0.5))),
    "till": lambda: mix((0, burst(0.2, 2.0, 16)), (0, blip([((170, 70), 0.16)], decay=18))),
    "plant": lambda: blip([((330, 520), 0.07), ((520, 780), 0.09)], decay=16),
    "water": lambda: mix(*[(0.05 * drop, burst(0.16, 1.5 + (drop % 3) * 0.5, 22, 0.7)) for drop in range(8)],
                         (0.02, blip([((900, 500), 0.1), ((1100, 600), 0.1), ((800, 450), 0.12)], decay=20))),
    "harvest": lambda: blip([(E5, 0.06), (G5, 0.06), (C6, 0.06), (E6, 0.22)], duty=0.25, decay=9),
    "menu": lambda: blip([(A5, 0.035), (E6, 0.07)], duty=0.25, decay=22),
    "sleep": lambda: blip([(G5, 0.3), (E5, 0.3), (C5, 0.3), (D5, 0.3), (C5, 0.9)], duty=0.5, decay=3.2),
    "eat": lambda: mix(*[(0.14 * bite, mix((0, burst(0.08, 1.8, 30)), (0, blip([((300, 200), 0.07)], decay=30))))
                         for bite in range(3)]),
    "trade": lambda: blip([(B5, 0.07), (E6, 0.4)], duty=0.25, decay=7),
    "fishing_cast": lambda: mix((0, [s * min(1, i / (RATE * 0.12)) for i, s in enumerate(burst(0.22, 1.4, 9, 0.7))]),
                                (0.2, blip([((420, 160), 0.14)], decay=16))),
    "fishing_bite": lambda: blip([(C7, 0.05), (C7, 0.05), (C7, 0.12)], duty=0.25, decay=14, gap=0.04),
    "fishing_catch": lambda: blip([(C6, 0.08), (E6, 0.08), (G6, 0.08), (C7, 0.4)], duty=0.25, decay=6),
    "fruit_pluck": lambda: blip([((700, 380), 0.05), ((500, 900), 0.08)], decay=20),
    "rustle": rustle, "bell": bell, "splash": splash, "quack": quack, "chime": chime,
}

for name, make in EFFECTS.items():
    save(name, make())
    print("wrote", name + ".wav")
