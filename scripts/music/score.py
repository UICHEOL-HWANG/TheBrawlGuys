"""Score helpers shared by the songs. Drum maps are {drum name: [(beat, velocity), ...]}."""


def merge(*maps):
    """One drum map from several, hits concatenated per drum."""
    out = {}
    for d in maps:
        for k, v in d.items():
            out.setdefault(k, []).extend(v)
    return out
