"""Generates the entity's sounds into game/assets/audio, aiming at the
sound of real analog horror (Mandela Catalogue, Local 58): children's TV
material played from a dying tape. Wow and flutter, drag, dropouts,
saturation, hiss, low-pass, and a synthetic "host" voice built from
formants, pitched down and doubled an octave below.

    python tools/gen_entity_audio.py
"""
import math

import numpy as np
from scipy.signal import butter, lfilter

from gen_audio import OUT as OUT_DIR, SR, fade, normalize, write

rng = np.random.default_rng(1410)


# --- tape -------------------------------------------------------------------

def lp(x, hz, order=2):
    b, a = butter(order, hz / (SR / 2), "low")
    return lfilter(b, a, x)


def hp(x, hz, order=2):
    b, a = butter(order, hz / (SR / 2), "high")
    return lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return lfilter(b, a, x)


def white(n):
    return rng.random(n) * 2 - 1


def tape(x, wow=0.012, flutter=0.003, drags=(), loop=False):
    """Variable tape speed. `drags` = [(time_s, depth, width_s)] moments
    where the tape slows down and the pitch sinks. For loops the speed
    curve is periodic so the seam stays clean."""
    n = len(x)
    length = n / SR
    t = np.arange(n) / SR
    fw = max(1, round(0.55 * length)) / length if loop else 0.55
    ff = max(1, round(6.5 * length)) / length if loop else 6.5
    rate = 1 + wow * np.sin(2 * np.pi * fw * t + 1.3) + flutter * np.sin(2 * np.pi * ff * t)
    rate += 0.004 * np.sin(2 * np.pi * (fw * 3.0) * t + 0.4)
    for at, depth, width in drags:
        rate -= depth * np.exp(-((t - at) / width) ** 2)
    pos = np.cumsum(rate)
    pos *= (n - 1) / pos[-1]
    idx = np.arange(n)
    if loop:
        return np.interp(pos, idx, x, period=n)
    return np.interp(pos, idx, x)


def dropouts(x, count, loop=False):
    env = np.ones(len(x))
    t = np.arange(len(x))
    for _ in range(count):
        c = rng.integers(0, len(x))
        w = int(rng.uniform(0.05, 0.2) * SR)
        d = np.abs(t - c)
        if loop:
            d = np.minimum(d, len(x) - d)
        env -= 0.85 * np.exp(-(d / w) ** 4)
    return x * np.clip(env, 0.1, 1)


def saturate(x, drive=1.8):
    return np.tanh(x * drive) / np.tanh(drive)


def crush(x, bits=7, mix=0.5):
    q = 2 ** (bits - 1)
    return x * (1 - mix) + np.round(x * q) / q * mix


def hiss(n, level=0.02):
    return hp(white(n), 2500) * level


def echo(x, taps=((0.11, 0.35), (0.23, 0.2), (0.37, 0.1))):
    y = np.copy(x)
    for delay, gain in taps:
        k = int(delay * SR)
        y[k:] += x[:-k] * gain
    return y


def vhs_chain(x, wow=0.012, drags=(), loop=False, cutoff=3200, drops=2):
    x = tape(x, wow=wow, drags=drags, loop=loop)
    if loop:  # filter three copies and keep the middle one: no click at the seam
        n = len(x)
        x = lp(saturate(np.tile(x, 3), 1.6), cutoff)[n:2 * n]
    else:
        x = lp(saturate(x, 1.6), cutoff)
    x = dropouts(x, drops, loop)
    return x + hiss(len(x), 0.015)


# --- the show's jingle --------------------------------------------------------

def organ(f, dur, vib=0.004):
    t = np.arange(int(dur * SR)) / SR
    ph = 2 * np.pi * f * np.cumsum(1 + vib * np.sin(2 * np.pi * 5.5 * t)) / SR
    tone = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.32 * np.sin(3 * ph) + 0.18 * np.sign(np.sin(ph)) * 0.5
    env = np.minimum(1, t / 0.012) * np.exp(-t * 1.1)
    return tone * env


def jingle():
    """¡Te estoy viendo! theme: a cheap toy organ, a cheerful bass, and a
    last bar that goes wrong. Slowed, warped and worn like a tape played
    a thousand times. Seamless loop."""
    step = 0.5
    melody = [72, 76, 79, 76, 77, 81, 79, -1, 76, 79, 84, 83, 81, 77, 79, -1,
              72, 76, 79, 76, 77, 74, 71, 72, 66, -1, 63, -1]
    bass = [48, 45, 41, 43, 48, 45, 41, 42]  # the last chord sinks a tritone
    n = int(len(melody) * step * SR)
    out = np.zeros(n)

    def add(sig, start):
        idx = (np.arange(len(sig)) + int(start * SR)) % n
        np.add.at(out, idx, sig)

    detune = 0.82  # the tape runs slow
    for i, m in enumerate(melody):
        if m > 0:
            add(organ(440 * 2 ** ((m - 69) / 12) * detune, step * 1.6) * 0.5, i * step)
    bar = len(melody) * step / len(bass)
    for i, m in enumerate(bass):
        f = 440 * 2 ** ((m - 69) / 12) * detune
        for k in range(4):
            add(organ(f, bar / 4 * 1.2, 0.002) * (0.35 if k % 2 == 0 else 0.22), i * bar + k * bar / 4)
    # a ghost of the tune, reversed, underneath
    seg = out[: int(2.0 * SR)][::-1] * 0.25
    add(lp(seg, 1500), 9.0)
    out = vhs_chain(normalize(out, 0.7), wow=0.02, drags=[(10.2, 0.28, 0.45), (3.1, 0.08, 0.2)], loop=True, cutoff=2800, drops=3)
    return normalize(out, 0.55)


# --- the voice ---------------------------------------------------------------

FORMANTS = {
    "a": (800, 1250, 2550), "e": (450, 1900, 2600), "i": (300, 2250, 3000),
    "o": (470, 850, 2450), "u": (330, 760, 2300), "l": (380, 1100, 2500),
    "n": (280, 1600, 2600), "v": (300, 1150, 2300), "m": (280, 1000, 2300),
}
BANDWIDTH = (90, 130, 180)


VOICE_STRETCH = 1.22  # the entity's words, drawn out a little (not the screams)


def formant_voice(segments, f0_points, f0_scale=1.0, formant_scale=1.0, whisper=False, stretch=None):
    """Source-filter synthesis: a glottal buzz (or breath) through three
    resonators whose frequencies glide from phoneme to phoneme.
    segments: [(phoneme, seconds)]; phonemes are FORMANTS keys plus
    'h' (breath on the next vowel), 's' (hiss), 't' (stop), '_' (silence).
    f0_points: [(fraction of the line 0..1, Hz)]."""
    k = VOICE_STRETCH if stretch is None else stretch
    segments = [(ph, d * k) for ph, d in segments]
    total = sum(d for _, d in segments)
    n = int(total * SR)
    F = np.zeros((3, n))
    voiced = np.zeros(n)
    breath = np.zeros(n)
    sibil = np.zeros(n)
    pos = 0
    last = FORMANTS["a"]
    for i, (ph, dur) in enumerate(segments):
        k = int(dur * SR)
        sl = slice(pos, min(n, pos + k))
        nxt = next((p for p, _ in segments[i + 1:] if p in FORMANTS), "a")
        if ph in FORMANTS:
            last = FORMANTS[ph]
            voiced[sl] = 0.55 if ph in "lnvm" else 1.0
        elif ph == "h":
            last = FORMANTS[nxt]
            breath[sl] = 0.6
        elif ph == "s":
            sibil[sl] = 0.7
        elif ph == "t":
            b = slice(pos + int(0.03 * SR), min(n, pos + int(0.05 * SR)))
            sibil[b] = 1.0
        for j in range(3):
            F[j, sl] = last[j] * formant_scale
        pos += k
    smooth = np.ones(int(0.035 * SR)) / int(0.035 * SR)
    F = np.array([np.convolve(f, smooth, "same") for f in F])
    F[F < 50] = 500
    voiced = np.convolve(voiced, np.ones(200) / 200, "same")
    breath = np.convolve(breath, np.ones(200) / 200, "same")

    t = np.arange(n) / n
    xs, ys = zip(*f0_points)
    f0 = np.interp(t, xs, ys) * f0_scale
    f0 *= 1 + 0.012 * np.sin(2 * np.pi * 5.2 * np.arange(n) / SR) + 0.006 * white(n)
    phase = np.cumsum(f0 / SR) % 1.0
    buzz = lp(2 * phase - 1, 2500, 1)
    src = (white(n) * (voiced * 0.9 + breath)) if whisper else (buzz * voiced + white(n) * breath * 0.6)

    y = np.zeros(n)
    s1 = s2 = 0.0
    stage_in = src
    for j in range(3):
        out = np.zeros(n)
        r = math.exp(-math.pi * BANDWIDTH[j] / SR)
        a2 = -r * r
        y1 = y2 = 0.0
        fj = F[j]
        for i in range(n):
            a1 = 2 * r * math.cos(2 * math.pi * fj[i] / SR)
            v = (1 - r) * stage_in[i] + a1 * y1 + a2 * y2
            y2 = y1
            y1 = v
            out[i] = v
        y += out * (1.0, 0.7, 0.4)[j]
    y += hp(white(n), 4500) * np.convolve(sibil, np.ones(150) / 150, "same") * 0.35
    return y


