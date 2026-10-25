"""Music of the prototype, synthesised (original, safe for streaming).
References: the library muzak and sign-off music of local TV (Local 58),
the warm, sad ambient of Gemini Home Entertainment and the cheerful 80s
children's-show jingle, all played back from worn VHS: wow and flutter,
drags, dropouts, saturation, hiss, low-pass, a room around it.

  menu_theme      "Fin de emisión": slow e-piano chords, a pad, the show's
                  melody far away on a bell; nostalgic and wrong. ~60 s loop
  show_theme      ¡Hola, Vecinitos! as broadcast: bouncy bass, glockenspiel,
                  e-piano stabs, soft drums, the host's greeting. 16 s loop
  jingle          the same theme in the empty house: music box and e-piano
                  through a dying tape and a big room (the entity's song)
  house_ambience  room tone, wind outside, the house settling. 24 s loop

    python tools/gen_music.py     (then tools/gen_entity_audio.py, which
                                   reuses the jingle for the capture)
"""
import numpy as np
from scipy.signal import lfilter

from gen_audio import SR, normalize, write
from gen_entity_audio import bp, crush, dropouts, formant_voice, hiss, hp, lp, saturate, tape

rng = np.random.default_rng(1989)


def hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def t_of(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * SR)) / SR


# --- instruments ----------------------------------------------------------------

def epiano(f: float, dur: float, vel: float = 1.0) -> np.ndarray:
    """FM electric piano (a DX7-ish tine): bright attack, warm body."""
    t = t_of(dur + 1.2)
    index = 2.2 * np.exp(-t * 5.0) + 0.35
    out = np.zeros_like(t)
    for det in (0.9985, 1.0015):
        out += np.sin(2 * np.pi * f * det * t + index * np.sin(2 * np.pi * f * det * t))
    out += 0.25 * np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t * 9)  # tine
    env = np.minimum(1, t / 0.004) * np.exp(-t * 1.4)
    env *= np.clip((dur + 1.2 - t) / 0.4, 0, 1)
    return out * env * 0.5 * vel


def pad(f: float, dur: float) -> np.ndarray:
    """Detuned saws, filtered soft, slow in and out."""
    t = t_of(dur)
    out = np.zeros_like(t)
    for det in (0.994, 1.0, 1.006):
        for k in range(1, 9):
            out += np.sin(2 * np.pi * f * det * k * t + k) / k
    env = np.clip(t / 1.2, 0, 1) * np.clip((dur - t) / 1.5, 0, 1)
    return lp(out, 1400) * env * 0.12


def bell(f: float, dur: float = 2.5, vel: float = 1.0) -> np.ndarray:
    """Glockenspiel / music box tine."""
    t = t_of(dur)
    out = (np.sin(2 * np.pi * f * t) * np.exp(-t * 2.2)
           + 0.4 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 5)
           + 0.15 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 11))
    return out * np.minimum(1, t / 0.002) * 0.5 * vel


def bass(f: float, dur: float) -> np.ndarray:
    t = t_of(dur)
    out = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t) + 0.12 * np.sin(6 * np.pi * f * t)
    env = np.minimum(1, t / 0.006) * np.exp(-t * 3.0) * np.clip((dur - t) / 0.05, 0, 1)
    return out * env * 0.55


def kick() -> np.ndarray:
    t = t_of(0.3)
    f = 45 + 80 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 12) * 0.8


def snare() -> np.ndarray:
    t = t_of(0.22)
    n = rng.random(len(t)) * 2 - 1
    return (bp(n, 1200, 6000) * 1.2 + np.sin(2 * np.pi * 190 * t) * 0.5) * np.exp(-t * 18) * 0.5


def hat() -> np.ndarray:
    t = t_of(0.06)
    return hp(rng.random(len(t)) * 2 - 1, 7000) * np.exp(-t * 60) * 0.25


# --- mixing ------------------------------------------------------------------------

