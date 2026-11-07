"""Genera los sonidos de alarma propios de TaskFlow (síntesis, sin archivos externos).

Uso:  python tool/generate_sounds.py
Salida: android/app/src/main/res/raw/tf_*.wav (mono, 22050 Hz, 16 bits).
Cada sonido está pensado para repetirse en bucle (termina con un silencio corto).
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "android", "app", "src", "main", "res", "raw")


def note(n):
    """Frecuencia de la nota MIDI n."""
    return 440.0 * 2 ** ((n - 69) / 12)


def buf(seconds):
    return [0.0] * int(seconds * RATE)


def add_tone(b, start, dur, freq, amp=0.5, partials=((1, 1.0),), attack=0.005,
             decay=3.0, wave_fn=math.sin, vibrato=0.0):
    i0 = int(start * RATE)
    n = int(dur * RATE)
    for i in range(n):
        if i0 + i >= len(b):
            break
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        # fundido final para evitar clics
        tail = min(1.0, (n - i) / (0.01 * RATE))
        f = freq * (1 + vibrato * math.sin(2 * math.pi * 5 * t))
        s = 0.0
        for mult, a in partials:
            s += a * wave_fn(2 * math.pi * f * mult * t)
        b[i0 + i] += amp * env * tail * s


def soft_square(x):
    # cuadrada suavizada (menos áspera que una cuadrada pura)
    return math.tanh(4 * math.sin(x))


def add_sweep(b, start, dur, f0, f1, amp=0.4):
    i0 = int(start * RATE)
    n = int(dur * RATE)
    phase = 0.0
    for i in range(n):
        if i0 + i >= len(b):
            break
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += 2 * math.pi * f / RATE
        env = math.sin(math.pi * t)
        b[i0 + i] += amp * env * math.sin(phase)


def write(name, b, gain=0.85):
    peak = max(1e-9, max(abs(x) for x in b))
    k = gain / peak
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x * k)) * 32767)) for x in b))
    print(name, os.path.getsize(path) // 1024, "KB")


def amanecer():
    b = buf(4.0)
    seq = [60, 64, 67, 72, 76, 79, 84]
    for i, n in enumerate(seq):
        add_tone(b, i * 0.32, 2.0, note(n), 0.35 + i * 0.05,
                 partials=((1, 1), (2, 0.3), (3, 0.1)), attack=0.03, decay=1.6)
    return b


def campanas():
    b = buf(4.0)
    bell = ((1, 1.0), (2.76, 0.5), (5.4, 0.25), (8.9, 0.12))
    for i, n in enumerate([76, 72, 74, 67, 67, 74, 76, 72]):
        add_tone(b, i * 0.42, 2.2, note(n), 0.5, partials=bell, attack=0.002, decay=2.2)
    return b


def digital():
    b = buf(2.0)
    for burst in (0.0, 1.0):
        for k in range(4):
            add_tone(b, burst + k * 0.13, 0.08, 2093, 0.4, wave_fn=soft_square,
                     attack=0.002, decay=0.0)
    return b


def marimba():
    b = buf(3.6)
    mar = ((1, 1.0), (4, 0.35), (10, 0.05))
    melody = [72, 76, 79, 76, 81, 79, 76, 72, 74, 77, 81, 79]
    for i, n in enumerate(melody):
        add_tone(b, i * 0.25, 0.9, note(n), 0.5, partials=mar, attack=0.002, decay=6)
    return b


def cristal():
    b = buf(4.0)
    rnd = random.Random(7)
    scale = [84, 86, 88, 91, 93, 96]
    for i in range(14):
        n = rnd.choice(scale)
        add_tone(b, i * 0.24 + rnd.random() * 0.05, 1.8, note(n), 0.3,
                 partials=((1, 1), (2.01, 0.4), (3.98, 0.15)), attack=0.002, decay=2.5)
    return b


def pulso():
    b = buf(3.0)
    for i in range(6):
        t = i * 0.5
        add_tone(b, t, 0.25, 110, 0.6 + i * 0.06, partials=((1, 1), (2, 0.5), (3, 0.2)),
                 attack=0.005, decay=9)
        add_tone(b, t + 0.18, 0.25, 98, 0.45 + i * 0.05, partials=((1, 1), (2, 0.5)),
                 attack=0.005, decay=10)
        add_tone(b, t, 0.2, note(81), 0.12, attack=0.002, decay=14)
    return b


def retro():
    b = buf(3.2)
    melody = [72, 76, 79, 84, 79, 76, 72, 76, 74, 77, 81, 86, 81, 77, 74, 79]
    for i, n in enumerate(melody):
        add_tone(b, i * 0.18, 0.16, note(n), 0.3, wave_fn=soft_square, attack=0.003, decay=4)
    return b


def sirena():
    b = buf(3.0)
    add_sweep(b, 0.0, 1.4, 660, 990, 0.5)
    add_sweep(b, 1.4, 1.4, 990, 660, 0.5)
    return b


def pajaros():
    b = buf(3.5)
    rnd = random.Random(3)
    t = 0.0
    while t < 3.0:
        f0 = 2500 + rnd.random() * 1500
        add_sweep(b, t, 0.07, f0, f0 + 1200 * (1 if rnd.random() > 0.4 else -1), 0.35)
        t += 0.09 if rnd.random() > 0.3 else 0.35
    return b


def zen():
    b = buf(6.0)
    add_tone(b, 0.0, 6.0, note(57), 0.6, partials=((1, 1), (2.01, 0.4), (2.99, 0.2), (5.4, 0.08)),
             attack=0.02, decay=0.55)
    add_tone(b, 0.0, 6.0, note(57) * 1.004, 0.4, attack=0.02, decay=0.55)  # batido suave
    return b


def manana():
    b = buf(4.4)
    # acordes suaves que suben: Do - Fa - Sol - Do
    chords = [(60, 64, 67), (65, 69, 72), (67, 71, 74), (72, 76, 79)]
    for i, ch in enumerate(chords):
        for n in ch:
            add_tone(b, i * 1.0, 1.4, note(n), 0.22, partials=((1, 1), (2, 0.25)),
                     attack=0.15, decay=1.1, vibrato=0.002)
    return b


SOUNDS = {
    "tf_amanecer": amanecer,
    "tf_campanas": campanas,
    "tf_digital": digital,
    "tf_marimba": marimba,
    "tf_cristal": cristal,
    "tf_pulso": pulso,
    "tf_retro": retro,
    "tf_sirena": sirena,
    "tf_pajaros": pajaros,
    "tf_zen": zen,
    "tf_manana": manana,
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        write(name, fn())
