"""Generates the prototype's placeholder sounds into game/assets/audio
(22 050 Hz mono WAV, deterministic). Original synthesis, safe for streaming;
to be replaced by recorded / designed audio once the direction is set.

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


def music_box() -> np.ndarray:
    """A children's-show tune on a worn music box, slightly detuned, with
    one wrong note at the end. Loops seamlessly (notes wrap around)."""
    melody = [72, 76, 79, 76, 77, 81, 79, -1, 76, 79, 84, 83, 81, 77, 79, -1,
              72, 76, 79, 76, 77, 74, 70, 72, -1, -1]
    step = 0.42
    n = int(len(melody) * step * SR)
    out = np.zeros(n)
    t = t_axis(2.5)
    for i, m in enumerate(melody):
        if m < 0:
            continue
        f = 440 * 2 ** ((m - 69) / 12) * 0.985
        wow = 1 + 0.006 * np.sin(2 * np.pi * 0.7 * (t + i * step))
        ph = 2 * np.pi * f * np.cumsum(wow) / SR
        tine = (np.sin(ph) * np.exp(-t * 3.2)
                + 0.35 * np.sin(2 * ph) * np.exp(-t * 6)
                + 0.12 * np.sin(5.4 * ph) * np.exp(-t * 12))
        start = int(i * step * SR)
        idx = (np.arange(len(t)) + start) % n
        np.add.at(out, idx, tine)
    out += lowpass(noise(n / SR), 0.3) * 0.02
    return normalize(out, 0.6)


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


def entity_step() -> np.ndarray:
    t = t_axis(0.45)
    x = np.sin(2 * np.pi * 48 * t) * np.exp(-t * 10)
    x += lowpass(noise(0.45), 0.06) * np.exp(-t * 14) * 2
    creak = np.sin(2 * np.pi * (320 + 60 * np.sin(2 * np.pi * 7 * t)) * t)
    x += creak * np.exp(-((t - 0.1) / 0.05) ** 2) * 0.25
    return fade(normalize(x, 0.9), 3)


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


def caught() -> np.ndarray:
    t = t_axis(1.4)
    x = noise(1.4) * 0.9
    x += np.sin(2 * np.pi * np.cumsum(120 - 80 * t / 1.4) / SR) * 0.6
    saw = ((np.cumsum(300 - 150 * t / 1.4 + 12 * np.sin(2 * np.pi * 9 * t)) / SR) % 1) * 2 - 1
    x += saw * 0.45 * np.exp(-t * 1.5)
    x *= np.minimum(1, t * 40) * np.exp(-np.maximum(0, t - 0.9) * 6)
    return np.clip(normalize(x, 1.2), -0.95, 0.95)


def main() -> None:
    print("audio ->", OUT)
    write("music_box", music_box())
    write("static", static())
    write("hum", hum())
    write("tv_tone", tv_tone())
    write("step", step())
    write("entity_step", entity_step())
    write("pickup", pickup())
    write("rec_beep", rec_beep())
    write("click", click())
    write("caught", caught())


if __name__ == "__main__":
    main()
