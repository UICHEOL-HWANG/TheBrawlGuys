"""Battle theme "Forest Romp": a driving woodland reel at 160 BPM in G major, 32 bars (A A' B A'').

Four-on-the-floor kick with a snare and clap backbeat, galloping eighth-note pizzicato bass and
non-stop down-up guitar strumming under a flute tune, marimba, woodblock, 16th shakers and the
odd bird. `intense` sits on top while someone is on
their last stock (MusicDirector): tambourine, double-time shaker, ocarina an octave up and a
glockenspiel sparkle. All material is original to this project (context F10).
"""
from score import merge

BEATS = 128
A, A2, B, A3 = 0, 32, 64, 96
# name -> (strum voicing, bass root, fifth)
CHORDS = {
    "G": ([55, 59, 62, 67], 43, 50), "D": ([54, 57, 62, 66], 38, 45), "Em": ([55, 59, 64, 67], 40, 47),
    "C": ([55, 60, 64, 67], 36, 43), "Bm": ([54, 59, 62, 66], 35, 42), "Am": ([57, 60, 64, 69], 45, 40),
}
# (chord, beats) per section; A ends on D so it rolls back round.
A_PROG = [("G", 4), ("D", 4), ("Em", 4), ("C", 4), ("G", 4), ("D", 4), ("C", 2), ("D", 2), ("G", 4)]
B_PROG = [("C", 4), ("D", 4), ("Bm", 4), ("Em", 4), ("C", 4), ("D", 4), ("Am", 4), ("D", 4)]
TUNE = [
    (0, 74, .5), (.5, 76, .5), (1, 79, 1), (2, 78, .5), (2.5, 76, .5), (3, 74, 1),
    (4, 78, .5), (4.5, 76, .5), (5, 74, 1), (6, 69, 1), (7, 74, 1),
    (8, 71, .5), (8.5, 74, .5), (9, 79, 1.5), (10.5, 78, .5), (11, 76, 1),
    (12, 76, .5), (12.5, 74, .5), (13, 72, 1), (14, 76, 1), (15, 72, 1),
    (16, 74, .5), (16.5, 76, .5), (17, 79, 1), (18, 81, .5), (18.5, 83, .5), (19, 81, 1),
    (20, 78, 1.5), (21.5, 76, .5), (22, 74, 1), (23, 78, 1),
    (24, 76, .5), (24.5, 79, .5), (25, 76, 1), (26, 74, .5), (26.5, 78, .5), (27, 81, 1),
    (28, 79, 2), (30, 74, .5), (30.5, 76, .5), (31, 78, 1),
]
COUNTER = [
    (0, 79, 2), (2, 76, 2), (4, 78, 3), (7, 81, 1), (8, 78, 2), (10, 74, 2), (12, 71, 3), (15, 74, 1),
    (16, 76, 2), (18, 79, 2), (20, 81, 3), (23, 78, 1), (24, 76, 2), (26, 72, 2), (28, 74, 2), (30, 78, 2),
]
G_SCALE = [7, 9, 11, 0, 2, 4, 6]


def _bars(prog, start):
    at = start
    for name, beats in prog:
        yield at, name, beats
        at += beats


def _shift(notes, by, semis=0, vel=1.0):
    return [(b + by, m + semis, d, vel) for b, m, d in notes]


def _third_below(notes):
    out = []
    for b, m, d in notes:
        lower = G_SCALE[(G_SCALE.index(m % 12) - 2) % 7]
        out.append((b, m - ((m % 12 - lower) % 12), d))
    return out


def _boom(prog, start):
    """Galloping eighths: root, root, fifth, octave; a fifth-to-root pickup into each change."""
    figure = ((0, 0, 1.0), (0.5, 0, 0.55), (1, 1, 0.8), (1.5, 2, 0.6))
    out = []
    for at, name, beats in _bars(prog, start):
        _, root, fifth = CHORDS[name]
        tones = (root, fifth, root + 12)
        for half in range(0, beats, 2):
            out += [(at + half + b, tones[i], 0.45, v) for b, i, v in figure]
    return out


def _chuck(prog, start):
    """Non-stop down-up eighth strumming, accents on 2 and 4; strings 6 ms apart (up strokes reversed)."""
    out = []
    for at, name, beats in _bars(prog, start):
        for i in range(beats * 2):
            down = i % 2 == 0
            v = 1.0 if i in (2, 6) else 0.7 if down else 0.45
            strings = CHORDS[name][0] if down else CHORDS[name][0][::-1]
            out += [(at + i * 0.5 + k * 0.012, m, 0.25, v) for k, m in enumerate(strings)]
    return out


def _arp(prog, start, step, octave, pattern=(0, 1, 2, 3, 2, 1)):
    out, k = [], 0
    for at, name, beats in _bars(prog, start):
        tones = CHORDS[name][0]
        for i in range(int(beats / step)):
            out.append((at + i * step, tones[pattern[k % len(pattern)]] + octave, step, 0.7 + 0.3 * (i % 2 == 0)))
            k += 1
    return out


