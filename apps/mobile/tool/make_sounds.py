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


def tone_glide(f0, f1, ms, gain, attack_ms=3, decay_ms=120):
    """A tone whose pitch slides from f0 to f1 over its length (a bend)."""
    n = int(RATE * ms / 1000)
    e = env(n, int(RATE * attack_ms / 1000), int(RATE * decay_ms / 1000))
    out, phase = [], 0.0
    for i in range(n):
        phase += 2 * math.pi * (f0 + (f1 - f0) * (i / n)) / RATE
        out.append(gain * e[i] * math.sin(phase))
    return out


def tone_wobble(freq, wobble_hz, wobble_depth, ms, gain, attack_ms=4, decay_ms=150):
    """A tone with vibrato: its pitch oscillates by +-wobble_depth, wobble_hz times a second."""
    n = int(RATE * ms / 1000)
    e = env(n, int(RATE * attack_ms / 1000), int(RATE * decay_ms / 1000))
    out, phase = [], 0.0
    for i in range(n):
        f = freq + wobble_depth * math.sin(2 * math.pi * wobble_hz * i / RATE)
        phase += 2 * math.pi * f / RATE
        out.append(gain * e[i] * math.sin(phase))
    return out


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

# the mascot's emotes (lib/widgets/emote_face.dart, lib/services/store.dart): one little sting per expression,
# played when the emote lands in the table's chat (lib/services/sound.dart's playEmote)
save('emote_laugh', mix(*[(i * 70, tone(f, 90, 0.4, decay_ms=40)) for i, f in enumerate([520, 620, 760])]))  # يضحك: a bouncy heh-heh-heh
save('emote_wink', mix((0, noise_burst(10, 0.6, 0.4, attack_ms=1, decay_ms=3)), (15, tone(1000, 90, 0.3, attack_ms=2, decay_ms=40))))  # يغمز: a little click-blip
save('emote_shock', mix((0, noise_burst(25, 0.5, 0.7, attack_ms=1, decay_ms=8)), (0, tone(300, 140, 0.35, attack_ms=1, decay_ms=50, harmonics=((1, 1.0), (1.9, 0.5))))))  # مصدوم: a sudden stab
save('emote_cry', tone_glide(520, 300, 420, 0.3, attack_ms=20, decay_ms=250))  # يبكي: a sagging whimper
save('emote_sleep', tone_wobble(260, 5, 15, 480, 0.25, attack_ms=60, decay_ms=300))  # نعسان: a slow, soft hum
save('emote_think', mix((0, tone_glide(500, 700, 160, 0.3, decay_ms=80)), (170, tone(650, 90, 0.2, decay_ms=50))))  # يفكّر: a curious rise then a settle
save('emote_nervous', mix(*[(i * 35, tone(f, 45, 0.25, attack_ms=1, decay_ms=15)) for i, f in enumerate([700, 500, 700, 500, 700, 500])]))  # متوتر: a jittery trill
save('emote_angry', mix((0, noise_burst(130, 0.35, 0.6, attack_ms=2, decay_ms=40)), (0, tone(150, 150, 0.4, attack_ms=2, decay_ms=50, harmonics=((1, 1.0), (2, 0.6), (3, 0.4))))))  # معصّب: a harsh buzz
save('emote_tease', tone_glide(500, 850, 110, 0.3, decay_ms=60) + tone_glide(850, 600, 90, 0.25, decay_ms=50))  # يمزح: a playful boop-boop
save('emote_cool', mix((0, tone(440, 160, 0.3, decay_ms=70)), (90, tone(660, 180, 0.25, decay_ms=90))))  # واثق: a smooth, confident chime
save('emote_love', mix(*[(i * 60, tone(f, 160, 0.28, decay_ms=90)) for i, f in enumerate([523, 659, 784])]))  # معجب: a sweet little flourish
save('emote_star', mix(*[(i * 50, tone(f, 150, 0.3, decay_ms=100, harmonics=((1, 1.0), (2, 0.4), (4, 0.15)))) for i, f in enumerate([659, 880, 1175])]))  # مبهور: a bright ta-da
save('emote_sad', mix((0, tone(440, 200, 0.28, decay_ms=100)), (160, tone(349, 260, 0.26, decay_ms=150))))  # حزين: a soft two-note fall
save('emote_bored', tone(220, 260, 0.22, attack_ms=10, decay_ms=120, harmonics=((1, 1.0), (2, 0.1))))  # زهقان: a flat, dull buzz
save('emote_shy', tone_wobble(700, 10, 25, 150, 0.25, attack_ms=10, decay_ms=90))  # خجلان: a quick, quivering eep
save('emote_surprised', tone_glide(400, 900, 90, 0.35, attack_ms=2, decay_ms=50))  # متفاجئ: a quick upward snap
save('emote_proud', mix(*[(i * 70, tone(f, 140, 0.32, decay_ms=70, harmonics=((1, 1.0), (2, 0.3), (3, 0.1)))) for i, f in enumerate([392, 523, 659])]))  # فخور: a little fanfare
save('emote_dizzy', tone_wobble(500, 9, 120, 380, 0.28, attack_ms=10, decay_ms=200))  # دايخ: a wide, swimming wobble
save('emote_clap', mix((0, noise_burst(35, 0.55, 0.8, attack_ms=1, decay_ms=10)), (130, noise_burst(35, 0.55, 0.8, attack_ms=1, decay_ms=10))))  # يصفّق: two sharp claps
save('emote_thumbsup', mix((0, tone(784, 110, 0.3, decay_ms=55)), (70, tone(1047, 140, 0.28, decay_ms=80))))  # تمام: a short, affirmative bling
save('emote_strong', mix((0, noise_burst(60, 0.08, 0.6, attack_ms=2, decay_ms=25)), (0, tone(110, 220, 0.4, attack_ms=2, decay_ms=120, harmonics=((1, 1.0), (2, 0.3))))))  # قوي: a deep thud
save('emote_kiss', mix((0, noise_burst(16, 0.45, 0.5, attack_ms=1, decay_ms=6)), (10, tone(900, 160, 0.25, decay_ms=90)), (90, tone(1200, 140, 0.18, decay_ms=70))))  # بوسة: a little mwah-pop and a sweet tail
print('ok')