LINE = [("_", 0.05), ("t", 0.05), ("e", 0.2), ("s", 0.12), ("t", 0.05), ("o", 0.2), ("i", 0.16), ("_", 0.1),
        ("v", 0.07), ("i", 0.12), ("e", 0.24), ("n", 0.08), ("t", 0.04), ("o", 0.75), ("_", 0.25)]
LINE_F0 = [(0, 135), (0.15, 150), (0.3, 175), (0.45, 150), (0.6, 168), (0.75, 145), (0.9, 85), (1.0, 60)]


def voice_line():
    """'¡Te estoy viendo!': the host's peekaboo line, pitched down, doubled
    an octave below, through a worn tape and a small room."""
    host = formant_voice(LINE, LINE_F0, 0.8, 0.95)
    low = formant_voice(LINE, LINE_F0, 0.4, 0.82)
    high = formant_voice(LINE, LINE_F0, 1.19, 1.05)
    v = normalize(host, 1) * 0.7 + normalize(low, 1) * 0.3 + normalize(high, 1) * 0.25
    v = crush(saturate(v, 2.2), 7, 0.4)
    v = echo(v)
    v = vhs_chain(v, wow=0.025, drags=[(len(v) / SR * 0.85, 0.2, 0.25)], cutoff=3000, drops=1)
    return fade(normalize(v, 0.8), 20)


def voice_whisper():
    """Right behind you, something whispering that is not quite words: three
    breathy voices babbling syllables that almost make sense, one of them
    backwards, too close to the ear, with wet mouth clicks. Nothing you can
    make out; you only know it is talking to you."""
    rng = np.random.default_rng(77)
    vowels = "aeiou"
    cons = ["t", "s", "h", "v", "n", "m", "l"]

    def babble(seconds):
        seg = [("_", 0.04)]
        total = 0.04
        while total < seconds:
            c = cons[rng.integers(len(cons))]
            v = vowels[rng.integers(len(vowels))]
            dc, dv = rng.uniform(0.04, 0.09), rng.uniform(0.08, 0.22)
            seg += [(c, dc), (v, dv)]
            total += dc + dv
            if rng.random() < 0.2:
                seg.append(("_", 0.06))
                total += 0.06
        return seg

    dur = 2.6
    n = int(dur * SR)
    out = np.zeros(n)
    for k, (scale, delay, backwards) in enumerate(((1.0, 0.0, False), (0.86, 0.11, True), (1.15, 0.27, False))):
        w = formant_voice(babble(dur - delay), [(0, 100), (1, 100)], 1.0, scale, whisper=True)
        if backwards:
            w = w[::-1]
        w = hp(normalize(w, 1), 250 + 120 * k)
        start_i = int(delay * SR)
        m = min(len(w), n - start_i)
        out[start_i:start_i + m] += w[:m] * (0.9 if k == 0 else 0.55)
    # Wet mouth clicks, close.
    for _ in range(7):
        i = int(rng.uniform(0.1, dur - 0.1) * SR)
        click = bp(white(int(0.012 * SR)), 1500, 5000) * np.exp(-np.linspace(0, 8, int(0.012 * SR)))
        out[i:i + len(click)] += click * 0.8
    # Swells in and out, as if leaning closer and away.
    t = np.arange(n) / SR
    out *= 0.55 + 0.45 * np.sin(2 * np.pi * 0.4 * t + 1.0) ** 2
    out = echo(normalize(out, 1), ((0.05, 0.3), (0.11, 0.18)))
    out = vhs_chain(out, wow=0.025, cutoff=5000, drops=0)
    return fade(normalize(out, 0.75), 30)


def rev_reverb(x, taps=((0.06, 0.6), (0.13, 0.45), (0.21, 0.32), (0.3, 0.22), (0.42, 0.14))):
    """Reverse reverb: the echo arrives before the voice, a breath sucked in."""
    pad = np.zeros(int(0.6 * SR))
    y = echo(np.concatenate([x, pad])[::-1], taps)
    return y[::-1]


def tape_stop(x, seconds=0.7):
    """The last stretch slows down and sinks, like a tape stopping."""
    n = int(seconds * SR)
    if n >= len(x):
        return x
    head, tail = x[:-n], x[-n:]
    t = np.linspace(0, 1, n)
    speed = (1 - t) ** 1.6 * 0.95 + 0.05
    pos = np.cumsum(speed)
    pos = pos / pos[-1] * (n - 1) * 0.55
    return np.concatenate([head, np.interp(pos, np.arange(n), tail) * (1 - t * 0.6)])


def ring(x, hz, mix):
    t = np.arange(len(x)) / SR
    return x * (1 - mix) + x * np.sin(2 * np.pi * hz * t) * mix


WHERE_SEG = [("_", 0.05), ("t", 0.04), ("o", 0.26), ("n", 0.08), ("t", 0.03), ("e", 0.22), ("_", 0.06),
             ("e", 0.12), ("s", 0.14), ("t", 0.04), ("a", 0.75), ("s", 0.2), ("_", 0.3)]


def voice_where(variant=0):
    """'¿Dónde estás...?' sung like hide-and-seek, and wrong: three voices
    (the host, one an octave down, a child's pitch through a throat far too
    big), a reverse echo that breathes in before it, a ring of something
    metallic under it, crushed, a dying tape, and the end sinking like a tape
    stopping. Three versions so it never sounds the same twice."""
    melodies = [
        [(0, 150), (0.2, 178), (0.38, 150), (0.5, 150), (0.62, 160), (0.8, 205), (0.92, 190), (1.0, 120)],
        [(0, 120), (0.2, 132), (0.38, 118), (0.5, 126), (0.65, 140), (0.8, 150), (1.0, 80)],
        [(0, 190), (0.18, 240), (0.36, 200), (0.5, 210), (0.66, 230), (0.82, 290), (1.0, 170)],
    ]
    f0 = melodies[variant]
    seg = [(ph, d * (1.0, 1.35, 0.9)[variant]) for ph, d in WHERE_SEG]
    host = formant_voice(seg, f0, 0.85, 0.97)
    low = formant_voice(seg, f0, 0.42, 0.8)
    child = formant_voice(seg, f0, 1.7, 0.72)   # a child's pitch, a giant's throat
    v = normalize(host, 1) * 0.7 + normalize(low, 1) * 0.28 + normalize(child, 1) * (0.4, 0.3, 0.55)[variant]
    v = ring(v, (37, 29, 53)[variant], 0.35)
    v = crush(saturate(v, 2.6), 6, 0.5)
    v = rev_reverb(v)
    v = echo(v, ((0.13, 0.4), (0.27, 0.25), (0.41, 0.15)))
    v = vhs_chain(v, wow=(0.04, 0.06, 0.035)[variant], drags=[(len(v) / SR * 0.55, 0.3, 0.3)], cutoff=2600, drops=2)
    v = tape_stop(v, (0.6, 0.9, 0.5)[variant])
    return finish(v, 0.75)


def voice_reverse():
    """For the TV's last cut: '¡te estoy viendo!' played backwards, slowed,
    with its echo coming first."""
    v = voice_line()[::-1]
    pos = np.arange(0, len(v) - 1, 0.8)
    v = np.interp(pos, np.arange(len(v)), v)
    v = rev_reverb(v)
    v = vhs_chain(v, wow=0.05, cutoff=2200, drops=2)
    return fade(normalize(v, 0.7), 30)


