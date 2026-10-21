#!/usr/bin/env python3
"""The page-turn sound (switching workspace), made from noise.

    python3 tools/make_page_sound.py

A soft paper swish: lifted and swept over (left to right), laid down with a
fainter brush, a few small crinkles; peak -15 dBFS. Writes
dotfiles/.local/share/sounds/archive/stereo/page-turn.oga (needs ffmpeg with
libvorbis). Replace it with a recording of your own through
archive-sound-prep recording.wav page.
"""
import pathlib
import subprocess
import tempfile
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
DST = ROOT / "dotfiles/.local/share/sounds/archive/stereo/page-turn.oga"
SR, T = 48000, 0.46


def band(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    w = np.clip((f - lo) / (lo * 0.5), 0, 1) * np.clip((hi - f) / (hi * 0.3), 0, 1)
    return np.fft.irfft(X * w, len(x))


def main():
    n = int(SR * T)
    rng = np.random.default_rng(12)
    t = np.arange(n) / SR
    noise = band(rng.standard_normal(n), 900, 7000)
    env = np.exp(-((t - 0.13) / 0.075) ** 2) + 0.55 * np.exp(-((t - 0.34) / 0.035) ** 2)
    env *= np.clip(t / 0.02, 0, 1) * np.clip((T - t) / 0.05, 0, 1)
    swish = noise * env
    swish = 0.7 * swish + 0.3 * band(swish, 3000, 9000) * 2
    crk = np.zeros(n)
    for c in rng.uniform(0.06, 0.30, 7):
        i, L = int(c * SR), int(0.004 * SR)
        burst = band(rng.standard_normal(L * 4), 2000, 9000)[:L] * np.exp(-np.arange(L) / (0.0012 * SR))
        crk[i:i + L] += burst * rng.uniform(0.4, 1.0)
    sig = swish + 0.35 * crk
    pan = np.clip((t - 0.04) / 0.32, 0, 1)
    st = np.stack([sig * np.cos(pan * np.pi / 2 * 0.7 + 0.15), sig * np.sin(pan * np.pi / 2 * 0.7 + 0.15)], 1)
    st *= 10 ** (-15 / 20) / np.abs(st).max()
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp) / "page.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((st * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav),
                        "-c:a", "libvorbis", "-q:a", "5", str(DST)], check=True)
    print("page-turn:", DST.relative_to(ROOT))


if __name__ == "__main__":
    main()
