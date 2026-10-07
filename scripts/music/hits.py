"""Weapon hit sounds (design.md DS-SFX-01): what the attacker hits *with* decides the sound.

Run: uv run --with numpy --with scipy --with soundfile scripts/music/hits.py [out_dir]
Writes <out>/<name>.wav (default assets/sfx), replacing the baked placeholders (bake_sfx.gd skips
HitSounds.NAMES). .wav on purpose: the web build turns every sound into a Web Audio sample, and an
.ogg would first be decoded on the main thread. Every sound is original (context F9).
"""
import sys
from pathlib import Path

import numpy as np
import soundfile
from synth import RNG, SR, bandpass, highpass, lowpass, sine

PEAK = 0.78  # sharp transients overshoot ~15% after Vorbis


def _t(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * SR)) / SR


def _noise(seconds: float) -> np.ndarray:
    return RNG.standard_normal(int(seconds * SR))


def _thump(start_hz: float, end_hz: float, decay: float, seconds: float = 0.35) -> np.ndarray:
    t = _t(seconds)
    hz = end_hz + (start_hz - end_hz) * np.exp(-t / 0.025)
    return sine(hz, len(t)) * np.exp(-t / decay)


def _ring(partials: list, decay: float, seconds: float) -> np.ndarray:
    """Inharmonic metal partials, higher ones dying faster."""
    t = _t(seconds)
    out = np.zeros_like(t)
    for i, (hz, amp) in enumerate(partials):
        out += sine(hz, len(t), RNG.random()) * amp * np.exp(-t / (decay / (1 + 0.35 * i)))
    return out


def fist(heavy: bool) -> np.ndarray:
    """Glove or fist on a body: a padded thump with a leathery slap."""
    s = 0.4 if heavy else 0.22
    t = _t(s)
    body = _thump(160 if heavy else 210, 45 if heavy else 70, 0.12 if heavy else 0.05, s) * (1.3 if heavy else 1.0)
    slap = bandpass(_noise(s), 700, 4500) * np.exp(-t / (0.03 if heavy else 0.018)) * 0.9
    out = np.tanh((body + slap) * (2.2 if heavy else 1.6))
    if heavy:
        out = out + lowpass(_noise(s), 300) * np.exp(-t / 0.09) * 1.2
    return out


def sword(heavy: bool) -> np.ndarray:
    """Blade contact: a bright slash transient, a metallic ring and a little body."""
    s = 0.9 if heavy else 0.45
    t = _t(s)
    slash = highpass(_noise(s), 3500) * np.exp(-t / 0.025) * 0.9
    base = 1450 if heavy else 2100
    ring = _ring([(base, 1.0), (base * 1.48, 0.7), (base * 2.13, 0.5), (base * 2.94, 0.35), (base * 4.07, 0.2)],
                 0.35 if heavy else 0.16, s) * 0.45
    body = _thump(180, 60, 0.07, s) * (0.9 if heavy else 0.5)
    return np.tanh((slash + ring + body) * 1.5)


def magic(heavy: bool) -> np.ndarray:
    """Fire bolt burst: a falling zap with FM shimmer over crackle (plus a boom when heavy)."""
    s = 0.6 if heavy else 0.35
    t = _t(s)
    hz = 300 + 1900 * np.exp(-t / 0.06)
    phase = 2 * np.pi * np.cumsum(hz) / SR
    zap = np.sin(phase + 2.5 * np.sin(3.1 * phase)) * np.exp(-t / (0.12 if heavy else 0.07)) * 0.5
    crackle = highpass(_noise(s) * (RNG.random(len(t)) > 0.985), 1500) * np.exp(-t / 0.15) * 1.6
    burst = bandpass(_noise(s), 300, 3000) * np.exp(-t / 0.05) * 0.6
    out = zap + crackle + burst
    if heavy:
        out = out + _thump(120, 40, 0.15, s) * 1.2 + lowpass(_noise(s), 250) * np.exp(-t / 0.2) * 1.4
    return np.tanh(out * 1.4)


def bat() -> np.ndarray:
    """Wooden bat: a dry 'tock' of hollow wood modes and a crack."""
    s = 0.3
    t = _t(s)
    wood = _ring([(620, 1.0), (1370, 0.8), (2240, 0.5), (3410, 0.3)], 0.045, s)
    crack = bandpass(_noise(s), 1500, 6000) * np.exp(-t / 0.008) * 1.2
    return np.tanh((wood + crack + _thump(150, 70, 0.05, s) * 0.8) * 1.8)


