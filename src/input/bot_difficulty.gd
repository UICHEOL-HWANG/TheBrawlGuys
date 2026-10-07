class_name BotDifficulty
extends RefCounted
## The difficulty dial (PRD-BOT-03): one continuous d in [0, 1] mapped to every BotSkill value.
## Each parameter moves monotonically from its d = 0 value to its d = 1 value (ints rounded), so
## a higher d reacts faster, guards / techs / DIs more, misaims and hesitates less and swings
## more often. The old dataset presets are named points on the dial. Monotonic win rate is
## verified by scripts/dda_sweep.gd (analysis/reports/dda.md).

const MIN_D := 0.0
const MAX_D := 1.0
const PRESETS := {"slow": 0.2, "normal": 0.5, "busy": 0.8}
const DEFAULT_PRESET := "normal"
## Parameter -> [value at d = 0, value at d = 1, curve exponent]; value = lerp(lo, hi, d ^ exp).
const ANCHORS := {
	"react_ticks": [24.0, 8.0, 1.0],
	"guard_chance": [0.35, 0.7, 1.0],
	"perfect_guard_chance": [0.0, 0.5, 1.0],
	"tech_chance": [0.0, 0.85, 1.0],
	"smart_getup": [0.0, 0.9, 1.0],
	"di_chance": [0.0, 0.9, 1.0],
	"recover_chance": [0.2, 1.0, 1.0],
	"cooldown_ticks": [54.0, 34.0, 1.0],
	"aim_error_deg": [40.0, 0.0, 1.0],
	"hesitate_chance": [0.55, 0.0, 1.0],
	"special_delay_ticks": [300.0, 0.0, 1.0],
}


static func clamp_d(d: float) -> float:
	return clampf(d, MIN_D, MAX_D)


## The skill for dial value d (clamped to [0, 1]).
static func skill(d: float) -> BotSkill:
	var s := BotSkill.new()
	s.d = clamp_d(d)
	for key: String in ANCHORS:
		var a: Array = ANCHORS[key]
		var v := lerpf(float(a[0]), float(a[1]), pow(s.d, float(a[2])))
		s.set(key, roundi(v) if typeof(s.get(key)) == TYPE_INT else v)
	return s


static func d_of(preset: String) -> float:
	return float(PRESETS.get(preset, PRESETS[DEFAULT_PRESET]))


## Name of the preset nearest to d (for match_players.bot_difficulty).
static func preset_name(d: float) -> String:
	var best := DEFAULT_PRESET
	for name: String in PRESETS:
		if absf(float(PRESETS[name]) - d) < absf(float(PRESETS[best]) - d):
			best = name
	return best
