class_name BotSquad
extends RefCounted
## The bots of one match (PRD-BOT-03~06): a dial BotController per bot slot, the opening probe of
## the one human (BotProbe -> skill estimate), DDA (DdaController) for bots facing humans when the
## dda variant is "on", bot tracking (BotTracker) and the device skill rating (SkillRating).
##   on   — bots start at the human's skill (rating, then the probe estimate) and DDA nudges them;
##   off  — bots stay at the normal preset (the A/B control); the probe still runs for data;
##   none — no human (bot-only matches, menu backdrop): fixed d, no probe, no DDA.
## Events go to MatchTelemetry as match_events rows: probe_stage, dda_adjusted, bot_intent.
## Bots read only views and write only InputFrames: the sim and replays are untouched.

const ON := "on"
const OFF := "off"
const NONE := "none"
## The probing bot plays at this d so probe features are comparable between players.
const PROBE_D := 0.5

var _config: GameConfig
var _bots := {}
var _start_d := {}
var _humans: Array[int] = []
var _variant: String
var _rating: SkillRating
var _rating_before: Variant = null
var _estimator: LinearModel
var _probe: BotProbe = null
var _prober: int = -1
var _probe_estimate: Variant = null
var _human_skill: float = PROBE_D
var _dda: DdaController = null
var _tracker: BotTracker


## options: variant (ON / OFF / NONE), d (start d without a human), d_by_slot (start d per bot
## slot, overrides the rest), rating (SkillRating or null), probe (bool), win_prob and
## estimator (LinearModel or null).
func _init(config: GameConfig, bot_slots: Array[int], humans: Array[int], options: Dictionary = {}) -> void:
	_config = config
	_humans = humans
	_variant = String(options.get("variant", NONE)) if not humans.is_empty() else NONE
	_rating = options.get("rating")
	_estimator = options.get("estimator")
	_tracker = BotTracker.new(config.dda_intent_cap, config.dda_intent_min_ticks)
	if _rating != null and _rating.matches() > 0:
		_rating_before = _rating.rating()
		_human_skill = _rating.rating()
	var start_d := float(options.get("d", PROBE_D))
	if _variant == ON:
		start_d = _human_skill
	elif _variant == OFF:
		start_d = BotDifficulty.d_of(BotDifficulty.DEFAULT_PRESET)
	var by_slot: Dictionary = options.get("d_by_slot", {})
	for slot: int in bot_slots:
		_start_d[slot] = float(by_slot.get(slot, start_d))
		_bots[slot] = BotController.new(slot, config, _start_d[slot])
	if bool(options.get("probe", false)) and humans.size() == 1 and not bot_slots.is_empty():
		_start_probe(bot_slots[0], humans[0])
	if _variant == ON and options.get("win_prob") != null:
		_dda = DdaController.new(config, options["win_prob"], _bots, humans, _skill_of)


func variant() -> String:
	return _variant


func bot(slot: int) -> BotController:
	return _bots.get(slot)


func sample(slot: int, view: Dictionary) -> InputFrame:
	var b: BotController = _bots.get(slot)
	return b.sample(view) if b != null else InputFrame.neutral()


## The matches row context (TelemetrySetup): dda_variant, null without a human.
func context() -> Dictionary:
	return {"dda_variant": null if _variant == NONE else _variant}


## After each sim tick: probe, DDA and tracking; rows go to telemetry (may be null).
func after_tick(view: Dictionary, telemetry: MatchTelemetry) -> void:
	var tick := int(view.get("tick", 0))
	var rows: Array[Dictionary] = []
	if _probe != null and _probe.active():
		var ended := _probe.observe(view)
		if not ended.is_empty():
			rows.append(_row(tick, "probe_stage", _prober, _probe.target(), ended))
			if not _probe.active():
				_on_probe_done()
	if _dda != null and (_probe == null or not _probe.active()):
		for e: Dictionary in _dda.step(view):
			rows.append(_row(tick, "dda_adjusted", int(e["slot"]), int(e["target"]), e))
	for slot: int in _bots:
		var intent := _tracker.sample(tick, slot, _bots[slot])
		if not intent.is_empty():
			rows.append(_row(tick, "bot_intent", slot, int(intent["target"]), intent))
	if telemetry != null:
		for r: Dictionary in rows:
			telemetry.add_bot_event(int(r["tick"]), String(r["type"]), r["actor"], r["target"], r["payload"])


