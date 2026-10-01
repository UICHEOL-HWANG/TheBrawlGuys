extends RefCounted
## One synthetic match setup for scripts/gen_dataset.gd (A9): rule, arena, player count,
## characters and per-slot bot tuning, all drawn from one seed so a dataset is reproducible.
## Bot tuning varies only the Bot config group of a per-bot GameConfig copy — the World keeps the
## project config, so the sim (and its config_fingerprint) is the shipped one.

## Rule draw weights (stock / team / timed).
const RULE_WEIGHTS := {MatchRules.STOCK: 0.5, MatchRules.TEAM: 0.25, MatchRules.TIMED: 0.25}
## Player counts per rule (team is fixed at MatchRules.TEAM_PLAYERS).
const STOCK_PLAYERS: Array[int] = [2, 2, 2, 3, 4]
const TIMED_PLAYERS: Array[int] = [2, 3, 4]
## Preset names describe the tuning, not strength: a first 400-match run showed "busy" bots
## (more swings and longer guards) LOSE more often than "slow" ones, so they are not difficulties.
const DIFFICULTIES: Array[String] = ["slow", "normal", "busy"]
## Bot group overrides per preset (written to match_players.bot_difficulty); "normal" keeps
## the config values.
const PRESETS := {
	"slow": {"bot_attack_cooldown_ticks": 55, "bot_guard_ticks": 18, "bot_guard_range": 1.5,
		"bot_edge_ratio": 0.7, "bot_item_seek_range": 4.0},
	"normal": {},
	"busy": {"bot_attack_cooldown_ticks": 14, "bot_guard_ticks": 48, "bot_guard_range": 2.9,
		"bot_edge_ratio": 0.86, "bot_item_seek_range": 11.0},
}
## +- jitter on the swing range so two bots of one difficulty still differ.
const RANGE_JITTER := 0.2


## {seed, rule, arena, characters, difficulties, bot_configs (one GameConfig per slot)}
static func make(seed: int, config: GameConfig) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var rule := _pick_rule(rng)
	var count := _player_count(rule, rng)
	var arenas := ArenaCatalog.ids()
	var characters: Array[String] = []
	var difficulties: Array[String] = []
	var bot_configs: Array[GameConfig] = []
	var arena := arenas[rng.randi_range(0, arenas.size() - 1)]
	for i: int in count:
		characters.append(CharacterData.IDS[rng.randi_range(0, CharacterData.IDS.size() - 1)])
		var difficulty := DIFFICULTIES[rng.randi_range(0, DIFFICULTIES.size() - 1)]
		difficulties.append(difficulty)
		bot_configs.append(bot_config(config, difficulty, rng.randf_range(-RANGE_JITTER, RANGE_JITTER)))
	return {"seed": seed, "rule": rule, "arena": arena, "characters": characters,
		"difficulties": difficulties, "bot_configs": bot_configs}


## A copy of config with the difficulty preset and a swing range offset applied.
static func bot_config(config: GameConfig, difficulty: String, range_offset: float) -> GameConfig:
	var out := config.duplicate() as GameConfig
	var preset: Dictionary = PRESETS.get(difficulty, {})
	for key: String in preset:
		out.set(key, type_convert(preset[key], typeof(out.get(key))))
	out.bot_attack_range = maxf(0.5, out.bot_attack_range + range_offset)
	return out


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