def host_voice(seg, f0, wow=0.03, drag_at=0.7, double=0.3, cutoff=2800, room=((0.13, 0.4), (0.27, 0.25), (0.41, 0.15))):
    """The entity's sung/spoken voice, the recipe of '¿dónde estás?': a
    formant voice (source-filter) doubled an octave below, saturated,
    bit-crushed, in a hollow room, and then through a dying tape (wow and
    flutter, a drag that slows the tape mid-word, dropouts, hiss). The words
    are there; the voice is not quite a person."""
    host = formant_voice(seg, f0, 0.85, 0.97)
    low = formant_voice(seg, f0, 0.42, 0.84)
    v = normalize(host, 1) * 0.65 + normalize(low, 1) * double
    v = crush(saturate(v, 1.8), 7, 0.35)
    v = echo(v, room)
    v = vhs_chain(v, wow=wow, drags=[(len(v) / SR * drag_at, 0.25, 0.2)], cutoff=cutoff, drops=1)
    return fade(normalize(v, 0.75), 20)


def voice_count():
    """Counting to ten for hide-and-seek, as on the show, each number later
    and lower than the last, the tape dragging more and more."""
    words = [[("u", 0.18), ("n", 0.07), ("o", 0.3)], [("t", 0.04), ("o", 0.26), ("s", 0.14)],
             [("t", 0.04), ("l", 0.05), ("e", 0.24), ("s", 0.14)], [("t", 0.04), ("u", 0.1), ("a", 0.16), ("t", 0.04), ("l", 0.04), ("o", 0.24)],
             [("s", 0.1), ("i", 0.16), ("n", 0.06), ("t", 0.04), ("o", 0.24)], [("s", 0.1), ("e", 0.18), ("i", 0.12), ("s", 0.14)],
             [("s", 0.1), ("i", 0.08), ("e", 0.16), ("t", 0.04), ("e", 0.24)], [("o", 0.2), ("t", 0.06), ("o", 0.26)],
             [("n", 0.06), ("u", 0.08), ("e", 0.16), ("v", 0.06), ("e", 0.26)], [("t", 0.04), ("i", 0.08), ("e", 0.22), ("s", 0.18)]]
    parts = []
    for k, w in enumerate(words):
        f = 170 - k * 7
        seg = [("_", 0.05)] + w + [("_", 0.25 + k * 0.06)]
        part = host_voice(seg, [(0, f), (0.4, f + 12), (1, f - 30)], wow=0.02 + k * 0.006, drag_at=0.6, cutoff=3000 - k * 120)
        parts.append(part * (0.8 + 0.02 * k))
    return fade(normalize(np.concatenate(parts), 0.75), 20)


def voice_ready():
    """'¡Allá voy!' ...ready or not, here I come."""
    seg = [("_", 0.05), ("a", 0.16), ("l", 0.07), ("a", 0.42), ("_", 0.08), ("v", 0.06), ("o", 0.3), ("i", 0.5), ("_", 0.3)]
    return host_voice(seg, [(0, 160), (0.3, 200), (0.5, 150), (0.75, 210), (1, 120)], wow=0.035, drag_at=0.8)


def voice_lost():
    """'¿Dónde te has metido?' when it loses you, sing-song, close to cross."""
    seg = [("_", 0.05), ("t", 0.04), ("o", 0.2), ("n", 0.06), ("t", 0.03), ("e", 0.12), ("t", 0.03), ("e", 0.12), ("a", 0.18), ("s", 0.1),
           ("m", 0.06), ("e", 0.12), ("t", 0.04), ("i", 0.16), ("t", 0.04), ("o", 0.5), ("_", 0.3)]
    return host_voice(seg, [(0, 150), (0.25, 175), (0.5, 140), (0.7, 160), (0.85, 210), (1, 110)], wow=0.04, drag_at=0.85)


def voice_found():
    """'¡Te encontré!' when it finds you in a hiding place: higher, delighted."""
    seg = [("_", 0.04), ("t", 0.04), ("e", 0.12), ("e", 0.08), ("n", 0.06), ("t", 0.04), ("o", 0.14), ("n", 0.06), ("t", 0.04), ("l", 0.05),
           ("e", 0.55), ("_", 0.3)]
    return host_voice(seg, [(0, 190), (0.3, 230), (0.6, 210), (0.75, 260), (1, 240)], wow=0.02, drag_at=0.9, double=0.5)


def voice_hum():
    """Humming the show's tune with its mouth shut, slow, off-key, on a
    tape that sags: it is wandering about and does not know where you are."""
    notes = [196, 220, 247, 196, 262, 247, 220, 0, 196, 220, 247, 294, 262, 233, 220]
    seg, f0 = [], []
    total = sum(0.45 if n else 0.3 for n in notes)
    t = 0.0
    for n in notes:
        d = 0.45 if n else 0.3
        seg.append(("m", d) if n else ("_", d))
        f0.append((t / total, (n or 196) * 0.62))
        t += d
    f0.append((1.0, 120))
    hum = formant_voice(seg, f0, 1.0, 0.9)
    low = formant_voice(seg, f0, 0.5, 0.8)
    v = normalize(hum, 1) * 0.8 + normalize(low, 1) * 0.25
    v = saturate(v, 1.5)
    v = echo(v, ((0.17, 0.35), (0.33, 0.2)))
    v = vhs_chain(v, wow=0.05, drags=[(len(v) / SR * 0.5, 0.4, 0.3)], cutoff=2200, drops=2)
    return fade(normalize(v, 0.7), 40)


def voice_giggle():
    """A child's giggle in its throat: the pitch of a child, the formants of
    something much bigger, each burst a little too long."""
    rng = np.random.default_rng(5)
    seg, f0 = [("_", 0.04)], []
    for k in range(7):
        seg += [("h", 0.05), ("i" if k % 2 else "e", 0.09 + rng.uniform(0, 0.05)), ("_", 0.05)]
    total = sum(d for _, d in seg)
    f0 = [(0, 300), (0.5, 360), (0.8, 330), (1, 250)]
    v = formant_voice(seg, f0, 1.0, 0.7)
    v = crush(saturate(normalize(v, 1), 2.0), 6, 0.4)
    v = echo(v, ((0.09, 0.4), (0.2, 0.25)))
    v = vhs_chain(v, wow=0.03, cutoff=3500, drops=1)
    return fade(normalize(v, 0.7), 15)


# --- variants, and the new sounds (every sound has at least two takes) ------------

def finish(v, peak=0.75, pad=0.5, room=((0.11, 0.3), (0.23, 0.18), (0.37, 0.1))):
    """Let it ring out instead of stopping dead: silence after it, the room's
    echo filling it, and a long fade at the very end."""
    v = np.concatenate([np.zeros(int(0.02 * SR)), v, np.zeros(int(pad * SR))])
    v = hp(v, 220)  # no boom: thin, close, wrong
    v = echo(v, room)
    n = int(0.4 * SR)
    v[-n:] *= np.cos(np.linspace(0, np.pi / 2, n)) ** 2
    m = int(0.02 * SR)
    v[:m] *= np.linspace(0, 1, m)
    return normalize(v, peak)


def stutter(v, at=0.0, length=0.16, times=2):
    """The tape skips: a scrap repeated before it goes on."""
    i0 = int(at * SR)
    chunk = v[i0:i0 + int(length * SR)]
    return np.concatenate([v[:i0]] + [chunk * (0.8 + 0.1 * k) for k in range(times)] + [v[i0:]])


def wrong_voice(seg, f0, child=0.3, ring_hz=41, crush_bits=6, wow=0.045, stop=0.6, drag_at=0.6):
    """The recipe pushed further, so the words are barely there: the host,
    an octave below, a child's pitch in a giant's throat, a metallic ring,
    crushed, a reverse echo breathing in first, a dying tape, a tape stop."""
    host = formant_voice(seg, f0, 1.0, 0.98)
    low = formant_voice(seg, f0, 0.5, 0.82)
    kid = formant_voice(seg, f0, 1.65, 0.75)
    v = normalize(host, 1) * 0.7 + normalize(low, 1) * 0.3 + normalize(kid, 1) * (child + 0.15)
    v = ring(v, ring_hz, 0.4)
    v = crush(saturate(v, 2.8), crush_bits, 0.55)
    v = rev_reverb(v)
    v = vhs_chain(v, wow=wow, drags=[(len(v) / SR * drag_at, 0.3, 0.3)], cutoff=2500, drops=2)
    return tape_stop(v, stop)


