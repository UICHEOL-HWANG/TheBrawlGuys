"""Renders a song dict (battle.py / menu.py) into seamless, gain-matched stereo loops.

Track keys: "voice" + "notes" or "drum" + "hits"; optional "gain", "pan" (-1..1), "rev" and
"dly" (send levels), "duck" (sidechain to the song's kick). A song's
"swing" (beats) delays every off-beat eighth for a shuffle feel.
"""
import acoustic
import instruments
import numpy as np
import synth

VOICES = {**instruments.VOICES, **acoustic.VOICES}

TAIL_S = 5.0
PEAK = 0.8  # headroom: Vorbis overshoots dense mixes by up to ~13%
DRUMS = {
    "kick": synth.kick, "snare": synth.snare, "clap": synth.clap, "hat": synth.hat, "crash": synth.crash,
    **acoustic.DRUMS,
}


def swung(beat: float, swing: float) -> float:
    """Off-beat eighths (and strums rolled just after them) land `swing` beats late."""
    return beat + swing if swing and 0.5 - 1e-6 <= beat % 1.0 < 0.6 else beat


def _place(buf: np.ndarray, x: np.ndarray, at: int) -> None:
    end = min(at + len(x), len(buf))
    if x.ndim == 1:
        x = synth.pan(x, 0.0)
    buf[at:end] += x[: end - at]


def _render_track(track: dict, n: int, beat_s: float, swing: float = 0.0) -> np.ndarray:
    out = np.zeros((n, 2))
    if "drum" in track:
        one = DRUMS[track["drum"]]()
        for hit in track["hits"]:
            _place(out, one * hit[1], round(swung(hit[0], swing) * beat_s * synth.SR))
    else:
        voice = VOICES[track["voice"]]
        for b, m, held, vel in track["notes"]:
            _place(out, voice(m, held * beat_s) * vel, round(swung(b, swing) * beat_s * synth.SR))
    p = track.get("pan", 0.0)
    if p:
        mono = out.mean(axis=1)
        out = out * (1 - abs(p)) + synth.pan(mono, p) * abs(p) * 1.4
    return out * track.get("gain", 1.0)


def _duck_env(kicks: list, n: int, beat_s: float, depth: float = 0.55) -> np.ndarray:
    env = np.ones(n)
    t = np.arange(int(0.3 * synth.SR)) / synth.SR
    dip = 1 - depth * np.exp(-t / 0.07)
    for b, _ in kicks:
        at = round(b * beat_s * synth.SR)  # kicks sit on the beat, so swing never moves them
        end = min(at + len(dip), n)
        env[at:end] = np.minimum(env[at:end], dip[: end - at])
    return env[:, None]


def _render_layer(tracks: list, song: dict, n: int, beat_s: float) -> np.ndarray:
    dry = np.zeros((n, 2))
    rev_send = np.zeros((n, 2))
    dly_send = np.zeros((n, 2))
    duck = _duck_env(song.get("kick", []), n, beat_s)
    for tr in tracks:
        x = _render_track(tr, n, beat_s, song.get("swing", 0.0))
        if tr.get("duck"):
            x = x * duck
        dry += x
        rev_send += x * tr.get("rev", 0.0)
        dly_send += x * tr.get("dly", 0.0)
    wet = synth.reverb(rev_send, 1.8)[:n] + synth.pingpong(dly_send, beat_s * 0.75, 0.45)[:n]
    bus = synth.highpass(dry + wet, 28)
    comp = song.get("bus_comp")
    return synth.compress(bus, **comp) if comp else bus


def _wrap(x: np.ndarray, loop_n: int) -> np.ndarray:
    """Fold everything past the loop point back onto its start so the loop is seamless."""
    out = x[:loop_n].copy()
    for at in range(loop_n, len(x), loop_n):  # a tail longer than the loop folds round again
        chunk = x[at:at + loop_n]
        out[: len(chunk)] += chunk
    return out


def render(song: dict) -> dict:
    """{file name: stereo float array}, all layers one length and one shared gain."""
    beat_s = 60.0 / song["bpm"]
    loop_n = round(song["beats"] * beat_s * synth.SR)
    n = loop_n + int(TAIL_S * synth.SR)
    layers = {name: _wrap(_render_layer(tr, song, n, beat_s), loop_n)
              for name, tr in song["layers"].items()}
    drive = song.get("drive", 1.1)
    layers = {k: np.tanh(v * drive) / drive for k, v in layers.items()}
    gain = PEAK / max(np.max(np.abs(sum(layers.values()))), 1e-9)
    return {k: (v * gain).astype(np.float32) for k, v in layers.items()}
