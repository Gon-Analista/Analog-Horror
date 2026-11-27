"""Sounds of the second night (Canal 9's studios) and of The Husk, the
empty Vecinito costume, into game/assets/audio. Same recipes as the
Visita's (tools/gen_entity_audio.py): everything as if played from a worn
tape, nothing clean. The Husk is not a voice: it is fur, stuffing, padded
feet, and the pull-string voice box sewn into its chest, dying.

    python tools/gen_husk_audio.py      (requires scipy)
"""
import numpy as np

import gen_entity_audio as ea
from gen_audio import SR, fade, normalize, write
from gen_entity_audio import bp, crush, echo, finish, formant_voice, hiss, hp, lp, saturate, tape, tape_stop, white


def _seed(k: int) -> None:
    ea.rng = np.random.default_rng(5200 + k)


def husk_rustle() -> np.ndarray:
    """A loop, while it moves (only when nobody is looking): fur dragging
    against fur at a walking pace, the stuffing inside crunching, and the
    plastic eyes ticking against the head. Seamless."""
    L = 4.0
    n = int(L * SR)
    t = np.arange(n) / SR
    pace = 2.0  # steps per second, a whole number of them in the loop
    phase = (t * pace) % 1.0
    swish_env = np.exp(-((phase - 0.35) / 0.16) ** 2) + 0.35 * np.exp(-((phase - 0.85) / 0.1) ** 2)
    swish = bp(white(n), 900, 5200) * swish_env * (0.7 + 0.3 * np.sin(2 * np.pi * 0.5 * t) ** 2)
    rub = lp(white(n), 700, 2) * (0.4 + 0.6 * swish_env) * 0.7
    crack = (ea.rng.random(n) < (90 * swish_env + 8) / SR).astype(float) * ea.rng.uniform(0.3, 1.0, n)
    crunch = bp(crack, 1400, 4800) * 3.0
    tick = np.zeros(n)
    for k in range(int(L * pace)):
        at = int(((k + 0.36) / pace) * SR)
        m = int(0.012 * SR)
        tick[at:at + m] += np.sin(2 * np.pi * 2300 * np.arange(m) / SR) * np.exp(-np.arange(m) / (0.003 * SR)) * 0.6
    x = swish * 1.2 + rub + crunch + tick
    x = tape(x, wow=0.008, loop=True)
    x = lp(np.tile(x, 3), 6000)[n:2 * n] + hiss(n, 0.006)
    return normalize(x, 0.55)


def husk_step() -> np.ndarray:
    """A padded foot put down: soft, hollow, too light for its size (there
    is nobody in it), a wooden heel plate knocking inside."""
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    pad = lp(white(n), 380, 3) * np.exp(-t * 26) * 7
    hollow = np.sin(2 * np.pi * (150 + 40 * np.exp(-t * 30)) * t) * np.exp(-t * 22) * 0.6
    knock = bp(white(n), 900, 2400) * np.exp(-np.maximum(0, t - 0.03) * 70) * (t > 0.03) * 0.9
    x = saturate(pad + hollow + knock, 1.4)
    x = echo(x, ((0.05, 0.25), (0.11, 0.12)))
    return fade(normalize(lp(x, 3000), 0.8), 3)


HOLA = [("_", 0.04), ("h", 0.06), ("o", 0.2), ("l", 0.07), ("a", 0.22), ("_", 0.12),
        ("v", 0.06), ("e", 0.14), ("s", 0.1), ("i", 0.12), ("n", 0.06), ("i", 0.13), ("t", 0.04), ("o", 0.5), ("_", 0.1)]
LINE = [("_", 0.04), ("t", 0.05), ("e", 0.2), ("s", 0.12), ("t", 0.05), ("o", 0.2), ("i", 0.16), ("_", 0.1),
        ("v", 0.07), ("i", 0.12), ("e", 0.24), ("n", 0.08), ("t", 0.04), ("o", 0.6), ("_", 0.1)]