def voice_line_v(variant=0):
    """'¡Te estoy viendo!' — what it shouts when it has you. Now the words
    hide inside it, and it comes out backwards: you know the melody, never
    the words."""
    seg = [(ph, d * (1.25, 1.55)[variant]) for ph, d in LINE]
    if variant == 0:
        f0 = [(0, 125), (0.15, 140), (0.3, 165), (0.45, 140), (0.6, 158), (0.75, 135), (0.9, 75), (1.0, 50)]
        v = wrong_voice(seg, f0, child=0.3, ring_hz=41)
    else:
        f0 = [(0, 160), (0.2, 150), (0.35, 210), (0.5, 170), (0.7, 240), (0.85, 200), (1.0, 90)]
        v = stutter(wrong_voice(seg, f0, child=0.45, ring_hz=33, stop=0.9), 0.05, 0.14, 3)
    v = v[::-1]  # backwards: the echo breathes in first and the words are gone
    return finish(fade(v, 25), 0.8)


def voice_count_v(variant=0):
    words = [[("u", 0.18), ("n", 0.07), ("o", 0.3)], [("t", 0.04), ("o", 0.26), ("s", 0.14)],
             [("t", 0.04), ("l", 0.05), ("e", 0.24), ("s", 0.14)], [("t", 0.04), ("u", 0.1), ("a", 0.16), ("t", 0.04), ("l", 0.04), ("o", 0.24)],
             [("s", 0.1), ("i", 0.16), ("n", 0.06), ("t", 0.04), ("o", 0.24)], [("s", 0.1), ("e", 0.18), ("i", 0.12), ("s", 0.14)],
             [("s", 0.1), ("i", 0.08), ("e", 0.16), ("t", 0.04), ("e", 0.24)], [("o", 0.2), ("t", 0.06), ("o", 0.26)],
             [("n", 0.06), ("u", 0.08), ("e", 0.16), ("v", 0.06), ("e", 0.26)], [("t", 0.04), ("i", 0.08), ("e", 0.22), ("s", 0.18)]]
    parts = []
    for k, w in enumerate(words):
        if variant == 0:
            f = 170 - k * 7
            contour = [(0, f), (0.4, f + 12), (1, f - 30)]
            gap = 0.25 + k * 0.06
        else:  # sung, rising, faster and faster, the last ones whispered high
            f = 140 + k * 9
            contour = [(0, f), (0.5, f * 1.1), (1, f * 0.95)]
            gap = max(0.08, 0.35 - k * 0.03)
        seg = [("_", 0.05)] + w + [("_", gap)]
        part = host_voice(seg, contour, wow=0.02 + k * 0.006, drag_at=0.6, cutoff=3000 - k * 120)
        parts.append(part * (0.8 + 0.02 * k))
    return finish(np.concatenate(parts), 0.75, 0.6)


def voice_ready_v(variant=0):
    if variant == 0:
        return finish(voice_ready(), 0.75)
    seg = [("_", 0.05), ("a", 0.4), ("l", 0.1), ("a", 0.7), ("_", 0.1), ("v", 0.08), ("o", 0.5), ("i", 0.9), ("_", 0.2)]
    return finish(wrong_voice(seg, [(0, 110), (0.3, 150), (0.5, 105), (0.75, 170), (1, 70)], child=0.35, stop=0.8), 0.75)


def voice_lost_v(variant=0):
    if variant == 0:
        return finish(voice_lost(), 0.75)
    seg = [("_", 0.05), ("t", 0.04), ("o", 0.3), ("n", 0.08), ("t", 0.03), ("e", 0.18), ("_", 0.25), ("t", 0.03), ("e", 0.16),
           ("a", 0.25), ("s", 0.12), ("m", 0.08), ("e", 0.16), ("t", 0.04), ("i", 0.22), ("t", 0.04), ("o", 0.8)]
    return finish(wrong_voice(seg, [(0, 130), (0.3, 120), (0.5, 160), (0.8, 135), (1, 60)], child=0.25, stop=1.0), 0.75)


def voice_found_v(variant=0):
    if variant == 0:
        return finish(voice_found(), 0.78)
    seg = [("_", 0.04), ("t", 0.04), ("e", 0.2), ("e", 0.14), ("n", 0.08), ("t", 0.04), ("o", 0.2), ("n", 0.08), ("t", 0.04), ("l", 0.06), ("e", 1.0)]
    return finish(stutter(wrong_voice(seg, [(0, 150), (0.4, 170), (0.7, 120), (1, 260)], child=0.55, stop=0.4), 0.0, 0.12, 2), 0.78)


def voice_hum_v(variant=0):
    if variant == 0:
        return finish(voice_hum(), 0.7, 0.6)
    notes = [220, 208, 196, 0, 175, 165, 196, 185, 0, 147, 139, 131]   # the tune, falling, minor, wrong
    seg, f0 = [], []
    total = sum(0.55 if n else 0.35 for n in notes)
    t = 0.0
    for n in notes:
        d = 0.55 if n else 0.35
        seg.append(("m", d) if n else ("_", d))
        f0.append((t / total, (n or 160) * 0.6))
        t += d
    f0.append((1.0, 70))
    v = normalize(formant_voice(seg, f0, 1.0, 0.85), 1) * 0.7 + normalize(formant_voice(seg, f0, 0.5, 0.75), 1) * 0.7
    v = vhs_chain(echo(saturate(v, 1.6), ((0.21, 0.35), (0.4, 0.2))), wow=0.07, drags=[(len(v) / SR * 0.6, 0.5, 0.35)], cutoff=2000, drops=2)
    return finish(tape_stop(v, 1.2), 0.7, 0.6)


def voice_giggle_v(variant=0):
    """A child's giggle in its throat; it trails off into the room now."""
    rng = np.random.default_rng(5 + variant)
    seg = [("_", 0.04)]
    bursts = 7 if variant == 0 else 10
    for k in range(bursts):
        seg += [("h", 0.05), ("i" if k % 2 else "e", 0.09 + rng.uniform(0, 0.06)), ("_", 0.05 + 0.01 * k)]
    f0 = [(0, 300), (0.5, 360), (0.8, 330), (1, 250)] if variant == 0 else [(0, 240), (0.3, 300), (0.7, 220), (1, 160)]
    v = formant_voice(seg, f0, 1.0, 0.7 if variant == 0 else 0.6)
    v = crush(saturate(normalize(v, 1), 2.0), 6, 0.4)
    v = vhs_chain(v, wow=0.03, cutoff=3500, drops=1)
    return finish(v, 0.72, 0.7, ((0.09, 0.4), (0.2, 0.28), (0.34, 0.16), (0.5, 0.08)))


def laugh_v(variant=0):
    if variant == 0:
        return finish(laugh(), 0.85)
    parts = []
    for k in range(5):
        f = 180 - k * 12
        seg = [("h", 0.07), ("a", 0.18), ("_", 0.11)]
        parts.append(formant_voice(seg, [(0, f), (0.4, f * 1.25), (1, f * 0.8)], 0.7, 0.9))
    v = np.concatenate(parts)
    low = np.concatenate([formant_voice([("h", 0.07), ("a", 0.18), ("_", 0.11)], [(0, 95), (1, 80)], 0.7, 0.75) for _ in range(5)])
    x = normalize(v, 1) * 0.7 + normalize(low[: len(v)], 1) * 0.8
    x = vhs_chain(rev_reverb(saturate(x, 3.0)), wow=0.05, cutoff=3000, drops=2)
    return finish(tape_stop(x, 0.5), 0.85)


