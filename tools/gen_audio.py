"""Generates the prototype's placeholder sounds into game/assets/audio
(22 050 Hz mono WAV, deterministic). Original synthesis, safe for streaming;
to be replaced by recorded / designed audio once the direction is set.
The entity's sounds are in gen_entity_audio.py.

    python tools/gen_audio.py
"""
import wave
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "audio"
SR = 22050
rng = np.random.default_rng(1014)


def write(name: str, x: np.ndarray) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("  ", name, f"{len(x) / SR:.2f}s")


def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * SR)) / SR


def lowpass(x: np.ndarray, a: float) -> np.ndarray:
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def noise(seconds: float) -> np.ndarray:
    return rng.random(int(seconds * SR)) * 2 - 1


def normalize(x: np.ndarray, peak: float) -> np.ndarray:
    return x / max(np.abs(x).max(), 1e-6) * peak


def fade(x: np.ndarray, ms: float = 5) -> np.ndarray:
    n = int(ms * SR / 1000)
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x



def static() -> np.ndarray:
    x = noise(2.0)
    return normalize(x * 0.6 + lowpass(x, 0.2) * 0.8, 0.5)


def hum() -> np.ndarray:
    t = t_axis(4.0)
    x = (np.sin(2 * np.pi * 60 * t) + 0.5 * np.sin(2 * np.pi * 120 * t)
         + 0.25 * np.sin(2 * np.pi * 180 * t))
    x += lowpass(noise(4.0), 0.05) * 0.4
    return normalize(x, 0.18)


def tv_tone() -> np.ndarray:
    t = t_axis(4.0)
    tone = (np.sin(2 * np.pi * 853 * t) + np.sin(2 * np.pi * 960 * t)) * (t < 1.0)
    tone[: int(SR * 1.0)] = fade(tone[: int(SR * 1.0)], 20)
    x = tone * 0.5 + lowpass(noise(4.0), 0.4) * 0.15
    return normalize(x, 0.3)


def step() -> np.ndarray:
    t = t_axis(0.18)
    x = lowpass(noise(0.18), 0.08) * np.exp(-t * 35) * 3 + np.sin(2 * np.pi * 80 * t) * np.exp(-t * 30) * 0.6
    return fade(normalize(x, 0.7), 2)



def pickup() -> np.ndarray:
    t = t_axis(0.16)
    x = np.zeros_like(t)
    for at in (0.0, 0.07):
        n = noise(0.006)
        i = int(at * SR)
        x[i:i + len(n)] += n - lowpass(n, 0.2)
    x += np.sin(2 * np.pi * 1200 * t) * np.exp(-t * 60) * 0.3
    return fade(normalize(x, 0.6), 1)


def rec_beep() -> np.ndarray:
    t = t_axis(0.09)
    s = np.sin(2 * np.pi * 2000 * t)
    return fade(normalize(s * 0.7 + np.sign(s) * 0.3, 0.3), 4)


def click() -> np.ndarray:
    n = noise(0.03)
    t = t_axis(0.03)
    return fade(normalize((n - lowpass(n, 0.3)) * np.exp(-t * 120), 0.5), 1)



def van_horn() -> np.ndarray:
    """The van outside: two short honks, muffled by the door."""
    t = t_axis(1.3)
    tone = np.sign(np.sin(2 * np.pi * 380 * t)) + np.sign(np.sin(2 * np.pi * 472 * t))
    env = ((t > 0.02) & (t < 0.32)) | ((t > 0.5) & (t < 0.95))
    x = lowpass(tone * env * 0.5, 0.12)
    x = x + np.concatenate([np.zeros(int(0.09 * SR)), x[: -int(0.09 * SR)]]) * 0.3
    return fade(normalize(x, 0.7), 10)