## Match over: folds a skill observation into the device rating (one human only). The base is
## the bots' end d (on arm, after DDA) or the probe estimate (off arm), moved dda_rating_result_step
## toward the result — a win says the human is above it, a loss below — an Elo-like step that
## settles the rating where the human wins half the time.
## Returns the human's Amplitude user properties afterwards ({} without a human).
func finish(view: Dictionary) -> Dictionary:
	if _rating != null and _humans.size() == 1 and bool(view.get("match_over", false)):
		var base: float = _mean_bot_d()
		if _variant != ON and _probe_estimate != null:
			base = float(_probe_estimate)
		var obs := base + _config.dda_rating_result_step * (2.0 * _human_score(view) - 1.0)
		_rating.record(obs, _config.dda_rating_weight)
	return player_props()


## dda_variant, skill_rating (null while unrated) and skill_matches for user properties.
func player_props() -> Dictionary:
	if _variant == NONE or _humans.size() != 1:
		return {}  # no lone human facing bots: nothing to say about DDA or skill
	var rated := _rating != null and _rating.matches() > 0
	return {"dda_variant": _variant, "skill_rating": _rating.rating() if rated else null,
		"skill_matches": _rating.matches() if _rating != null else 0}


func _mean_bot_d() -> float:
	var total := 0.0
	for slot: int in _bots:
		total += (_bots[slot] as BotController).skill().d
	return total / maxf(1.0, float(_bots.size()))


## 1 win (own team in team mode), 0.5 draw, 0 loss for the human.
func _human_score(view: Dictionary) -> float:
	var winner := int(view.get("winner", -1))
	if winner < 0:
		return 0.5
	var human := _humans[0]
	var mode: Dictionary = view.get("mode", {})
	var teams: Array = mode.get("teams", [])
	if String(mode.get("rule", "")) == MatchRules.TEAM and winner < teams.size() and human < teams.size():
		return 1.0 if int(teams[winner]) == int(teams[human]) else 0.0
	return 1.0 if winner == human else 0.0


## Bot tracking columns for a slot's match_players row (every key on every row, null when n/a).
func slot_summary(slot: int) -> Dictionary:
	var out := {"bot_d_start": null, "bot_d_mean": null, "bot_d_end": null, "dda_adjustments": null,
		"probe_target_slot": null, "probe_features": null, "probe_estimate": null, "skill_rating": null}
	if _bots.has(slot):
		out.merge(_tracker.summary(slot), true)
		out["dda_adjustments"] = int(_dda.adjustments.get(slot, 0)) if _dda != null else 0
		out["bot_difficulty"] = BotDifficulty.preset_name(float(out["bot_d_start"]) if out["bot_d_start"] != null else PROBE_D)
		out["bot_params_hash"] = (_bots[slot] as BotController).skill().params_hash()
	if slot == _prober:
		out["probe_target_slot"] = _probe.target()
		out["probe_features"] = _probe.features()
		out["probe_estimate"] = _probe_estimate
	if _humans.has(slot):
		out["skill_rating"] = _rating_before
	return out


func _start_probe(prober: int, human: int) -> void:
	_prober = prober
	_probe = BotProbe.new(prober, human, _config, roundi(_config.dda_probe_stage_s * SimTime.TICK_RATE))
	_bots[prober].probe = _probe
	_bots[prober].set_difficulty(PROBE_D)


## Probe over: estimate the human's skill; in the on arm every bot starts from it (a fair match).
func _on_probe_done() -> void:
	if _estimator != null:
		_probe_estimate = snappedf(_estimator.predict(_probe.features()), 0.001)
	var start := _human_skill if _variant == ON else float(_start_d[_prober])
	if _probe_estimate != null and _variant == ON:
		_human_skill = float(_probe_estimate) if _rating_before == null else lerpf(_rating_before, _probe_estimate, 0.5)
		start = clampf(_human_skill, _config.dda_min_d, _config.dda_max_d)
	_bots[_prober].set_difficulty(start)
	if _variant == ON:
		for slot: int in _bots:
			_bots[slot].set_difficulty(start)


func _skill_of(slot: int) -> float:
	if _bots.has(slot):
		return (_bots[slot] as BotController).skill().d
	return _human_skill


static func _row(tick: int, type: String, actor: int, target: int, payload: Dictionary) -> Dictionary:
	var p := payload.duplicate()
	for k: String in ["tick", "slot", "target"]:
		p.erase(k)
	return {"tick": tick, "type": type, "actor": actor, "target": target if target >= 0 else null, "payload": p}
