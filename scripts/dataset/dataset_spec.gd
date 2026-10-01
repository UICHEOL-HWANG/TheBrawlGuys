extends RefCounted
## One synthetic match setup for scripts/gen_dataset.gd (A9): rule, arena, player count,
## characters, per-slot dial values and the dda variant, all drawn from one seed so a dataset is
## reproducible. Bots never change the sim config, so the World (and its config_fingerprint) is
## the shipped one.

## Rule draw weights (stock / team / timed).
const RULE_WEIGHTS := {MatchRules.STOCK: 0.5, MatchRules.TEAM: 0.25, MatchRules.TIMED: 0.25}
## Player counts per rule (team is fixed at MatchRules.TEAM_PLAYERS).
const STOCK_PLAYERS: Array[int] = [2, 2, 2, 3, 4]
const TIMED_PLAYERS: Array[int] = [2, 3, 4]
## Bots get a continuous dial value d ~ U[0, 1] (BotDifficulty, PRD-BOT-03); slot 0 plays the
## "player" (a dial bot with a known d the probe and DDA treat as the human), and the dda
## variant is drawn 50 / 50 so DDA-on and DDA-off matches both appear.
const DDA_ON_SHARE := 0.5


## {seed, rule, arena, characters, d (one per slot), difficulties (preset names), variant}
static func make(seed: int, _config: GameConfig = null) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var rule := _pick_rule(rng)
	var count := _player_count(rule, rng)
	var arenas := ArenaCatalog.ids()
	var characters: Array[String] = []
	var d: Array[float] = []
	var difficulties: Array[String] = []
	var arena := arenas[rng.randi_range(0, arenas.size() - 1)]
	for i: int in count:
		characters.append(CharacterData.IDS[rng.randi_range(0, CharacterData.IDS.size() - 1)])
		d.append(snappedf(rng.randf(), 0.001))
		difficulties.append(BotDifficulty.preset_name(d.back()))
	var variant := BotSquad.ON if rng.randf() < DDA_ON_SHARE else BotSquad.OFF
	return {"seed": seed, "rule": rule, "arena": arena, "characters": characters, "d": d,
		"difficulties": difficulties, "variant": variant}


## The MatchSetup the app would build for this spec (bots only, so local_slot is -1).
static func to_match_setup(spec: Dictionary) -> MatchSetup:
	var chars: Array[String] = spec["characters"]
	var setup := MatchSetup.all_bots(chars.size(), int(spec["seed"]))
	setup.rule = String(spec["rule"])
	setup.arena_id = String(spec["arena"])
	var picks := {}
	for i: int in chars.size():
		picks[i] = chars[i]
	setup.set_characters(picks)
	return setup


static func _pick_rule(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	for rule: String in RULE_WEIGHTS:
		roll -= float(RULE_WEIGHTS[rule])
		if roll < 0.0:
			return rule
	return MatchRules.STOCK


static func _player_count(rule: String, rng: RandomNumberGenerator) -> int:
	match rule:
		MatchRules.TEAM:
			return MatchRules.TEAM_PLAYERS
		MatchRules.TIMED:
			return TIMED_PLAYERS[rng.randi_range(0, TIMED_PLAYERS.size() - 1)]
	return STOCK_PLAYERS[rng.randi_range(0, STOCK_PLAYERS.size() - 1)]