def tape_whir() -> np.ndarray:
    """A VHS rewinding somewhere: motor whine with flutter, ticking reels.
    Each tape in the house plays it, so you can find them by ear."""
    t = t_axis(3.0)
    f = 140 * (1 + 0.01 * np.sin(2 * np.pi * 7 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) * 0.4 + np.sin(2 * ph) * 0.25 + np.sin(3.02 * ph) * 0.1
    x += (lowpass(noise(3.0), 0.3) - lowpass(noise(3.0), 0.05)) * 0.3
    ticks = (np.sin(2 * np.pi * 4 * t) > 0.995).astype(float)
    x += lowpass(ticks, 0.5) * 2.0
    return normalize(x, 0.4)


def power_down() -> np.ndarray:
    """The power goes: a relay clack, the mains hum sinking into nothing."""
    t = t_axis(1.8)
    f = 120 * np.exp(-t * 2.2) + 8
    hum = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 1.6) * 0.6
    clack = lowpass(noise(1.8), 0.2) * np.exp(-t * 40) * 2.5
    thump = np.sin(2 * np.pi * 50 * t) * np.exp(-t * 9) * 0.7
    return fade(normalize(hum + clack + thump, 0.85), 5)


def window_slide() -> np.ndarray:
    """An old sash pushed up: wood dragging in its runners in jerks, the
    glass buzzing in its putty, a knock as it stops."""
    t = t_axis(0.9)
    jerks = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (5 + 4 * t) * t))
    drag = lowpass(noise(0.9), 0.08) * jerks * np.clip(1 - t / 0.75, 0, 1)
    squeal = np.sin(2 * np.pi * (620 + 140 * np.sin(t * 9)) * t) * 0.18 * (np.sin(t * 23) > 0.4) * np.clip(1 - t / 0.7, 0, 1)
    rattle = lowpass(noise(0.9), 0.5) * 0.25 * (np.sin(2 * np.pi * 31 * t) > 0.6)
    knock = np.zeros_like(t)
    k0 = int(0.74 * SR)
    kt = t[: len(t) - k0]
    knock[k0:] = np.sin(2 * np.pi * 140 * kt) * np.exp(-kt * 38) * 1.2 + lowpass(noise(len(kt) / SR), 0.3) * np.exp(-kt * 60)
    return fade(normalize(drag + squeal + rattle + knock, 0.7), 8)


def window_shut() -> np.ndarray:
    """The sash brought down: a shorter drag, then a bang and the panes
    rattling in the frame."""
    t = t_axis(0.7)
    drag = lowpass(noise(0.7), 0.1) * np.clip(1 - t / 0.35, 0, 1)
    bang = np.zeros_like(t)
    k0 = int(0.33 * SR)
    kt = t[: len(t) - k0]
    bang[k0:] = np.sin(2 * np.pi * 110 * kt) * np.exp(-kt * 25) * 1.4 + lowpass(noise(len(kt) / SR), 0.4) * np.exp(-kt * 30)
    bang[k0:] += np.sin(2 * np.pi * 1900 * kt) * 0.15 * np.exp(-kt * 12) * (np.sin(2 * np.pi * 37 * kt) > 0)
    return fade(normalize(drag * 0.5 + bang, 0.75), 6)


def wind_draft() -> np.ndarray:
    """Night air through an open window (loops): low rushing wind that
    swells and falls, a whistle in the gap now and then."""
    secs = 6.0
    t = t_axis(secs)
    rush = lowpass(lowpass(noise(secs), 0.03), 0.05)
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * t / secs) * np.sin(2 * np.pi * 2 * t / secs + 1)
    whistle = np.sin(2 * np.pi * (880 + 60 * np.sin(2 * np.pi * t / secs)) * t) * 0.04 * np.clip(np.sin(2 * np.pi * 3 * t / secs), 0, 1) ** 3
    x = rush * swell / max(np.abs(rush).max(), 1e-6) + whistle
    n = int(0.25 * SR)  # crossfade the ends so it loops
    x[:n] = x[:n] * np.linspace(0, 1, n) + x[-n:] * np.linspace(1, 0, n)
    return normalize(x[:-n], 0.5)


def main() -> None:
    print("audio ->", OUT)
    write("static", static())
    write("hum", hum())
    write("tv_tone", tv_tone())
    write("step", step())
    write("pickup", pickup())
    write("rec_beep", rec_beep())
    write("click", click())
    write("van_horn", van_horn())
    write("tape_whir", tape_whir())
    write("power_down", power_down())
    write("window_slide", window_slide())
    write("window_shut", window_shut())
    write("wind_draft", wind_draft())


if __name__ == "__main__":
    main()