def _pads(prog, start):
    return [(at, m + 12, beats - 0.1, 1.0) for at, name, beats in _bars(prog, start) for m in CHORDS[name][0][1:3]]


def _groove(start, bars):
    d = {"kick": [], "snare": [], "clap": [], "shaker": [], "woodblock": []}
    for bar in range(bars):
        s = start + bar * 4
        fill = bar == bars - 1
        d["kick"] += [(s + b, 1.0 if b % 2 == 0 else 0.85) for b in range(4)]
        d["snare"] += [(s + 1, 1.0)] + ([(s + 3, 1.0)] if not fill else
                                        [(s + 2 + k * 0.25, 0.5 + 0.06 * k) for k in range(8)])
        d["clap"] += [(s + 1, 1.0), (s + 3, 1.0)]
        d["shaker"] += [(s + h * 0.25, (1.0, 0.4, 0.7, 0.4)[h % 4]) for h in range(16)]
        d["woodblock"] += [(s + 1.5, 0.8), (s + 2.75, 0.6), (s + 3.5, 0.7)] if bar % 2 else [(s + 0.75, 0.6), (s + 3.5, 0.8)]
    return d


def song():
    parts = [(A_PROG, A), (A_PROG, A2), (B_PROG, B), (A_PROG, A3)]
    drums = merge(*[_groove(s, 8) for _, s in parts])
    tune = _shift(TUNE, A) + _shift(TUNE, A2) + _shift(TUNE, A3)
    birds = [(A + 0.5, 0.8), (A2 + 14, 0.6), (B + 6, 0.8), (B + 22, 0.6), (A3 + 30, 0.7)]
    base = [
        {"drum": "kick", "hits": drums["kick"], "gain": 0.45},
        {"drum": "snare", "hits": drums["snare"], "gain": 1.4, "rev": 0.2},
        {"drum": "clap", "hits": drums["clap"], "gain": 0.7, "rev": 0.3},
                {"drum": "shaker", "hits": drums["shaker"], "gain": 1.6, "pan": 0.35},
        {"drum": "woodblock", "hits": drums["woodblock"], "gain": 1.6, "pan": -0.4, "rev": 0.2},
        {"drum": "bird", "hits": birds, "gain": 1.8, "pan": 0.7, "rev": 0.5},
        {"voice": "pizz_bass", "duck": True, "gain": 1.1, "notes": [n for p, s in parts for n in _boom(p, s)]},
        {"voice": "strum", "gain": 1.5, "pan": -0.2, "rev": 0.15, "notes": [n for p, s in parts for n in _chuck(p, s)]},
        {"voice": "warm_pad", "duck": True, "gain": 0.8, "rev": 0.5, "notes": [n for p, s in parts for n in _pads(p, s)]},
        {"voice": "marimba", "gain": 0.7, "pan": 0.3, "rev": 0.25, "notes":
            _arp(A_PROG, A, 0.5, 12) + _arp(A_PROG, A2, 0.5, 12) + _arp(B_PROG, B, 0.5, 24, (0, 2, 1, 3))
            + _arp(A_PROG, A3, 0.25, 12, (0, 1, 2, 3))},
        {"voice": "flute", "gain": 1.0, "rev": 0.35, "dly": 0.15, "notes": tune + _shift(COUNTER, B, vel=0.9)},
        {"voice": "flute", "gain": 0.55, "pan": -0.3, "rev": 0.35, "notes": _shift(_third_below(TUNE), A3)},
        {"voice": "guitar", "gain": 1.6, "pan": 0.35, "rev": 0.3, "notes": _shift(TUNE, A2, -12, 0.8)},
    ]
    intense = [
        {"drum": "tambourine", "hits": [(b, 0.9) for b in range(1, BEATS, 2)], "gain": 1.5, "pan": -0.3},
        {"drum": "shaker", "hits": [(b * 0.25, 0.4) for b in range(1, BEATS * 4, 2)], "gain": 1.2, "pan": -0.35},
        {"drum": "woodblock", "hits": [(b + 0.75, 0.5) for b in range(0, BEATS, 2)], "gain": 1.2, "pan": 0.45},
        {"voice": "ocarina", "gain": 0.6, "pan": 0.2, "rev": 0.35, "dly": 0.2, "notes":
            _shift(TUNE, A, 12, 0.8) + _shift(TUNE, A2, 12, 0.8) + _shift(COUNTER, B, 12, 0.7) + _shift(TUNE, A3, 12, 0.8)},
        {"voice": "glock", "gain": 0.7, "pan": -0.25, "dly": 0.25, "notes":
            [n for p, s in parts for n in _arp(p, s, 0.25, 24, (0, 1, 2, 3))]},
    ]
    return {"bpm": 160.0, "beats": BEATS, "swing": 0.0, "kick": drums["kick"], "drive": 1.6,
            "bus_comp": {"threshold_db": -18.0, "ratio": 3.0, "release_s": 0.07, "makeup_db": 5.0},
            "layers": {"battle_base": base, "battle_intense": intense}}
