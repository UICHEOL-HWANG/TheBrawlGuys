class_name DdaController
extends RefCounted
## Dynamic difficulty (PRD-BOT-06). Every dda_interval_s it asks the win-probability model
## (LinearModel over DdaFeatures) how likely each human slot is to win, as a share relative to a
## fair one (p / prior * 0.5, so 0.5 = even in any player count). Outside the target band by more
## than dda_hysteresis it starts adjusting, and keeps nudging the d of every bot facing that human
## (not its teammates) by gain x (p - band middle), capped at dda_max_step, at most once per
## dda_cooldown_s, until p is back inside the band. A human ahead raises the bots' d.
## Bot-side only: changes BotController skill, never the sim.

const AHEAD := "player_ahead"
const BEHIND := "player_behind"

var _config: GameConfig
var _model: LinearModel
var _bots: Dictionary = {}
var _humans: Array[int] = []
var _skill_of: Callable
var _adjusting: Dictionary = {}
var _last_adjust: Dictionary = {}
var _last_p: Dictionary = {}
var adjustments: Dictionary = {}


## bots: slot -> BotController (only those facing a human are adjusted); skill_of(slot) -> d
## for any slot (a human's skill estimate).
func _init(config: GameConfig, model: LinearModel, bots: Dictionary, humans: Array[int], skill_of: Callable) -> void:
	_config = config
	_model = model
	_bots = bots
	_humans = humans
	_skill_of = skill_of
	for slot: int in bots:
		adjustments[slot] = 0


## Latest relative win probability of a human slot (-1 before the first evaluation).
func win_prob(human: int) -> float:
	return float(_last_p.get(human, -1.0))


## Call once per sim tick; returns dda_adjusted events {tick, slot, target, from, to, reason, win_prob}.
func step(view: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tick := int(view.get("tick", 0))
	if _model == null or bool(view.get("match_over", false)) or tick % interval_ticks(_config) != 0:
		return out
	var skill := {}
	for f: Dictionary in view["fighters"]:
		skill[int(f["id"])] = float(_skill_of.call(int(f["id"])))
	for human: int in _humans:
		var me := BotViewQuery.find(view, human)
		if me.is_empty() or int(me["stocks"]) <= 0:
			continue
		var p := relative(_model.predict(DdaFeatures.of(view, human, skill)), DdaFeatures.prior(view))
		_last_p[human] = p
		out.append_array(_adjust(view, human, p, tick))
	return out


func _adjust(view: Dictionary, human: int, p: float, tick: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var since := tick - int(_last_adjust.get(human, -(1 << 30)))
	var plan := decide(p, bool(_adjusting.get(human, false)), since, _config)
	_adjusting[human] = plan["adjusting"]
	if float(plan["step"]) == 0.0:
		return out
	_last_adjust[human] = tick
	for slot: int in _bots:
		if not _faces(view, slot, human):
			continue
		var bot: BotController = _bots[slot]
		var from := bot.skill().d
		var to := clampf(from + float(plan["step"]), _config.dda_min_d, _config.dda_max_d)
		if is_equal_approx(from, to):
			continue
		bot.set_difficulty(to)
		adjustments[slot] = int(adjustments[slot]) + 1
		out.append({"tick": tick, "slot": slot, "target": human, "from": snappedf(from, 0.001),
			"to": snappedf(to, 0.001), "reason": plan["reason"], "win_prob": snappedf(p, 0.001)})
	return out


## Hysteresis + cooldown decision: {adjusting, step, reason}. p = relative win probability,
## ticks_since = ticks since this human's last adjustment.
static func decide(p: float, adjusting: bool, ticks_since: int, config: GameConfig) -> Dictionary:
	var low := config.dda_target_low
	var high := config.dda_target_high
	if not adjusting and (p > high + config.dda_hysteresis or p < low - config.dda_hysteresis):
		adjusting = true
	elif adjusting and p >= low and p <= high:
		adjusting = false
	var out := {"adjusting": adjusting, "step": 0.0, "reason": ""}
	if adjusting and ticks_since >= roundi(config.dda_cooldown_s * SimTime.TICK_RATE):
		var mid := (low + high) * 0.5
		out["step"] = clampf(config.dda_gain * (p - mid), -config.dda_max_step, config.dda_max_step)
		out["reason"] = AHEAD if p > mid else BEHIND
	return out


## Model probability as a share relative to a fair one (0.5 = even), clamped to [0, 1].
static func relative(p: float, prior: float) -> float:
	return clampf(p / maxf(prior, 0.01) * 0.5, 0.0, 1.0)


static func interval_ticks(config: GameConfig) -> int:
	return maxi(1, roundi(config.dda_interval_s * SimTime.TICK_RATE))


## A bot faces a human unless they share a team (team mode).
static func _faces(view: Dictionary, bot: int, human: int) -> bool:
	var mode: Dictionary = view.get("mode", {})
	var teams: Array = mode.get("teams", [])
	if String(mode.get("rule", "")) != MatchRules.TEAM or bot >= teams.size() or human >= teams.size():
		return true
	return int(teams[bot]) != int(teams[human])
