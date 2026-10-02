"""Renders the soundtrack to <out>/<name>.ogg (MusicDirector prefers .ogg over the .wav placeholders).

Run: uv run --with numpy --with scipy --with soundfile scripts/music/compose.py [out_dir] [song ...]
Songs: battle, menu. Defaults: assets/music ("" also means it), all songs.
"""
import sys
from pathlib import Path

import battle
import menu
import mixer
import numpy as np
import soundfile
import synth

SONGS = {"battle": battle.song, "menu": menu.song}
OGG_QUALITY = 0.6  # libsndfile Vorbis quality, 0..1
BLOCK = 1 << 14  # libsndfile's Vorbis encoder crashes on very large single writes


def write_ogg(samples: np.ndarray, path: Path) -> None:
    with soundfile.SoundFile(path, "w", synth.SR, samples.shape[1], format="OGG",
                             subtype="VORBIS", compression_level=1.0 - OGG_QUALITY) as f:
        for i in range(0, len(samples), BLOCK):
            f.write(samples[i:i + BLOCK])


def main(argv: list) -> int:
    root = Path(__file__).resolve().parents[2]
    out = Path(argv[0]) if argv and argv[0] else root / "assets" / "music"
    names = argv[1:] or list(SONGS)
    unknown = [n for n in names if n not in SONGS]
    if unknown:
        print(f"compose: unknown song(s) {unknown}; choose from {list(SONGS)}", file=sys.stderr)
        return 1
    out.mkdir(parents=True, exist_ok=True)
    for name in names:
        for file_name, samples in mixer.render(SONGS[name]()).items():
            path = out / f"{file_name}.ogg"
            write_ogg(samples, path)
            print(f"compose: {path} ({len(samples) / synth.SR:.2f}s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