def voice_cry(variant=0):
    """Crying in pain, somewhere in the house: long, slow wails that never
    hurry, each one sliding down and breaking at the end, a slow breath
    drawn in between. A child's pitch through something far too big."""
    rng = np.random.default_rng(31 + variant)
    out = []
    phrases = 2 if variant == 0 else 3
    for k in range(phrases):
        n_in = int(0.7 * SR)
        breath = bp(white(n_in), 500, 1800) * np.sin(np.linspace(0, np.pi, n_in)) ** 2 * 0.18
        dur = rng.uniform(2.6, 3.4)
        top = (360, 300)[variant] - k * 18
        seg = [("a", dur * 0.45), ("o", dur * 0.3), ("u", dur * 0.25)]
        f0 = [(0, top * 0.92), (0.15, top), (0.5, top * 0.9), (0.8, top * 0.72), (0.92, top * 0.8), (1, top * 0.55)]
        wail = formant_voice(seg, f0, 1.0, 0.74)
        under = formant_voice(seg, f0, 0.5, 0.7)
        w = normalize(wail, 1) * 0.9 + normalize(under, 1) * 0.12
        t = np.arange(len(w)) / SR
        env = np.minimum(1, t / 0.35) * np.minimum(1, (t[-1] - t) / 0.8)
        w *= env * (0.85 + 0.15 * np.sin(2 * np.pi * 1.3 * t))   # a slow waver, never a sob
        out += [breath, w, np.zeros(int(rng.uniform(0.5, 0.9) * SR))]
    v = np.concatenate(out)
    v = saturate(v, 1.5)
    v = vhs_chain(rev_reverb(v), wow=0.035, cutoff=3000, drops=1)
    return finish(v, 0.7, 0.9, ((0.13, 0.35), (0.27, 0.22), (0.43, 0.14), (0.62, 0.08)))


def voice_moan(variant=0):
    """A moan of pain, long and low, the voice breaking into a rattle."""
    rng = np.random.default_rng(41 + variant)
    dur = (2.6, 3.2)[variant]
    seg = [("h", 0.2), ("o", dur * 0.4), ("u", dur * 0.3), ("a", dur * 0.3 - 0.2)] if variant == 0 else \
          [("h", 0.15), ("a", dur * 0.35), ("_", 0.12), ("o", dur * 0.55)]
    walk = np.cumsum(rng.normal(0, 4, 12))
    f0 = [(i / 11, max(90, (150, 130)[variant] + walk[i] * 1.5)) for i in range(12)]
    a = formant_voice(seg, f0, 1.0, 0.85)
    b = formant_voice(seg, f0, 0.97, 0.8)
    v = normalize(a, 1) * 0.7 + normalize(b, 1) * 0.6
    v = ring(v, 23, 0.25)
    v = saturate(v, 2.2)
    v = vhs_chain(rev_reverb(v), wow=0.05, drags=[(len(v) / SR * 0.7, 0.4, 0.3)], cutoff=2200, drops=1)
    return finish(tape_stop(v, 0.7), 0.72, 0.6)


def voice_frustrated(variant=0):
    """Frustration: it has lost you. Grunts through its teeth and a growl
    breathed out, or a long 'no' that cracks."""
    if variant == 0:
        seg = [("m", 0.22), ("_", 0.09), ("n", 0.14), ("a", 0.12), ("_", 0.14), ("h", 0.12), ("a", 0.4), ("_", 0.1)]
        f0 = [(0, 150), (0.25, 190), (0.45, 130), (0.65, 200), (1, 95)]
    else:
        seg = [("n", 0.12), ("o", 1.1), ("_", 0.1)]
        f0 = [(0, 220), (0.3, 250), (0.55, 140), (0.65, 230), (1, 80)]
    host = formant_voice(seg, f0, 1.0, 0.92)
    low = formant_voice(seg, f0, 0.6, 0.8)
    v = normalize(host, 1) * 0.85 + normalize(low, 1) * 0.2
    v = crush(saturate(v, 3.6), 5, 0.6)
    n = int(0.5 * SR)
    breath = bp(white(n), 350, 1800) * np.linspace(1, 0, n) * 0.35
    v = np.concatenate([v, breath])
    v = vhs_chain(v, wow=0.035, cutoff=2600, drops=1)
    v = hp(hp(v, 260), 260)  # its teeth, not a rumble
    return finish(v, 0.78)


def voice_reverse_v(variant=0):
    if variant == 0:
        return finish(voice_reverse(), 0.7)
    v = voice_where(1)[::-1]
    pos = np.arange(0, len(v) - 1, 0.75)
    v = np.interp(pos, np.arange(len(v)), v)
    return finish(vhs_chain(rev_reverb(v), wow=0.06, cutoff=2000, drops=2), 0.7)


def voice_agony(variant=0):
    """The flash burns it: its low wrong voice for an instant, then the
    pitch snaps up into a woman's scream, shrill, wavering, breaking, as if
    another voice came out of it; then it chokes off and the tape sinks."""
    rng = np.random.default_rng(61 + variant)
    low_seg = [("_", 0.02), ("o", 0.22)]
    low = wrong_voice(low_seg, [(0, 140), (1, 110)], child=0.2, ring_hz=41, crush_bits=6, wow=0.03, stop=0.05, drag_at=0.9)
    dur = (1.9, 2.3)[variant]
    seg = [("a", dur * 0.55), ("e", dur * 0.25), ("a", dur * 0.2)] if variant == 0 else [("i", dur * 0.3), ("a", dur * 0.7)]
    top = (980, 860)[variant]
    f0 = [(0, top * 0.8), (0.06, top * 1.05), (0.25, top * 0.95), (0.45, top * 1.12), (0.6, top), (0.8, top * 1.08), (0.92, top * 0.7), (1, top * 0.45)]
    f0 = [(x, y * (1 + rng.normal(0, 0.02))) for x, y in f0]
    scream = formant_voice(seg, f0, 1.0, 1.28, stretch=1.0)
    scream2 = formant_voice(seg, [(x, y * 1.01) for x, y in f0], 1.0, 1.22, stretch=1.0)
    v = normalize(scream, 1) * 0.8 + normalize(scream2, 1) * 0.5 + bp(white(len(scream)), 2500, 7000) * 0.12
    t = np.arange(len(v)) / SR
    v *= 0.75 + 0.25 * np.sin(2 * np.pi * 7.5 * t)            # the scream wavers
    v *= np.where((t > dur * 0.48) & (t < dur * 0.52), 0.25, 1.0)  # it breaks for an instant
    v = crush(saturate(v, 2.2), 7, 0.3)
    v = echo(v, ((0.12, 0.35), (0.27, 0.22), (0.45, 0.12)))
    v = vhs_chain(v, wow=0.025, cutoff=7000, drops=1)
    v = tape_stop(v, 0.45)
    out = np.concatenate([normalize(low, 0.7), v])
    return finish(out, 0.9, 0.6)


def voice_hunger(variant=0):
    """Found lying in wait, it comes: no words, a starved, desperate roar,
    as if it has wanted you for hours and has you at last. Gasps in, a
    guttural cry that climbs and cracks, the breath ragged after it."""
    rng = np.random.default_rng(71 + variant)
    gasp_n = int(0.18 * SR)
    gasp = bp(white(gasp_n), 600, 2400) * np.linspace(0.2, 1.0, gasp_n) ** 2 * 0.6
    dur = (1.3, 1.6)[variant]
    seg = [("h", 0.06), ("a", dur * 0.7), ("o", dur * 0.3)] if variant == 0 else [("h", 0.05), ("o", dur * 0.3), ("a", dur * 0.7)]
    f0 = [(0, 120), (0.2, 200), (0.45, 260), (0.6, 230), (0.75, 290), (1, 150)]
    roar = wrong_voice(seg, f0, child=0.35, ring_hz=33, crush_bits=5, wow=0.02, stop=0.2, drag_at=0.9)
    growl = formant_voice(seg, [(0, 60), (1, 75)], 1.0, 0.7, stretch=1.0)
    n = min(len(roar), len(growl))
    v = normalize(roar[:n], 1) * 0.9 + normalize(growl[:n], 1) * 0.35
    t = np.arange(n) / SR
    v *= 0.8 + 0.2 * np.sin(2 * np.pi * 11.0 * t)   # ragged
    v = saturate(v, 3.2)
    pant = np.concatenate([bp(white(int(0.14 * SR)), 500, 2000) * np.hanning(int(0.14 * SR)) * 0.35,
                           np.zeros(int(0.06 * SR)),
                           bp(white(int(0.12 * SR)), 500, 2000) * np.hanning(int(0.12 * SR)) * 0.3])
    return finish(np.concatenate([gasp, v, pant]), 0.9, 0.4)