def rock() -> np.ndarray:
    """Thrown stone: heavy thud with gritty crumble."""
    s = 0.45
    t = _t(s)
    grit = lowpass(_noise(s) * (RNG.random(len(t)) > 0.93), 3000) * np.exp(-t / 0.12) * 2.0
    return np.tanh((_thump(130, 45, 0.1, s) * 1.4 + grit + lowpass(_noise(s), 600) * np.exp(-t / 0.04)) * 1.8)


def feather() -> np.ndarray:
    """Feather glove: a soft cushioned 'poof' with an airy sparkle on top."""
    s = 0.45
    t = _t(s)
    env = (1 - np.exp(-t / 0.012)) * np.exp(-t / 0.11)
    poof = lowpass(_noise(s), 1200) * env * 1.5
    air = highpass(_noise(s), 6000) * env * 0.25
    chirp = sine(1300 + 900 * np.exp(-t / 0.05), len(t)) * np.exp(-t / 0.06) * 0.2
    return np.tanh((poof + air + chirp + _thump(220, 120, 0.04, s) * 0.4) * 1.3)


def _impact(heavy: bool) -> np.ndarray:
    """Shared punch under every hit: an attack click, a sub drop and a short distorted crunch."""
    s = 0.6 if heavy else 0.3
    t = _t(s)
    click = highpass(_noise(s), 4000) * np.exp(-t / 0.0025) * 1.4
    sub = _thump(110 if heavy else 140, 34 if heavy else 50, 0.16 if heavy else 0.07, s) * (1.6 if heavy else 1.0)
    crunch = np.tanh(bandpass(_noise(s), 400, 2500) * 6.0) * np.exp(-t / (0.035 if heavy else 0.02)) * 0.5
    out = click + sub + crunch
    if heavy:
        out = out + lowpass(_noise(s), 160) * np.exp(-t / 0.22) * 1.8  # rumble tail
    return out


def _mix(x: np.ndarray, imp: np.ndarray, amount: float) -> np.ndarray:
    n = max(len(x), len(imp))
    return np.pad(x, (0, n - len(x))) + np.pad(imp, (0, n - len(imp))) * amount


# name -> (voice, heavy, impact amount). Heavy hits get a deeper impact and stereo width.
SOUNDS = {
    "hit_light": (lambda: fist(False), False, 0.8), "hit_heavy": (lambda: fist(True), True, 1.0),
    "hit_sword_light": (lambda: sword(False), False, 0.6), "hit_sword_heavy": (lambda: sword(True), True, 0.9),
    "hit_magic_light": (lambda: magic(False), False, 0.6), "hit_magic_heavy": (lambda: magic(True), True, 0.9),
    "hit_bat": (bat, True, 0.7), "hit_rock": (rock, True, 0.8), "hit_feather": (feather, False, 0.25),
}
HAAS_S = 0.011  # right-channel delay on heavy hits for width


def render(name: str) -> np.ndarray:
    voice, heavy, amount = SOUNDS[name]
    x = np.tanh(_mix(voice(), _impact(heavy), amount) * 2.0)  # drive glues the layers and adds bite
    x = x * np.minimum(1.0, (len(x) - np.arange(len(x))) / (0.01 * SR))  # click-free end
    x = x * PEAK / max(np.max(np.abs(x)), 1e-9)
    right = x
    if heavy:
        d = int(HAAS_S * SR)
        right = 0.75 * x + 0.25 * np.concatenate([np.zeros(d), x[:-d]])
    return np.stack([x, right], axis=1).astype(np.float32)


def main(argv: list) -> int:
    out = Path(argv[0]) if argv else Path(__file__).resolve().parents[2] / "assets" / "sfx"
    out.mkdir(parents=True, exist_ok=True)
    for name in SOUNDS:
        # .wav, not .ogg: the web build plays AudioStreamWAV as a Web Audio sample (see SfxRecipes.stream_path)
        soundfile.write(out / f"{name}.wav", render(name), SR, subtype="PCM_16")
        print(f"hits: {out / name}.wav")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
