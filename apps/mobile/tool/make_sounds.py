"""Synthesise the game's sound effects into assets/sounds/*.wav (no recorded or licensed samples).

Run from apps/mobile:  python tool/make_sounds.py
Every sound is short and quiet on purpose (phone speakers, played often).
"""
import math, random, struct, wave

RATE = 44100
random.seed(7)


def env(n, attack, decay):
    """attack/decay in samples: quick rise, exponential fall."""
    out = []
    for i in range(n):
        a = min(1.0, i / max(1, attack))
        out.append(a * math.exp(-i / max(1, decay)))
    return out


def noise_burst(ms, lowpass, gain, attack_ms=2, decay_ms=25, sweep=0.0):
    """Filtered noise: a card sliding / landing. `sweep` moves the filter over time (a swish)."""
    n = int(RATE * ms / 1000)
    e = env(n, int(RATE * attack_ms / 1000), int(RATE * decay_ms / 1000))
    y, out = 0.0, []
    for i in range(n):
        k = lowpass * (1 + sweep * (i / n))
        y += min(1.0, k) * (random.uniform(-1, 1) - y)
        out.append(y * e[i] * gain)
    return out


def tone(freq, ms, gain, attack_ms=4, decay_ms=120, harmonics=((1, 1.0), (2, 0.25), (3, 0.08))):
    n = int(RATE * ms / 1000)
    e = env(n, int(RATE * attack_ms / 1000), int(RATE * decay_ms / 1000))
    return [gain * e[i] * sum(a * math.sin(2 * math.pi * freq * h * i / RATE) for h, a in harmonics) for i in range(n)]


def mix(*parts):
    """parts: (start_ms, samples)"""
    length = max(int(RATE * s / 1000) + len(p) for s, p in parts)
    out = [0.0] * length
    for s, p in parts:
        o = int(RATE * s / 1000)
        for i, v in enumerate(p):
            out[o + i] += v
    return out


def save(name, samples):
    peak = max(1e-9, max(abs(v) for v in samples))
    scale = min(1.0, 0.95 / peak)
    with wave.open(f'assets/sounds/{name}.wav', 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, v * scale)) * 32767 * 0.6)) for v in samples))


# a card thrown on the felt: a short swish, then a soft thud
save('card_throw', mix((0, noise_burst(90, 0.08, 0.9, attack_ms=10, decay_ms=30, sweep=2.0)), (70, noise_burst(60, 0.03, 1.0, decay_ms=18)), (70, tone(140, 60, 0.35, decay_ms=20))))
# dealing: a quick flick
save('deal', mix((0, noise_burst(55, 0.25, 0.8, attack_ms=1, decay_ms=12, sweep=1.0))))
# the trick is gathered: a longer, softer slide
save('collect', mix((0, noise_burst(260, 0.05, 0.7, attack_ms=40, decay_ms=90, sweep=3.0))))
# a card placed on a pile / meld (Trix, Hand)
save('place', mix((0, noise_burst(50, 0.05, 0.9, decay_ms=14)), (0, tone(220, 50, 0.25, decay_ms=15))))
# your turn: a gentle two-note chime
save('turn', mix((0, tone(880, 220, 0.35, decay_ms=90)), (110, tone(1175, 320, 0.3, decay_ms=130))))
# a button press
save('tap', mix((0, noise_burst(18, 0.5, 0.5, attack_ms=1, decay_ms=4)), (0, tone(1600, 25, 0.2, attack_ms=1, decay_ms=8))))
# last seconds of your turn
save('tick', tone(1320, 70, 0.4, attack_ms=1, decay_ms=25, harmonics=((1, 1.0), (3, 0.2))))
# game won: a bright rising arpeggio
save('win', mix(*[(i * 110, tone(f, 420, 0.3, decay_ms=200)) for i, f in enumerate([523, 659, 784, 1047])]))
# game lost: a soft falling phrase
save('lose', mix(*[(i * 160, tone(f, 480, 0.3, decay_ms=220, harmonics=((1, 1.0), (2, 0.15)))) for i, f in enumerate([523, 440, 349])]))
print('ok')
