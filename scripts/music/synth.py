"""Offline voices for the soundtrack: band-limited oscillators, drums, filters and effects.

Everything renders to float64 numpy arrays at SR. Stereo signals are shaped (n, 2).
"""
import numpy as np
from scipy import signal

SR = 44100
RNG = np.random.default_rng(7)


def midi_hz(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69.0) / 12.0)


def _polyblep(t: np.ndarray, dt: float) -> np.ndarray:
    out = np.zeros_like(t)
    a = t < dt
    x = t[a] / dt
    out[a] = x + x - x * x - 1.0
    b = t > 1.0 - dt
    x = (t[b] - 1.0) / dt
    out[b] = x * x + x + x + 1.0
    return out


def saw(hz: float, n: int, phase: float = 0.0) -> np.ndarray:
    dt = hz / SR
    t = (phase + dt * np.arange(n)) % 1.0
    return 2.0 * t - 1.0 - _polyblep(t, dt)


def square(hz: float, n: int, phase: float = 0.0) -> np.ndarray:
    return 0.5 * (saw(hz, n, phase) - saw(hz, n, phase + 0.5))


def sine(hz, n: int, phase: float = 0.0) -> np.ndarray:
    if np.isscalar(hz):
        return np.sin(2 * np.pi * (phase + hz * np.arange(n) / SR))
    return np.sin(2 * np.pi * (phase + np.cumsum(hz) / SR))


def adsr(n: int, a: float, d: float, s: float, r: float, hold: float) -> np.ndarray:
    """Envelope for a note held `hold` seconds, total length n samples (release included)."""
    t = np.arange(n) / SR
    env = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel = t > hold
    if rel.any():
        env[rel] = env[min(int(hold * SR), n - 1)] * np.exp(-(t[rel] - hold) / max(r, 1e-4))
    return env


def lowpass(x: np.ndarray, hz: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, min(hz, SR * 0.45), "low", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def highpass(x: np.ndarray, hz: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, hz, "high", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def bandpass(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    sos = signal.butter(2, [lo, hi], "band", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def sweep_lowpass(x: np.ndarray, start_hz: float, end_hz: float, blocks: int = 64) -> np.ndarray:
    """Lowpass whose cutoff glides exponentially across the clip (block-wise, state carried)."""
    curve = [start_hz * (end_hz / start_hz) ** (i / max(blocks - 1, 1)) for i in range(blocks)]
    return moving_lowpass(x, curve)


def moving_lowpass(x: np.ndarray, cutoffs: list) -> np.ndarray:
    """Lowpass following one cutoff per equal block of the clip (filter state carried across)."""
    blocks = len(cutoffs)
    out = np.empty_like(x)
    edges = np.linspace(0, len(x), blocks + 1).astype(int)
    zi = None
    for i, hz in enumerate(cutoffs):
        sos = signal.butter(2, min(hz, SR * 0.45), "low", fs=SR, output="sos")
        if zi is None:
            zi = np.zeros((sos.shape[0], 2) + x.shape[1:])
        seg = x[edges[i]:edges[i + 1]]
        out[edges[i]:edges[i + 1]], zi = signal.sosfilt(sos, seg, axis=0, zi=zi)
    return out


# ---------------------------------------------------------------- drums

def kick(punch: float = 1.0) -> np.ndarray:
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    hz = 50.0 + 190.0 * np.exp(-t / 0.022)
    body = sine(hz, n) * np.exp(-t / 0.2)
    click = highpass(RNG.standard_normal(n), 2500) * np.exp(-t / 0.003) * 0.6
    knock = bandpass(RNG.standard_normal(n), 900, 3000) * np.exp(-t / 0.008) * 0.3
    return np.tanh((body + click + knock) * 2.6 * punch) * 0.9


def clap() -> np.ndarray:
    """Three quick noise bursts and a short tail, layered over the snare for width and snap."""
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    env = np.zeros(n)
    for k, at in enumerate((0.0, 0.009, 0.018)):
        i = int(at * SR)
        env[i:] += np.exp(-(t[: n - i]) / (0.006 if k < 2 else 0.07))
    return bandpass(RNG.standard_normal(n), 900, 7000) * env * 0.7


def snare(tone: float = 1.0) -> np.ndarray:
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    body = sine(185.0 + 60 * np.exp(-t / 0.01), n) * np.exp(-t / 0.045) * 0.7 * tone
    noise = bandpass(RNG.standard_normal(n), 1200, 9000) * np.exp(-t / 0.085)
    return np.tanh((body + noise * 0.8) * 1.4) * 0.8


def hat(open_: bool = False) -> np.ndarray:
    n = int((0.35 if open_ else 0.06) * SR)
    t = np.arange(n) / SR
    metal = sum(square(f, n) for f in (3150, 4270, 5840, 7290)) * 0.25 + RNG.standard_normal(n)
    return highpass(metal, 7000, 4) * np.exp(-t / (0.12 if open_ else 0.018)) * 0.45


def crash() -> np.ndarray:
    n = int(1.8 * SR)
    t = np.arange(n) / SR
    return highpass(RNG.standard_normal(n), 4500, 2) * np.exp(-t / 0.55) * 0.3


# ---------------------------------------------------------------- effects

def compress(x: np.ndarray, threshold_db: float = -18.0, ratio: float = 4.0,
             release_s: float = 0.08, makeup_db: float = 6.0) -> np.ndarray:
    """Bus compressor: a smoothed peak follower on the summed channels drives one gain curve."""
    level = np.abs(x).max(axis=1) if x.ndim == 2 else np.abs(x)
    env = signal.lfilter([1 - np.exp(-1 / (release_s * SR))], [1, -np.exp(-1 / (release_s * SR))], level)
    env = np.maximum(env, 1e-6)
    over = 20 * np.log10(env) - threshold_db
    gain_db = np.where(over > 0, -over * (1 - 1 / ratio), 0.0) + makeup_db
    g = 10 ** (gain_db / 20)
    return x * (g[:, None] if x.ndim == 2 else g)


def pan(x: np.ndarray, p: float) -> np.ndarray:
    """Equal-power pan of a mono signal; p in [-1, 1]."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def reverb(x: np.ndarray, seconds: float = 1.6, damp_hz: float = 6000) -> np.ndarray:
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = np.zeros((len(x) + n - 1, 2))
    for ch in range(2):
        ir = lowpass(RNG.standard_normal(n), damp_hz) * np.exp(-t / (seconds / 6.9))
        ir[: int(0.012 * SR)] = 0.0
        out[:, ch] = signal.fftconvolve(x[:, ch], ir / np.sqrt(np.sum(ir**2)))
    return out * 0.18


def pingpong(x: np.ndarray, delay_s: float, feedback: float = 0.4, taps: int = 6) -> np.ndarray:
    d = int(delay_s * SR)
    out = np.zeros((len(x) + d * taps, 2))
    mono = lowpass(x.mean(axis=1), 5000)
    for k in range(1, taps + 1):
        out[k * d: k * d + len(x), k % 2] += mono * feedback**k
    return out