def chase_scream(variant=0):
    """Chasing you: a human scream, a grown man's, desperate, throat torn,
    the kind a person makes running at you out of their mind: the voice
    breaking upwards into a shriek and cracking, raw and hoarse, with a
    lower body under it so it stays heavy; ragged gasps in between. Then a
    little wrong: a second voice a hair off pitch, slightly overdriven."""
    rng = np.random.default_rng(1400 + variant)
    bursts = ((1.2, 0.9), (1.0, 1.25), (0.95,))[variant]
    parts = []
    for k, dur in enumerate(bursts):
        n = int(dur * SR)
        u = np.linspace(0, 1, 24)
        # A man screaming, deep: from a roar (~110 Hz) straining up to a
        # shout (~260 Hz), cracking at the top, then falling as the breath goes.
        top = rng.uniform(240, 280)
        crack_at = rng.uniform(0.35, 0.6)
        f0 = 110 + (top - 110) * np.sin(np.pi * np.clip(u * 1.15, 0, 1)) ** 0.7
        f0 *= 1.0 + 0.28 * np.exp(-((u - crack_at) / 0.04) ** 2)          # the voice cracks
        f0 *= 1.0 + 0.035 * np.sin(u * 40 + rng.uniform(0, 6))            # shaking
        pts = [(float(x), float(y)) for x, y in zip(u, f0)]
        seg = [("a", dur * 0.7), ("o", dur * 0.3)] if k % 2 == 0 else [("h", 0.05), ("a", dur * 0.95)]
        voice = formant_voice(seg, pts, 1.0, 0.95, stretch=1.0)
        other = formant_voice(seg, [(x, y * 1.012) for x, y in pts], 1.0, 0.9, stretch=1.0)  # a second throat, a hair off
        low = formant_voice(seg, [(x, y * 0.5) for x, y in pts], 1.0, 0.8, stretch=1.0)
        m = min(len(voice), len(other), len(low), n)
        t = np.arange(m) / SR
        rasp = bp(white(m), 1200, 4500) * (0.6 + 0.4 * np.sin(np.pi * t / dur))   # hoarse air
        x = normalize(voice[:m], 1) + normalize(other[:m], 1) * 0.45 + normalize(low[:m], 1) * 0.4 + rasp * 0.3
        x = saturate(x, 10.0)                    # strained, torn, blown out
        x = crush(x, bits=6, mix=0.35)
        x = lp(x, 6000)
        x = saturate(x * 1.6, 3.5)               # and again, like a speaker giving out
        x *= np.minimum(1, t / 0.04) * np.minimum(1, (dur - t) / 0.15)
        parts.append(x)
        if k < len(bursts) - 1:
            g = int(rng.uniform(0.2, 0.3) * SR)
            gt = np.arange(g) / g
            parts.append(bp(white(g), 700, 3000) * np.sin(np.pi * gt) ** 2 * 0.3)  # a ragged gasp in
    v = np.concatenate(parts)
    v = echo(v, ((0.08, 0.25), (0.17, 0.14), (0.3, 0.07)))
    return finish(v, 0.95, 0.3)


def neck_breath():
    """Its breath on the back of your neck (a loop, while it is right behind
    you): slow, wet, too deep, a rattle in the throat on the way out. Close,
    dry, no room: it is right there."""
    rng = np.random.default_rng(31)
    out = []
    for k in range(2):
        a, b = 1.25 + 0.15 * k, 1.7 - 0.1 * k
        ni, ne = int(a * SR), int(b * SR)
        ti, te = np.arange(ni) / ni, np.arange(ne) / ne
        # In: a rough draw through the teeth, rising.
        inhale = bp(white(ni), 700, 3800) * np.sin(np.pi * ti) ** 1.5 * (0.5 + 0.5 * ti) * 0.55
        # Out: lower, wetter, with a rattle (a slow buzz under the air).
        rattle = np.sign(np.sin(2 * np.pi * np.cumsum(38 + 10 * rng.random(ne)) / SR)) * 0.5
        exhale = (bp(white(ne), 250, 1800) * 0.8 + lp(rattle * white(ne) * 0.5 + rattle * 0.12, 900)) * np.sin(np.pi * te) ** 1.2 * (1.0 - 0.6 * te)
        out += [inhale, np.zeros(int(0.18 * SR)), exhale, np.zeros(int((0.5 + 0.2 * k) * SR))]
    x = np.concatenate(out)
    return normalize(lp(x, 4500), 0.6)


def wake_cry():
    """The one sound when it gets into the house: a tearing scream, as if
    it shouted '¡LIBERTAD!' (freedom), low and in agony, like someone being
    tortured: the voice strains and cracks on the last syllable, a man's
    groan grinds under it, a woman's cry breaks over it, and it ends in a
    choked sob and a gasp. Far off, through the walls. Then nothing."""
    rng = np.random.default_rng(99)
    seg = [("_", 0.02), ("l", 0.08), ("i", 0.17), ("v", 0.05), ("e", 0.18), ("l", 0.05), ("t", 0.05), ("a", 1.45), ("_", 0.05)]
    # Low, and shaking: the pitch strains up and keeps breaking.
    f0 = [(0, 165), (0.08, 200), (0.16, 190), (0.26, 235), (0.34, 250), (0.45, 300), (0.6, 330), (0.75, 290), (0.9, 210), (1, 140)]
    f0 = [(x, y * (1 + (rng.normal(0, 0.05) if 0.4 < x < 0.95 else 0))) for x, y in f0]
    shout = wrong_voice(seg, f0, child=0.2, ring_hz=47, crush_bits=5, wow=0.03, stop=0.2, drag_at=0.93)
    tail_seg = [("_", 0.66), ("a", 0.8), ("o", 0.5), ("_", 0.05)]
    groan = formant_voice(tail_seg, [(0, 120), (0.4, 140), (0.7, 128), (1, 90)], 1.0, 0.85, stretch=1.0)
    cry = formant_voice(tail_seg, [(0, 620), (0.3, 760), (0.55, 820), (0.8, 640), (1, 420)], 1.0, 1.2, stretch=1.0)
    n = max(len(shout), len(groan), len(cry))
    pad = lambda a: np.pad(a, (0, n - len(a)))
    t = np.arange(n) / SR
    # The voice cracking: sudden dips, like a breath knocked out of it.
    crack = np.ones(n)
    for at in (0.95, 1.22, 1.5, 1.74):
        crack *= 1 - 0.75 * np.exp(-((t - at) / 0.035) ** 2)
    shake = 0.7 + 0.3 * np.sin(2 * np.pi * 6.5 * t + 3 * np.sin(2 * np.pi * 1.3 * t))
    x = normalize(pad(shout), 1) * 0.95 * crack
    x += normalize(pad(groan), 1) * 0.5 * shake
    x += normalize(pad(cry), 1) * 0.35 * shake * crack
    x += bp(white(n), 1500, 4500) * np.clip((t - 0.66) / 0.15, 0, 1) * np.exp(-np.maximum(0, t - 1.3) * 3) * 0.16  # the tear
    x = saturate(x, 3.2)
    # A choked sob and a gasp after it.
    sob = formant_voice([("_", 0.05), ("u", 0.12), ("_", 0.1), ("u", 0.16), ("_", 0.05)], [(0, 260), (0.5, 230), (1, 170)], 1.0, 1.0, stretch=1.0)
    gn = int(0.45 * SR)
    gt = np.arange(gn) / gn
    gasp = bp(white(gn), 900, 3200) * np.sin(np.pi * gt) ** 2 * (0.4 + gt) * 0.5
    after = np.concatenate([np.zeros(int(0.15 * SR)), normalize(sob, 1) * 0.35, np.zeros(int(0.1 * SR)), gasp])
    x = np.concatenate([x, after, np.zeros(int(0.6 * SR))])
    x = echo(x, ((0.21, 0.38), (0.43, 0.24), (0.7, 0.13)))
    x = lp(x, 4200)  # a little far off
    return finish(x, 0.9, 0.2)


def flash_fire():
    """The camcorder's flash going off: a hard click, the pop of the tube,
    a bright crackle."""
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    click = np.zeros(n)
    click[:int(0.004 * SR)] = 1.0
    pop = bp(white(n), 900, 7000) * np.exp(-t * 28) * 0.9
    thump = np.sin(2 * np.pi * 70 * t) * np.exp(-t * 20) * 0.6
    crackle = (np.random.default_rng(3).random(n) > 0.985) * np.exp(-t * 9) * 0.5
    return finish(saturate(click + pop + thump + crackle, 2.0), 0.9, 0.2)