def _ratchet(seconds: float) -> np.ndarray:
    """The pull string running back in: a plastic ratchet buzzing down."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rate = 70 * (1 - t / seconds) ** 0.6 + 12
    clicks = (np.diff(np.floor(np.cumsum(rate) / SR), prepend=0) > 0).astype(float)
    return bp(clicks, 1200, 5000) * 2.2 * (0.6 + 0.4 * (1 - t / seconds))


def husk_voicebox(variant=0) -> np.ndarray:
    """The pull-string voice box sewn into its chest, from the show's
    merchandise: a cartoon voice from a tiny speaker ('¡hola, vecinito!' or
    '¡te estoy viendo!'), the motor dragging so the words sag and stop,
    muffled through the fur. It is the only thing it says."""
    seg, f0 = (HOLA, [(0, 330), (0.2, 390), (0.4, 300), (0.6, 420), (0.85, 360), (1.0, 250)]) if variant == 0 else \
        (LINE, [(0, 360), (0.2, 420), (0.4, 330), (0.6, 400), (0.8, 300), (1.0, 220)])
    v = formant_voice(seg, f0, 1.0, 1.25, stretch=1.0)
    v = bp(normalize(v, 1), 550, 3400, 3)  # a speaker the size of a coin
    v = crush(saturate(v, 2.4), 5, 0.5)
    drag = len(v) / SR * (0.55 if variant == 0 else 0.4)
    v = tape(v, wow=0.06, flutter=0.01, drags=[(drag, 0.35, 0.18)])
    v = tape_stop(v, 0.55)
    v = lp(v, 1900)  # through the fur
    x = np.concatenate([_ratchet(0.35) * 0.35, np.zeros(int(0.05 * SR)), v])
    x = x + hiss(len(x), 0.01)
    return finish(fade(x, 10), 0.7, 0.4, ((0.03, 0.2), (0.07, 0.1)))


def husk_breath() -> np.ndarray:
    """A loop, up close while it stands still: breathing inside the head,
    muffled by the fur and the foam. There is nobody in there."""
    _seed(40)
    x = ea.neck_breath()
    x = lp(x, 1100, 3) * 1.6 + bp(x, 280, 900) * 0.8
    x = echo(x, ((0.012, 0.5), (0.025, 0.3)))  # the inside of the head: tiny and hollow
    return normalize(x, 0.5)


def husk_settle() -> np.ndarray:
    """It stops: the costume settling around nothing, a soft collapse of
    fabric and the eyes clicking once."""
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    flump = lp(white(n), 900, 2) * np.exp(-t * 9) * np.clip(t / 0.02, 0, 1) * 1.2
    fabric = bp(white(n), 1500, 5000) * np.exp(-t * 14) * 0.4
    m = int(0.01 * SR)
    click = np.zeros(n)
    at = int(0.16 * SR)
    click[at:at + m] = np.sin(2 * np.pi * 2600 * np.arange(m) / SR) * np.exp(-np.arange(m) / (0.002 * SR))
    x = flump + fabric + click * 0.5
    return fade(normalize(lp(x, 5000), 0.6), 4)


def husk_wake() -> np.ndarray:
    """The costume rack in the wardrobe: hangers ringing and sliding as
    something gets down from one, a heavy fall of fur, and then the voice
    box, slowed to a groan."""
    _seed(60)
    n = int(2.4 * SR)
    t = np.arange(n) / SR
    hangers = np.zeros(n)
    for _ in range(14):
        at = int(ea.rng.uniform(0.0, 0.9) * SR)
        f = ea.rng.uniform(1800, 4200)
        m = int(0.4 * SR)
        k = np.arange(m) / SR
        tone = (np.sin(2 * np.pi * f * k) + 0.5 * np.sin(2 * np.pi * f * 2.76 * k)) * np.exp(-k * ea.rng.uniform(8, 14))
        hangers[at:at + m] += tone[: n - at] * ea.rng.uniform(0.2, 0.5)
    slide = bp(white(n), 2500, 7000) * np.exp(-((t - 0.45) / 0.3) ** 2) * 0.5
    fall = lp(white(n), 300, 3) * np.exp(-np.maximum(0, t - 1.0) * 6) * (t > 1.0) * 5
    x = hangers + slide + fall
    vb = husk_voicebox(0)
    vb = tape(vb, wow=0.0, drags=[(len(vb) / SR * 0.5, 0.45, 0.6)])  # a groan
    out = np.concatenate([x, np.zeros(int(0.4 * SR))])
    out = np.concatenate([out, vb * 0.8])
    out = echo(out, ((0.17, 0.3), (0.33, 0.18), (0.51, 0.1)))  # a long corridor
    return finish(lp(out, 5000), 0.8, 0.6)


def pa_chime() -> np.ndarray:
    """The building's public address: the three-note chime before an
    announcement, from ceiling speakers down a concrete corridor, then the
    hum of the open line."""
    notes = (659.3, 523.3, 392.0)
    parts = []
    for i, f in enumerate(notes):
        n = int((0.55 if i < 2 else 1.1) * SR)
        k = np.arange(n) / SR
        tone = np.sin(2 * np.pi * f * k) + 0.35 * np.sin(2 * np.pi * f * 4.0 * k) * np.exp(-k * 9) + 0.2 * np.sin(2 * np.pi * f * 2 * k)
        parts.append(tone * np.exp(-k * 2.2) * np.clip(k / 0.004, 0, 1))
    x = np.concatenate(parts)
    line = np.arange(int(1.6 * SR)) / SR
    hum = (np.sin(2 * np.pi * 50 * line) * 0.3 + np.sin(2 * np.pi * 150 * line) * 0.15) * 0.25 + hiss(len(line), 0.03)
    x = np.concatenate([x * 0.8, hum * np.clip(1 - line / 1.6, 0, 1)])
    x = bp(saturate(x, 1.8), 350, 4000, 2)  # a cheap ceiling speaker
    x = tape(x, wow=0.006)
    x = echo(x, ((0.09, 0.4), (0.19, 0.25), (0.31, 0.14), (0.47, 0.08)))
    return finish(x, 0.6, 0.4)


# "Atención, personal del canal nueve..." as heard from the corridor: the
# words are there, you cannot quite make them out.
PA_WORDS = [("_", 0.08), ("a", 0.1), ("t", 0.04), ("e", 0.1), ("n", 0.06), ("s", 0.08), ("i", 0.08), ("o", 0.16), ("n", 0.1), ("_", 0.2),
            ("t", 0.04), ("e", 0.1), ("l", 0.05), ("s", 0.08), ("o", 0.1), ("n", 0.06), ("a", 0.12), ("l", 0.08), ("_", 0.1),
            ("t", 0.04), ("e", 0.08), ("l", 0.06), ("t", 0.04), ("a", 0.12), ("n", 0.06), ("a", 0.12), ("l", 0.1), ("_", 0.1),
            ("n", 0.06), ("u", 0.08), ("e", 0.12), ("v", 0.06), ("e", 0.2), ("_", 0.3),
            ("m", 0.05), ("a", 0.1), ("s", 0.08), ("t", 0.04), ("e", 0.12), ("l", 0.05), ("e", 0.1), ("s", 0.1), ("_", 0.12),
            ("a", 0.08), ("l", 0.06), ("m", 0.06), ("u", 0.1), ("e", 0.1), ("l", 0.06), ("e", 0.24), ("_", 0.2)]


def pa_voice() -> np.ndarray:
    """An announcement through the ceiling speakers: a flat man's voice,
    reading, the words smeared by the corridor's echo and a speaker that
    buzzes; you get the tone of it, not the words (the subtitle has them)."""
    _seed(70)
    f0 = [(0, 128), (0.2, 122), (0.45, 126), (0.5, 118), (0.75, 124), (1.0, 104)]
    v = formant_voice(PA_WORDS, f0, 1.0, 1.0, stretch=1.0)
    v = bp(normalize(v, 1), 380, 3200, 3)
    v = crush(saturate(v, 2.0), 6, 0.6)
    v = tape(v, wow=0.01)
    hum = np.arange(len(v)) / SR
    v = v + (np.sin(2 * np.pi * 50 * hum) * 0.04 + hiss(len(v), 0.02))
    v = echo(v, ((0.09, 0.45), (0.19, 0.3), (0.31, 0.18), (0.47, 0.1)))
    return finish(fade(v, 20), 0.6, 0.4)


def station_ambience() -> np.ndarray:
    """The building at night (a loop): the hum of the fluorescent ballasts,
    the air handling breathing through the ducts, a relay clicking in a
    rack far off. Seamless."""
    L = 12.0
    n = int(L * SR)
    t = np.arange(n) / SR
    hum = sum(np.sin(2 * np.pi * f * t + ea.rng.random() * 6) * a for f, a in ((100.0, 0.5), (200.0, 0.25), (300.0, 0.12), (50.0, 0.2)))
    hum *= 0.6 + 0.4 * np.sin(2 * np.pi * (1 / L) * t) ** 2
    air = lp(white(n), 500, 2) * (0.8 + 0.2 * np.sin(2 * np.pi * (3 / L) * t)) * 1.4
    x = hum * 0.4 + air
    for _ in range(4):
        at = int(ea.rng.uniform(0.5, L - 0.5) * SR)
        m = int(0.05 * SR)
        x[at:at + m] += bp(white(m), 1500, 4000) * np.exp(-np.arange(m) / (0.006 * SR)) * 0.5
    x = tape(x, wow=0.004, loop=True)
    x = lp(np.tile(x, 3), 3500)[n:2 * n] + hiss(n, 0.004)
    return normalize(x, 0.45)


def main() -> None:
    _seed(1)
    write("husk_rustle", husk_rustle())
    _seed(2)
    write("husk_step", husk_step())
    _seed(3)
    write("husk_voicebox", husk_voicebox(0))
    _seed(4)
    write("husk_voicebox2", husk_voicebox(1))
    write("husk_breath", husk_breath())
    _seed(5)
    write("husk_settle", husk_settle())
    write("husk_wake", husk_wake())
    _seed(7)
    write("pa_chime", pa_chime())
    _seed(8)
    write("station_ambience", station_ambience())
    write("pa_voice", pa_voice())


if __name__ == "__main__":
    main()