class Track:
    """A loop buffer: anything that runs past the end wraps to the start."""

    def __init__(self, seconds: float):
        self.n = int(seconds * SR)
        self.buf = np.zeros(self.n)

    def add(self, sig: np.ndarray, at: float, gain: float = 1.0) -> None:
        idx = (np.arange(len(sig)) + int(at * SR)) % self.n
        np.add.at(self.buf, idx, sig * gain)


def reverb(x: np.ndarray, size: float = 1.0, wet: float = 0.3, damp_hz: float = 4000) -> np.ndarray:
    """Freeverb-like: parallel feedback combs, then allpasses."""
    out = np.zeros_like(x)
    for d_ms, g in ((29.7, 0.84), (37.1, 0.83), (41.1, 0.82), (43.7, 0.81)):
        d = int(d_ms * size * SR / 1000)
        a = np.zeros(d + 1)
        a[0], a[d] = 1.0, -g
        out += lfilter([1.0], a, np.concatenate([np.zeros(d), x])[: len(x)])
    out = lp(out, damp_hz)
    for d_ms, g in ((5.0, 0.7), (1.7, 0.7)):
        d = int(d_ms * SR / 1000)
        b = np.zeros(d + 1)
        a = np.zeros(d + 1)
        b[0], b[d] = -g, 1.0
        a[0], a[d] = 1.0, -g
        out = lfilter(b, a, out)
    return x * (1 - wet) + out * wet * 0.25


def looped(fn, x: np.ndarray) -> np.ndarray:
    """Apply a filter chain to a loop without a click at the seam."""
    n = len(x)
    return fn(np.tile(x, 3))[n:2 * n]


# --- pieces --------------------------------------------------------------------------

MELODY = [72, 76, 79, 76, 77, 81, 79, None, 76, 79, 84, 83, 81, 77, 79, None,
          72, 76, 79, 76, 77, 74, 71, 72]


def menu_theme() -> np.ndarray:
    bpm = 64
    beat = 60 / bpm
    bar = beat * 4
    chords = [[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [53, 56, 60, 62],
              [52, 55, 59, 62], [50, 53, 57, 60], [55, 60, 62, 65], [55, 59, 62, 65]]
    roots = [36, 33, 29, 29, 28, 26, 31, 31]
    bars = len(chords) * 2
    tr = Track(bars * bar)
    for b in range(bars):
        ch = chords[b % len(chords)]
        t0 = b * bar
        tr.add(pad(hz(ch[0] - 12), bar + 1.0) + pad(hz(ch[2]), bar + 1.0), t0)
        tr.add(bass(hz(roots[b % len(roots)]), bar * 0.95), t0, 0.7)
        for k, at in enumerate((0.0, beat * 1.5, beat * 2.0, beat * 3.5)):
            vel = (0.9, 0.5, 0.75, 0.45)[k]
            for i, m in enumerate(ch):
                tr.add(epiano(hz(m), beat * 1.2, vel), t0 + at + i * 0.012)
    # The show's melody, far away on a bell, slowed, in the second half.
    start = len(chords) * bar
    for i, m in enumerate(MELODY):
        if m is not None:
            tr.add(bell(hz(m + 12) * 0.995), start + i * beat * 0.75, 0.35)
    x = normalize(tr.buf, 0.8)
    x = looped(lambda y: reverb(y, 1.6, 0.45, 3500), x)
    x = tape(x, wow=0.007, drags=[(len(x) / SR * 0.71, 0.06, 0.6)], loop=True)
    x = looped(lambda y: lp(saturate(y, 1.3), 5500), x)
    x = dropouts(x, 2, loop=True) + hiss(len(x), 0.008)
    return normalize(x, 0.55)


def show_theme() -> np.ndarray:
    bpm = 120
    beat = 60 / bpm
    bar = beat * 4
    chords = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62],
              [60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]]
    roots = [48, 45, 41, 43, 48, 45, 41, 43]
    tr = Track(len(chords) * bar)
    for b, ch in enumerate(chords):
        t0 = b * bar
        r = roots[b]
        for k, m in enumerate((r, r + 7, r + 12, r + 7)):
            tr.add(bass(hz(m), beat * 0.9), t0 + k * beat, 0.8)
        for k in range(4):
            for i, m in enumerate(ch):
                tr.add(epiano(hz(m), beat * 0.25, 0.55), t0 + k * beat + beat * 0.5 + i * 0.004)
        for k in range(4):
            tr.add(kick() if k % 2 == 0 else snare(), t0 + k * beat)
        for k in range(8):
            tr.add(hat(), t0 + k * beat * 0.5, 0.8 if k % 2 else 0.5)
    for rep in range(2):
        for i, m in enumerate(MELODY):
            if m is not None:
                tr.add(bell(hz(m + 12), 1.2), rep * 4 * bar + i * beat * 0.5, 0.9)
    seg = [("_", 0.05), ("o", 0.18), ("l", 0.05), ("a", 0.22), ("_", 0.06), ("v", 0.05), ("e", 0.14),
           ("s", 0.08), ("i", 0.13), ("n", 0.05), ("i", 0.13), ("t", 0.04), ("o", 0.2), ("s", 0.12), ("_", 0.1)]
    host = formant_voice(seg, [(0, 190), (0.25, 240), (0.5, 210), (0.7, 250), (0.9, 220), (1, 200)])
    tr.add(normalize(host, 1), 0.1, 0.55)
    x = normalize(tr.buf, 0.8)
    x = looped(lambda y: bp(saturate(reverb(y, 0.6, 0.15), 1.25), 150, 6500), x)
    return normalize(x + hiss(len(x), 0.004), 0.5)