def flash_charge():
    """Recharging: the whine of the capacitor climbing."""
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    f = 2200 + 5200 * (t / t[-1]) ** 0.7
    phase = np.cumsum(f / SR) * 2 * np.pi
    v = np.sin(phase) * 0.25 * (0.3 + 0.7 * (t / t[-1])) + np.sin(phase * 2.01) * 0.05
    v *= np.minimum(1, t / 0.05) * np.minimum(1, (t[-1] - t) / 0.08)
    return normalize(v, 0.5)


VARIANTS = {
    "voice_line": voice_line_v, "voice_count": voice_count_v, "voice_ready": voice_ready_v,
    "voice_lost": voice_lost_v, "voice_found": voice_found_v, "voice_hum": voice_hum_v,
    "voice_giggle": voice_giggle_v, "laugh": laugh_v, "voice_cry": voice_cry, "voice_moan": voice_moan,
    "voice_frustrated": voice_frustrated, "voice_reverse": voice_reverse_v, "voice_agony": voice_agony, "voice_hunger": voice_hunger,
    "chase_scream": chase_scream,
}


def write_variants():
    """Two takes of each: <name>.wav and <name>2.wav."""
    for name, fn in VARIANTS.items():
        write(name, fn(0))
        write(name + "2", fn(1))


def intrusion_buzz():
    """The hijacked signal: a loud mains buzz with a sawtooth growl under
    it, clipping, and a voice-like formant sweeping through, as on the 1987
    Chicago intrusion. Loops."""
    dur = 3.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    buzz = sum(np.sign(np.sin(2 * np.pi * 60 * k * t)) / k for k in (1, 3, 5)) * 0.5
    saw = ((t * 118.0) % 1.0) * 2 - 1
    growl = lp(saw * (0.6 + 0.4 * np.sin(2 * np.pi * 0.7 * t)), 900)
    sweep = bp(white(n), 400, 1800) * (0.5 + 0.5 * np.sin(2 * np.pi * 1.3 * t)) * 0.6
    x = buzz * 0.6 + growl * 0.5 + sweep
    x = saturate(x, 3.0)
    x = crush(x, 6, 0.5)
    return normalize(hp(x, 50), 0.85)


def scream():
    """'¡VECINITO!' shouted, clipped."""
    seg = [("v", 0.05), ("e", 0.16), ("s", 0.08), ("i", 0.14), ("n", 0.05), ("i", 0.14), ("t", 0.04), ("o", 0.5)]
    f0 = [(0, 260), (0.4, 330), (0.7, 380), (1, 190)]
    v = normalize(formant_voice(seg, f0, 1.0, 1.1, stretch=1.0), 1) + normalize(formant_voice(seg, f0, 0.5, 0.9, stretch=1.0), 1) * 0.8
    return saturate(v, 5.0)


# --- presence ---------------------------------------------------------------

def drone():
    """Low beating cluster, a breath that swells, mains hum. Seamless."""
    L = 10.0
    t = np.arange(int(L * SR)) / SR
    x = sum(np.sin(2 * np.pi * f * t + rng.random() * 6) * a for f, a in ((38.0, 1.0), (41.2, 0.8), (55.3, 0.5), (50.0, 0.25)))
    swell = 0.5 + 0.5 * np.sin(2 * np.pi * (2 / L) * t - 1.5)
    br = bp(white(len(t)), 180, 650) * swell * 1.4
    x = x * (0.8 + 0.2 * swell) + br
    x = tape(x, wow=0.01, loop=True) + hiss(len(t), 0.01)
    return normalize(x, 0.5)


def entity_step():
    """A heavy, soft weight settling on old floorboards: a muffled thud and
    the wood creaking under it (stick-slip pulses through a resonant band).
    No pitch, nothing cartoonish: it should sound like something big that
    is trying to be quiet."""
    n = int(0.7 * SR)
    t = np.arange(n) / SR
    thud = np.sin(2 * np.pi * (44 + 10 * np.exp(-t * 20)) * t) * np.exp(-t * 11)
    thud += lp(white(n), 160, 4) * np.exp(-t * 16) * 6
    pulses = (rng.random(n) < (40 + 25 * np.sin(2 * np.pi * 3 * t)) / SR).astype(float)
    creak_env = np.clip((t - 0.06) / 0.05, 0, 1) * np.exp(-np.maximum(0, t - 0.12) * 7)
    creak = bp(lp(pulses, 1800, 1), 380, 950) * creak_env * 9
    x = saturate(thud + creak, 1.6)
    x = echo(x, ((0.045, 0.25), (0.1, 0.12)))
    x = lp(x, 1800) + hiss(n, 0.004)
    return fade(normalize(x, 0.85), 4)


def filmed_sting(jingle_loop):
    """When the camcorder catches it: the show's song slows down and dies
    like a tape being stopped by hand, over a low thump. No whistles."""
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    src = np.roll(jingle_loop, -int(4.0 * SR))
    rate = np.clip(1.0 - t / 0.85, 0.0, 1.0) ** 1.6
    pos = np.cumsum(rate)
    x = np.interp(pos, np.arange(len(src)), src) * np.clip(rate * 3, 0, 1)
    x += np.sin(2 * np.pi * (34 + 20 * np.exp(-t * 8)) * t) * np.exp(-t * 4) * 0.7
    x += lp(white(n), 900) * np.exp(-t * 18) * 0.25
    x = lp(saturate(x, 1.5), 2600) + hiss(n, 0.006)
    return fade(normalize(x, 0.65), 8)


def caught(jingle_loop):
    """The screamer when it takes you: a blow that hits the whole speaker,
    its voice screaming the show's line right into the lens (the host, an
    octave below, a child's pitch in a giant's throat, shredded), the jingle
    racing underneath, the tape tearing in stutters, and at the end the
    tape stopping dead."""
    n = int(1.9 * SR)
    t = np.arange(n) / SR
    boom = (np.sin(2 * np.pi * np.cumsum(90 - 60 * np.minimum(t, 0.4) / 0.4) / SR) * np.exp(-t * 4.5) * 1.2
            + bp(white(n), 200, 3000) * np.exp(-t * 18) * 1.0)
    seg = [(ph, d * 0.55) for ph, d in LINE]
    shout = wrong_voice(seg, [(0, 380), (0.3, 470), (0.6, 420), (0.8, 520), (1, 260)], child=0.7, ring_hz=61, crush_bits=5, wow=0.03, stop=0.3)
    shout = np.concatenate([np.zeros(int(0.04 * SR)), normalize(shout, 1)])[:n]
    shout = np.pad(shout, (0, n - len(shout)))
    fast = np.interp(np.arange(n) * 1.9, np.arange(len(jingle_loop)), jingle_loop, period=len(jingle_loop))
    tear = bp(white(n), 800, 6000) * (np.sin(2 * np.pi * 18 * t) > 0.2) * 0.35
    x = boom + shout * 1.3 + fast * 0.45 + tear
    x *= np.minimum(1, t * 200)
    x = saturate(x, 3.0)
    x = tape_stop(x, 0.35)
    return np.clip(normalize(x, 1.0), -0.97, 0.97)


def show_theme():
    """The show as it was broadcast: the same tune, clean, at the right
    speed and ending where it should, with the host's cheerful greeting.
    Only a TV speaker colours it. Seamless loop."""
    step = 0.36
    melody = [72, 76, 79, 76, 77, 81, 79, -1, 76, 79, 84, 83, 81, 77, 79, -1,
              72, 76, 79, 76, 77, 74, 71, 72]
    bass = [48, 45, 41, 43, 48, 45]
    n = int(len(melody) * step * SR)
    out = np.zeros(n)

    def add(sig, start):
        idx = (np.arange(len(sig)) + int(start * SR)) % n
        np.add.at(out, idx, sig)

    for i, m in enumerate(melody):
        if m > 0:
            add(organ(440 * 2 ** ((m - 69) / 12), step * 1.4) * 0.5, i * step)
    bar = len(melody) * step / len(bass)
    for i, m in enumerate(bass):
        f = 440 * 2 ** ((m - 69) / 12)
        for k in range(4):
            add(organ(f, bar / 4 * 1.1, 0.002) * (0.3 if k % 2 == 0 else 0.2), i * bar + k * bar / 4)
    seg = [("_", 0.05), ("o", 0.18), ("l", 0.05), ("a", 0.22), ("_", 0.06), ("v", 0.05), ("e", 0.14),
           ("s", 0.08), ("i", 0.13), ("n", 0.05), ("i", 0.13), ("t", 0.04), ("o", 0.2), ("s", 0.12), ("_", 0.1)]
    host = formant_voice(seg, [(0, 190), (0.25, 240), (0.5, 210), (0.7, 250), (0.9, 220), (1, 200)])
    add(normalize(host, 1) * 0.7, 0.2)
    out = bp(saturate(normalize(out, 0.8), 1.2), 180, 5200)
    return normalize(out, 0.5)


