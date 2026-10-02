# Audio overhaul — context
Last Updated: 2026-10-02 16:40

## Key files
- scripts/music/{synth,instruments,score,mixer,battle,menu,compose,hits}.py — offline renderer. Run: `uv run --with numpy --with scipy --with soundfile scripts/music/compose.py [out] [battle|menu]`, `.../hits.py [out]`
- src/audio/hit_sounds.gd — event+attacker style → sound; src/audio/sfx_director.gd (style_of, on_events(events, fighters)); src/audio/sfx_recipes.gd stream_path (.ogg wins over baked .wav)
- src/main/match_presentation.gd passes view fighters to SFX
- tests/unit/test_hit_sounds.gd

## Decisions
- ffmpeg here lacks libvorbis → soundfile writes OGG, in 16k-frame blocks (libsndfile crashes on huge single writes).
- Peaks: music 0.8, sfx 0.78 pre-encode (Vorbis overshoot up to ~15%).
- hit_light/hit_heavy names kept (now fist sounds) so existing callers/tests stay valid.
- Battle drums never drop out; snare/clap loud (D&B punch), reese lower.
- Honest limit: pure synthesis has a quality ceiling; user offered Suno Pro / royalty-free as alternatives.
- 2026-10-02: user wants battle BGM as a light, bouncy forest tune instead of D&B; scripts/music/acoustic.py adds woodland voices; mixer swing.
