# Audio overhaul — plan
User: placeholder BGM sounds cheap ("밤티"); make battle BGM punchy (reference: 2001 Korean online-game D&B, ~172 BPM, Eb major — style only, the file itself is copyrighted and not used); hit SFX per weapon, punchier.
1. Offline Python renderer scripts/music/ (numpy/scipy/soundfile) → assets/music/*.ogg (MusicDirector already prefers .ogg).
2. Battle theme 174 BPM D&B, base + intensity layer, shared gain, seamless loop; menu theme 112 BPM e-piano.
3. Hit SFX per weapon (fist/sword/magic/bat/rock/feather) → assets/sfx/hit_*.ogg; HitSounds picks by item kind then attacker style.
4. User listening approval before baking music into assets.