def rage(jingle_loop):
    """All the tapes are gone: it screams. A long torn 'aaah' climbing out
    of an octave below, the show's song spun backwards and fast, a rumble."""
    n = int(3.0 * SR)
    t = np.arange(n) / SR
    seg = [("a", 2.6), ("_", 0.4)]
    f0 = [(0, 150), (0.25, 260), (0.6, 520), (0.85, 600), (1, 300)]
    v = normalize(formant_voice(seg, f0, 1.0, 1.15, stretch=1.0), 1) + normalize(formant_voice(seg, f0, 0.5, 0.9, stretch=1.0), 1) * 0.9
    v = saturate(v * 1.5, 6.0)
    spin = np.interp(np.arange(n) * 2.2, np.arange(len(jingle_loop)), jingle_loop[::-1], period=len(jingle_loop))
    rumble = lp(white(n), 120) * 6 + np.sin(2 * np.pi * 38 * t) * 0.6
    x = v * 0.9 + spin * 0.5 + rumble * 0.5 + hp(white(n), 2000) * 0.25
    x *= np.minimum(1, t * 30) * np.exp(-np.maximum(0, t - 2.3) * 5)
    x = echo(x, ((0.13, 0.4), (0.29, 0.25), (0.47, 0.15)))
    return np.clip(normalize(saturate(x, 2.0), 1.0), -0.95, 0.95)


def break_free():
    """Filmed, and it moves anyway: the tape snaps, a wet grunt."""
    n = int(0.8 * SR)
    t = np.arange(n) / SR
    snap = hp(white(n), 3000) * np.exp(-t * 30) * 1.5
    screech = np.sin(2 * np.pi * np.cumsum(3200 - 2600 * t / 0.8) / SR) * np.exp(-t * 6) * 0.3
    grunt = normalize(formant_voice([("o", 0.5), ("_", 0.3)], [(0, 90), (1, 60)], 1.0, 0.8), 1) * 0.8
    x = snap + screech + saturate(grunt, 3.0)
    return fade(normalize(lp(x, 6000), 0.85), 5)


def death_scream():
    """Someone being taken: a real-sounding scream, ragged, breaking, cut
    short. Dry, close, no music in it."""
    n = int(1.9 * SR)
    t = np.arange(n) / SR
    seg = [("a", 0.9), ("e", 0.6), ("a", 0.4)]
    f0 = [(0, 260), (0.1, 420), (0.35, 470), (0.55, 380), (0.7, 520), (0.85, 300), (1.0, 180)]
    v = formant_voice(seg, f0, 1.0, 1.08, stretch=1.0)
    v = normalize(v, 1) * (1 + 0.35 * white(n))  # roughness
    breath = bp(white(n), 1500, 5000) * 0.25
    x = saturate(v * 1.3 + breath, 3.0)
    x *= np.minimum(1, t * 25) * np.where(t < 1.55, 1.0, np.exp(-(t - 1.55) * 40))  # choked off
    return fade(normalize(lp(x, 7000), 0.9), 3)


def death_gore():
    """What happens to them: cloth tearing, bones going, something wet,
    a last thud. Raw and dry."""
    n = int(2.4 * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    # cloth tearing: rough high noise with a flutter
    tear = hp(white(n), 1800) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 38 * t))) * ((t > 0.15) & (t < 0.65))
    x += tear * 0.4
    for at in (0.55, 0.8, 1.05, 1.2, 1.5):  # bones
        k = int(at * SR)
        m = int(0.07 * SR)
        crack = bp(white(m), 1500, 6000) * np.exp(-np.arange(m) / SR * 70) * 1.6
        thump = np.sin(2 * np.pi * 70 * np.arange(m) / SR) * np.exp(-np.arange(m) / SR * 30) * 0.8
        x[k:k + m] += crack + thump
    wet_t = t[(t > 0.9) & (t < 2.0)] - 0.9
    wet = lp(white(len(wet_t)), 600) * 3.0 * (0.5 + 0.5 * np.sin(2 * np.pi * 6 * wet_t)) * np.exp(-wet_t * 1.5)
    x[(t > 0.9) & (t < 2.0)] += wet
    k = int(2.05 * SR)
    m = int(0.3 * SR)
    x[k:k + m] += (np.sin(2 * np.pi * 50 * np.arange(m) / SR) + lp(white(m), 300) * 3) * np.exp(-np.arange(m) / SR * 14)
    return fade(normalize(saturate(x, 1.5), 0.9), 3)


def laugh():
    """It laughs while it plays with the bodies: a cartoon giggle ('je je
    je') from the show, slowed, doubled an octave down, through the tape."""
    parts = []
    for k in range(6):
        f = 300 + k * 18
        seg = [("h", 0.05), ("e", 0.13), ("_", 0.07)]
        v = formant_voice(seg, [(0, f), (0.5, f * 1.15), (1, f * 0.9)], 0.75, 1.05)
        parts.append(v)
    v = np.concatenate(parts)
    low = np.concatenate([formant_voice([("h", 0.05), ("e", 0.13), ("_", 0.07)], [(0, 150), (1, 140)], 0.75, 0.85) for _ in range(6)])
    x = normalize(v, 1) * 0.8 + normalize(low[: len(v)], 1) * 0.7
    x = echo(saturate(x, 2.5), ((0.09, 0.35), (0.2, 0.2)))
    x = vhs_chain(x, wow=0.03, cutoff=3500, drops=1)
    return fade(normalize(x, 0.85), 10)


def body_thud():
    """A body hitting the floor: heavy, dull, a little bounce."""
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * (60 * np.exp(-t * 6) + 35) * t) * np.exp(-t * 9)
    x += lp(white(n), 400) * np.exp(-t * 18) * 3
    k = int(0.16 * SR)
    x[k:] += (np.sin(2 * np.pi * 70 * t[: n - k]) * np.exp(-t[: n - k] * 20) + lp(white(n - k), 500) * np.exp(-t[: n - k] * 30)) * 0.4
    return fade(normalize(saturate(x, 1.5), 0.9), 3)


def main() -> None:
    # The show's theme and the jingle are music: tools/gen_music.py (run it
    # first; the capture and the sting reuse the jingle).
    import wave
    with wave.open(str(OUT_DIR / "jingle.wav")) as w:
        j = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(float) / 32767
    write("voice_line", voice_line())
    write("voice_whisper", voice_whisper())
    write("voice_where", voice_where(0))
    write("voice_where2", voice_where(1))
    write("voice_where3", voice_where(2))
    write("voice_reverse", voice_reverse())
    write("intrusion_buzz", intrusion_buzz())
    write("voice_count", voice_count())
    write("voice_ready", voice_ready())
    write("voice_lost", voice_lost())
    write("voice_found", voice_found())
    write("voice_hum", voice_hum())
    write("voice_giggle", voice_giggle())
    write("drone", drone())
    write("entity_step", entity_step())
    write("filmed_sting", filmed_sting(j))
    write("caught", caught(j))
    write("rage", rage(j))
    write("break_free", break_free())
    write("death_scream", death_scream())
    write("death_gore", death_gore())
    write("laugh", laugh())
    write("body_thud", body_thud())
    write_variants()  # last: the finished takes (and second takes) over the single ones above
    write("flash_fire", flash_fire())
    write("wake_cry", wake_cry())
    write("neck_breath", neck_breath())
    write("chase_scream3", chase_scream(2))  # (takes 1 and 2: write_variants)
    write("flash_charge", flash_charge())


if __name__ == "__main__":
    main()
