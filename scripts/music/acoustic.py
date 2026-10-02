"""Woodland voices for the forest battle theme: plucked strings, flute, mallets and hand percussion.

Plucked strings use Karplus-Strong (a noise burst ringing in a damped delay line), run through
scipy's lfilter so a note costs one IIR pass.
"""
import numpy as np
from scipy import signal
from synth import RNG, SR, adsr, bandpass, highpass, lowpass, midi_hz, sine


def _t(n: int) -> np.ndarray:
    return np.arange(n) / SR


def karplus(hz: float, seconds: float, decay: float = 0.996, bright: float = 4000.0) -> np.ndarray:
    n = int(seconds * SR)
    delay = max(2, round(SR / hz - 0.5))  # the averaging filter adds half a sample
    burst = np.zeros(n)
    burst[:delay] = lowpass(RNG.standard_normal(delay), bright)
    a = np.zeros(delay + 2)
    a[0], a[delay], a[delay + 1] = 1.0, -decay / 2, -decay / 2
    return signal.lfilter([1.0], a, burst)


def pizz_bass(m: float, hold: float) -> np.ndarray:
    """Upright-bass pluck: warm, short, with a thumb thump."""
    s = min(hold, 0.5) + 0.25
    x = karplus(midi_hz(m), s, 0.993, 1200) * 1.6 + sine(midi_hz(m), int(s * SR)) * np.exp(-_t(int(s * SR)) / 0.12)
    return lowpass(x, 900) * 0.55


def strum(m: float, hold: float) -> np.ndarray:
    """One string of a muted acoustic strum ('chuck'); the chord's notes are staggered by the score."""
    return highpass(karplus(midi_hz(m), 0.22, 0.975, 5000), 120) * 0.35


def guitar(m: float, hold: float) -> np.ndarray:
    return highpass(karplus(midi_hz(m), min(hold, 1.0) + 0.4, 0.995, 6000), 100) * 0.3


def marimba(m: float, hold: float) -> np.ndarray:
    n = int(0.7 * SR)
    t, hz = _t(n), midi_hz(m)
    tone = (sine(hz, n) * np.exp(-t / 0.3) + sine(hz * 3.93, n) * 0.25 * np.exp(-t / 0.06)
            + sine(hz * 9.2, n) * 0.08 * np.exp(-t / 0.02))
    click = bandpass(RNG.standard_normal(n), 2000, 6000) * np.exp(-t / 0.003) * 0.15
    return (tone + click) * 0.35


def glock(m: float, hold: float) -> np.ndarray:
    n = int(1.0 * SR)
    t, hz = _t(n), midi_hz(m)
    tone = sine(hz, n) * np.exp(-t / 0.5) + sine(hz * 2.76, n) * 0.3 * np.exp(-t / 0.15) \
        + sine(hz * 5.4, n) * 0.12 * np.exp(-t / 0.05)
    return tone * 0.16


def _breathy(m: float, hold: float, harmonics: tuple, breath: float, vib_depth: float) -> np.ndarray:
    n = int((hold + 0.15) * SR)
    t, hz = _t(n), midi_hz(m)
    vib = 1 + vib_depth * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.15) / 0.2, 0, 1)
    tone = sum(sine(hz * (k + 1) * vib, n) * a for k, a in enumerate(harmonics))
    air = bandpass(RNG.standard_normal(n), min(hz * 2, 8000), min(hz * 6, 15000)) * breath
    return (tone + air) * adsr(n, 0.035, 0.2, 0.85, 0.08, hold)


def flute(m: float, hold: float) -> np.ndarray:
    return _breathy(m, hold, (1.0, 0.35, 0.12, 0.04), 0.06, 0.004) * 0.3


def ocarina(m: float, hold: float) -> np.ndarray:
    return _breathy(m, hold, (1.0, 0.05, 0.08), 0.03, 0.006) * 0.3


def warm_pad(m: float, hold: float) -> np.ndarray:
    n = int((hold + 0.6) * SR)
    hz = midi_hz(m)
    tone = sum(sine(hz * f, n, RNG.random()) for f in (0.997, 1.0, 1.003)) + sine(hz * 2, n) * 0.3
    return lowpass(tone, 1800) * adsr(n, 0.4, 0.8, 0.8, 0.5, hold) * 0.08


# ---------------------------------------------------------------- hand percussion

def woodblock() -> np.ndarray:
    n = int(0.15 * SR)
    t = _t(n)
    tone = sine(1180, n) * np.exp(-t / 0.035) + sine(2860, n) * 0.4 * np.exp(-t / 0.015)
    return (tone + bandpass(RNG.standard_normal(n), 2000, 7000) * np.exp(-t / 0.002) * 0.3) * 0.5


def shaker() -> np.ndarray:
    n = int(0.09 * SR)
    t = _t(n)
    env = (1 - np.exp(-t / 0.008)) * np.exp(-t / 0.03)
    return bandpass(RNG.standard_normal(n), 4500, 11000) * env * 0.45


def tambourine() -> np.ndarray:
    n = int(0.3 * SR)
    t = _t(n)
    jingle = sum(sine(f, n, RNG.random()) for f in (6100, 7350, 8900, 10400)) * 0.15
    return highpass(RNG.standard_normal(n) * 0.6 + jingle, 5500) * np.exp(-t / 0.09) * 0.4


def bird() -> np.ndarray:
    """Two or three quick rising chirps."""
    out = np.zeros(int(0.5 * SR))
    at = 0
    for _ in range(2 + int(RNG.random() * 2)):
        n = int((0.05 + RNG.random() * 0.03) * SR)
        t = _t(n)
        hz = 2600 + 2200 * (t / t[-1]) ** 0.6 + 300 * np.sin(2 * np.pi * 40 * t)
        out[at:at + n] += sine(hz, n) * np.sin(np.pi * t / t[-1]) * 0.12
        at += n + int(0.04 * SR)
    return out


VOICES = {
    "pizz_bass": pizz_bass, "strum": strum, "guitar": guitar, "marimba": marimba, "glock": glock,
    "flute": flute, "ocarina": ocarina, "warm_pad": warm_pad,
}
DRUMS = {
    "woodblock": woodblock, "shaker": shaker, "tambourine": tambourine, "bird": bird,
}
