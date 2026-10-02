"""Pitched voices. Each takes (midi, held seconds) and returns the note with its release tail."""
import numpy as np
from synth import RNG, SR, adsr, lowpass, midi_hz, pan, saw, sine, square, sweep_lowpass


def _cents(hz: float, c: float) -> float:
    return hz * 2.0 ** (c / 1200.0)


def sub_bass(m: float, hold: float) -> np.ndarray:
    n = int((hold + 0.1) * SR)
    return np.tanh(sine(midi_hz(m), n) * 1.3) * adsr(n, 0.006, 0.4, 0.8, 0.06, hold)


def supersaw(m: float, hold: float, cutoff: float = 3200.0) -> np.ndarray:
    """Stereo detuned pad: seven saws fanned across the field."""
    n = int((hold + 0.6) * SR)
    hz = midi_hz(m)
    out = np.zeros((n, 2))
    for i, c in enumerate((-22, -14, -7, 0, 7, 14, 22)):
        out += pan(saw(_cents(hz, c), n, RNG.random()), (i - 3) / 3.5)
    env = adsr(n, 0.05, 0.6, 0.7, 0.35, hold)
    return lowpass(out, cutoff) * env[:, None] * 0.16


def pluck(m: float, hold: float) -> np.ndarray:
    n = int((min(hold, 0.25) + 0.25) * SR)
    hz = midi_hz(m)
    tone = saw(hz, n) + square(_cents(hz, 8), n) * 0.5
    tone = sweep_lowpass(tone, 7000, 500, blocks=24)
    t = np.arange(n) / SR
    return tone * np.exp(-t / 0.11) * 0.35


def epiano(m: float, hold: float) -> np.ndarray:
    """Two-operator FM electric piano with a short metallic tine."""
    n = int((hold + 0.9) * SR)
    hz = midi_hz(m)
    t = np.arange(n) / SR
    index = 1.6 * np.exp(-t / 0.35) + 0.25
    body = np.sin(2 * np.pi * hz * t + index * np.sin(2 * np.pi * hz * t))
    tine = sine(hz * 14.0, n) * np.exp(-t / 0.02) * 0.15
    return (body + tine) * adsr(n, 0.002, 0.9, 0.35, 0.3, hold) * 0.3


def bell(m: float, hold: float) -> np.ndarray:
    n = int(1.2 * SR)
    hz = midi_hz(m)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * hz * t + 2.2 * np.exp(-t / 0.2) * np.sin(2 * np.pi * hz * 3.5 * t))
    return tone * np.exp(-t / 0.35) * 0.18


VOICES = {
    "sub": sub_bass, "pad": supersaw,
    "pluck": pluck, "epiano": epiano, "bell": bell,
}
