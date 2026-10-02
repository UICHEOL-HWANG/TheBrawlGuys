"""Menu theme: laid-back electric-piano groove at 112 BPM in Eb major, 16 bars.

Same key and hook shape as the battle theme so the two feel like one soundtrack.
"""
from score import merge

BPM = 112.0
# Seventh-chord voicings over two bars each: Abmaj7 Bb6 Gm7 Cm7, twice.
CHORDS = [([56, 60, 63, 67], 44), ([58, 62, 65, 67], 46), ([55, 58, 62, 65], 43), ([55, 58, 60, 63], 36)]
MELODY = [
    (0, 75, 1.5), (1.5, 77, .5), (2, 79, 2), (4, 77, 1), (5, 75, 1), (6, 72, 2),
    (8, 74, 1.5), (9.5, 75, .5), (10, 77, 2), (12, 82, 1.5), (13.5, 79, 2.5),
    (16, 79, 1), (17, 77, 1), (18, 75, 2), (20, 74, 1), (21, 75, 1), (22, 77, 2),
    (24, 79, 1.5), (25.5, 75, .5), (26, 72, 3), (29, 70, 1), (30, 72, 2),
]


def _keys(start):
    """Off-beat comping: each chord stabbed on 1, the and of 2, and 4."""
    out = []
    for i, (tones, _) in enumerate(CHORDS):
        s = start + i * 8
        for bar in (0, 4):
            for b, held, v in ((0, 1.2, 0.9), (1.5, 0.4, 0.6), (3, 0.8, 0.7)):
                out += [(s + bar + b, m, held, v) for m in tones]
    return out


def _bass(start):
    out = []
    for i, (_, root) in enumerate(CHORDS):
        s = start + i * 8
        out += [(s, root, 1.5, 1.0), (s + 2.5, root, 0.5, 0.7), (s + 3, root + 7, 0.75, 0.8),
                (s + 4, root, 1.5, 1.0), (s + 6.5, root + 12, 0.5, 0.6), (s + 7, root + 10, 0.75, 0.7)]
    return out


def _drums(bars):
    d = {"kick": [], "snare": [], "hat": []}
    for bar in range(bars):
        s = bar * 4
        d["kick"] += [(s, 0.8), (s + 1.75, 0.5), (s + 2.5, 0.6)]
        d["snare"] += [(s + 1, 0.55), (s + 3, 0.55)]
        d["hat"] += [(s + h * 0.5 + (0.08 if h % 2 else 0), 0.45 if h % 2 else 0.25) for h in range(8)]
    return d


def song():
    drums = merge(_drums(16))
    tracks = [
        {"drum": "kick", "hits": drums["kick"], "gain": 0.7},
        {"drum": "snare", "hits": drums["snare"], "gain": 0.45, "rev": 0.35},
        {"drum": "hat", "hits": drums["hat"], "gain": 0.35, "pan": 0.3},
        {"drum": "crash", "hits": [(0, 0.6), (32, 0.5)], "gain": 0.5, "pan": -0.3},
        {"voice": "sub", "duck": True, "gain": 0.8, "notes": _bass(0) + _bass(32)},
        {"voice": "epiano", "duck": True, "gain": 0.5, "pan": -0.15, "rev": 0.35, "notes": _keys(0) + _keys(32)},
        {"voice": "pad", "gain": 0.3, "rev": 0.6, "notes":
            [(i * 8 + h, m + 12, 7.9, 0.8) for h in (0, 32) for i, (t, _) in enumerate(CHORDS) for m in t[1:3]]},
        {"voice": "bell", "gain": 0.7, "pan": 0.25, "rev": 0.4, "dly": 0.4, "notes":
            [(b + 32, m, d, 1.0) for b, m, d in MELODY]},
        {"voice": "pluck", "gain": 0.35, "pan": 0.3, "dly": 0.3, "notes":
            [(b, m - 12, min(d, 0.5), 0.7) for b, m, d in MELODY[::2]]},
    ]
    return {"bpm": BPM, "beats": 64, "kick": drums["kick"], "layers": {"menu": tracks}}
