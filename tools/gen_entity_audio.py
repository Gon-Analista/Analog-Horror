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
    """¡Hola, Vecinitos! theme: a cheap toy organ, a cheerful bass, and a
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


def formant_voice(segments, f0_points, f0_scale=1.0, formant_scale=1.0, whisper=False):
    """Source-filter synthesis: a glottal buzz (or breath) through three
    resonators whose frequencies glide from phoneme to phoneme.
    segments: [(phoneme, seconds)]; phonemes are FORMANTS keys plus
    'h' (breath on the next vowel), 's' (hiss), 't' (stop), '_' (silence).
    f0_points: [(fraction of the line 0..1, Hz)]."""
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


HOLA = [("_", 0.05), ("h", 0.12), ("o", 0.34), ("l", 0.08), ("a", 0.42), ("_", 0.12),
        ("v", 0.08), ("e", 0.26), ("s", 0.14), ("i", 0.24), ("n", 0.08), ("i", 0.24),
        ("t", 0.06), ("o", 0.8), ("_", 0.25)]
HOLA_F0 = [(0, 128), (0.12, 132), (0.25, 168), (0.35, 150), (0.5, 140), (0.6, 160),
           (0.7, 172), (0.78, 140), (0.92, 82), (1.0, 60)]


def voice_hola():
    """'Hola, vecinito': the host's cheerful greeting, pitched down, doubled
    an octave below, through a worn tape and a small room."""
    host = formant_voice(HOLA, HOLA_F0, 0.8, 0.95)
    low = formant_voice(HOLA, HOLA_F0, 0.4, 0.82)
    high = formant_voice(HOLA, HOLA_F0, 1.19, 1.05)
    v = normalize(host, 1) * 0.6 + normalize(low, 1) * 0.8 + normalize(high, 1) * 0.12
    v = crush(saturate(v, 2.2), 7, 0.4)
    v = echo(v)
    v = vhs_chain(v, wow=0.025, drags=[(len(v) / SR * 0.85, 0.2, 0.25)], cutoff=3000, drops=1)
    return fade(normalize(v, 0.8), 20)


def voice_whisper():
    """'ve-ci-ni-to...' breathed, close, too slow."""
    seg = [("_", 0.05), ("v", 0.1), ("e", 0.3), ("s", 0.2), ("i", 0.3), ("n", 0.1), ("i", 0.3),
           ("t", 0.07), ("o", 0.6), ("_", 0.3)]
    w = formant_voice(seg, [(0, 100), (1, 100)], 1.0, 1.0, whisper=True)
    w = hp(w, 300)
    w = echo(normalize(w, 1), ((0.07, 0.4), (0.15, 0.25)))
    w = vhs_chain(w, wow=0.02, cutoff=4500, drops=0)
    return fade(normalize(w, 0.7), 20)


def scream():
    """'¡VECINITO!' shouted, clipped."""
    seg = [("v", 0.05), ("e", 0.16), ("s", 0.08), ("i", 0.14), ("n", 0.05), ("i", 0.14), ("t", 0.04), ("o", 0.5)]
    f0 = [(0, 260), (0.4, 330), (0.7, 380), (1, 190)]
    v = normalize(formant_voice(seg, f0, 1.0, 1.1), 1) + normalize(formant_voice(seg, f0, 0.5, 0.9), 1) * 0.8
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
    """The capture: the scream, the jingle racing, everything clipping."""
    n = int(1.8 * SR)
    t = np.arange(n) / SR
    fast = np.interp(np.arange(n) * 1.7, np.arange(len(jingle_loop)), jingle_loop, period=len(jingle_loop))
    sc = scream()
    x = white(n) * 0.7 + fast * 0.8
    x[: len(sc)] += sc[:n] * 1.2
    x += np.sin(2 * np.pi * np.cumsum(110 - 70 * t / 1.8) / SR) * 0.6
    x *= np.minimum(1, t * 50) * np.exp(-np.maximum(0, t - 1.2) * 6)
    return np.clip(normalize(saturate(x, 2.5), 1.0), -0.95, 0.95)


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


def main() -> None:
    # The show's theme and the jingle are music: tools/gen_music.py (run it
    # first; the capture and the sting reuse the jingle).
    import wave
    with wave.open(str(OUT_DIR / "jingle.wav")) as w:
        j = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(float) / 32767
    write("voice_hola", voice_hola())
    write("voice_whisper", voice_whisper())
    write("drone", drone())
    write("entity_step", entity_step())
    write("filmed_sting", filmed_sting(j))
    write("caught", caught(j))


if __name__ == "__main__":
    main()
