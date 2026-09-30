class_name MatchSeed
extends RefCounted
## A fresh seed for each match the menus start (Phase 5 follow-up): bot characters
## (CharacterPicks) and the sim's own randomness differ from match to match. Drawn here in the app
## layer from a randomized generator, never inside the sim; the sim stays deterministic for the
## seed it is given, and telemetry records it (matches.seed) so replays reproduce the match. The
## menu backdrop, perf scenes, main.tscn run alone and tests keep their fixed seeds.

## Positive 31-bit: fits matches.seed (bigint) and survives JSON numbers exactly.
const MAX_SEED := 0x7FFFFFFF

static var _rng: RandomNumberGenerator = null


static func fresh() -> int:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng.randi_range(1, MAX_SEED)