def jingle() -> np.ndarray:
    step = 0.5
    notes = MELODY + [66, None, 63, None]
    tr = Track(len(notes) * step)
    detune = 0.82
    for i, m in enumerate(notes):
        if m is None:
            continue
        f = hz(m) * detune
        tr.add(bell(f * 2, 2.5), i * step, 0.8)
        tr.add(epiano(f, step * 1.5, 0.45), i * step + 0.01)
    for b, r in enumerate([48, 45, 41, 43, 48, 45, 41, 42]):
        tr.add(epiano(hz(r) * detune, 1.6, 0.4), b * len(notes) * step / 8)
    x = normalize(tr.buf, 0.8)
    x = looped(lambda y: reverb(y, 2.2, 0.55, 2500), x)
    x = tape(x, wow=0.022, drags=[(10.2, 0.28, 0.45), (3.1, 0.08, 0.2)], loop=True)
    x = looped(lambda y: lp(crush(saturate(y, 1.7), 8, 0.3), 2800), x)
    x = dropouts(x, 3, loop=True) + hiss(len(x), 0.015)
    return normalize(x, 0.55)


def house_ambience() -> np.ndarray:
    L = 24.0
    n = int(L * SR)
    t = np.arange(n) / SR
    hum = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((50, 1.0), (100, 0.4), (150, 0.15))) * 0.04
    wind = looped(lambda y: bp(y, 200, 900), rng.random(n) * 2 - 1) * (0.5 + 0.5 * np.sin(2 * np.pi * (2 / L) * t) ** 2) * 0.5
    x = hum + wind
    tr = Track(L)
    tr.buf = x
    for _ in range(5):  # the house settling: a creak here and there
        d = 0.4
        tt = t_of(d)
        pulses = (rng.random(len(tt)) < 50 / SR).astype(float)
        creak = bp(lp(pulses, 1500, 1), 300, 800) * np.exp(-((tt - 0.2) / 0.12) ** 2) * 6
        tr.add(creak, rng.uniform(0, L), rng.uniform(0.3, 0.8))
    x = looped(lambda y: reverb(y, 1.4, 0.4, 2000), tr.buf)
    return normalize(x + hiss(n, 0.004), 0.35)


def main() -> None:
    write("menu_theme", menu_theme())
    write("show_theme", show_theme())
    write("jingle", jingle())
    write("house_ambience", house_ambience())


if __name__ == "__main__":
    main()
