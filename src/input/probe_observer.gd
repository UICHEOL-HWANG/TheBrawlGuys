class_name ProbeObserver
extends RefCounted
## What a probing bot measures about its target (PRD-BOT-05), from state views only: every swing
## the bot starts within THREAT_RANGE is a threat, answered when the target guards or dodges
## within RESPONSE_TICKS (reaction ticks averaged); tumbles of the target and whether they ended
## in a tech; whiffs the probe marks and whether the target punished them within PUNISH_TICKS;
## damage traded, the target's attack starts and its time near the edge. Counters are kept per
## stage and in total; features() turns a counter set into the probe feature vector.

const THREAT_RANGE := 3.2
const RESPONSE_TICKS := 40
const PUNISH_TICKS := 60
const EDGE_SHARE := 0.8
## Feature values when a counter has no samples (a neutral prior, never NaN).
const NO_REACTION_TICKS := 40.0
const NO_RATE := 0.0
const FEATURES: Array[String] = [
	"react_ticks", "response_rate", "dodge_rate", "tech_rate", "punish_rate", "damage_share",
	"attack_rate", "edge_share",
]
const SWING_STATES: Array[int] = [Fighter.State.ATTACK, Fighter.State.CHARGE, Fighter.State.SPECIAL]

var _self_id: int
var _target: int
var _prev_me: Dictionary = {}
var _prev_foe: Dictionary = {}
var _threat_at: int = -1
var _whiff_at: int = -1
var total := {}
var stage := {}


func _init(self_id: int, target: int) -> void:
	_self_id = self_id
	_target = target
	total = new_counters()
	stage = new_counters()


static func new_counters() -> Dictionary:
	return {"threats": 0, "responses": 0, "dodges": 0, "react_sum": 0, "tumbles": 0, "techs": 0,
		"whiffs": 0, "punished": 0, "dealt": 0.0, "taken": 0.0, "attacks": 0, "ticks": 0, "edge_ticks": 0}


## A deliberate whiff (punish stage): watch whether the target hits back in time.
func mark_whiff(tick: int) -> void:
	_whiff_at = tick
	_add("whiffs", 1)


func observe(view: Dictionary) -> void:
	var me := BotViewQuery.find(view, _self_id)
	var foe := BotViewQuery.find(view, _target)
	if me.is_empty() or foe.is_empty():
		return
	var tick := int(view.get("tick", 0))
	if not _prev_me.is_empty():
		_observe_pair(me, foe, tick, float(view.get("arena_radius", 10.0)))
	_prev_me = me
	_prev_foe = foe


func _observe_pair(me: Dictionary, foe: Dictionary, tick: int, radius: float) -> void:
	_add("ticks", 1)
	var pos: Vector3 = foe["pos"]
	if Vector2(pos.x, pos.z).length() > radius * EDGE_SHARE:
		_add("edge_ticks", 1)
	if _started_swing(_prev_foe, foe):
		_add("attacks", 1)
	_damage(me, foe)
	_threats(me, foe, tick)
	_tumbles(foe)
	if _whiff_at >= 0 and tick - _whiff_at <= PUNISH_TICKS and float(me["damage"]) > float(_prev_me["damage"]):
		_add("punished", 1)
		_whiff_at = -1
	elif _whiff_at >= 0 and tick - _whiff_at > PUNISH_TICKS:
		_whiff_at = -1


func _damage(me: Dictionary, foe: Dictionary) -> void:
	_add("taken", maxf(0.0, float(me["damage"]) - float(_prev_me["damage"])))
	_add("dealt", maxf(0.0, float(foe["damage"]) - float(_prev_foe["damage"])))


func _threats(me: Dictionary, foe: Dictionary, tick: int) -> void:
	var dist := BotViewQuery.flat(me["pos"], foe["pos"]).length()
	if _started_swing(_prev_me, me) and dist <= THREAT_RANGE:
		_threat_at = tick
		_add("threats", 1)
	if _threat_at < 0:
		return
	if tick - _threat_at > RESPONSE_TICKS:
		_threat_at = -1
		return
	var dodging := bool(foe.get("is_dodging", false)) or int(foe["state"]) == Fighter.State.DODGE
	if dodging or int(foe["state"]) == Fighter.State.GUARD:
		_add("responses", 1)
		_add("react_sum", tick - _threat_at)
		_add("dodges", 1 if dodging else 0)
		_threat_at = -1


func _tumbles(foe: Dictionary) -> void:
	var was := bool(_prev_foe.get("tumbling", false))
	var now := bool(foe.get("tumbling", false))
	if now and not was:
		_add("tumbles", 1)
	elif was and not now and int(foe["state"]) != Fighter.State.KNOCKDOWN and int(foe["state"]) != Fighter.State.KO:
		_add("techs", 1)


static func _started_swing(prev: Dictionary, now: Dictionary) -> bool:
	return SWING_STATES.has(int(now["state"])) and not SWING_STATES.has(int(prev.get("state", -1)))


func _add(key: String, amount: Variant) -> void:
	total[key] += amount
	stage[key] += amount


## Ends a stage: its counters are returned and a fresh set starts.
func close_stage() -> Dictionary:
	var out := stage
	stage = new_counters()
	return out


## The probe feature vector of a counter set (FEATURES order; no NaN).
static func features(c: Dictionary) -> Dictionary:
	var responses := int(c["responses"])
	var traded := float(c["dealt"]) + float(c["taken"])
	return {
		"react_ticks": float(c["react_sum"]) / responses if responses > 0 else NO_REACTION_TICKS,
		"response_rate": _rate(responses, int(c["threats"])),
		"dodge_rate": _rate(int(c["dodges"]), int(c["threats"])),
		"tech_rate": _rate(int(c["techs"]), int(c["tumbles"])),
		"punish_rate": _rate(int(c["punished"]), int(c["whiffs"])),
		"damage_share": float(c["taken"]) / traded if traded > 0.0 else 0.5,
		"attack_rate": float(c["attacks"]) / maxf(float(c["ticks"]) / SimTime.TICK_RATE, 1.0),
		"edge_share": _rate(int(c["edge_ticks"]), int(c["ticks"])),
	}


static func _rate(n: int, of: int) -> float:
	return float(n) / of if of > 0 else NO_RATE
