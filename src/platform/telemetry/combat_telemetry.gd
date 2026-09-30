class_name CombatTelemetry
extends RefCounted
## Combat bookkeeping for MatchTelemetry (platform A6): turns sim events and fighter views into
## SlotStats counters, the stock_lost / gimmick / item / special Amplitude events and the extra raw-row
## fields (attack_kind on hits, cause and credited attacker on ringouts). Split out of
## MatchTelemetry so the match lifecycle and the combat reading stay one responsibility each.

const GIMMICK_TYPES: Array[String] = ["platform_break", "bounce"]
const GIMMICK_PREFIX := "gimmick_"

var _stat: Callable  # slot -> SlotStats
var _emit: Callable  # (event_name, props)
var _loss := StockLoss.new()
var _attacks := AttackTracker.new()
var _items := ItemTelemetry.new()
var _specials: SpecialTelemetry
var _prev: Array = []
var _dealer: Dictionary = {}  # target -> attacker of this tick's last hit


func _init(stat: Callable, emit: Callable) -> void:
	_stat = stat
	_emit = emit
	_specials = SpecialTelemetry.new(emit, _count)


## Fighter views of the previous tick (damage at death, swing starts).
func previous() -> Array:
	return _prev


## Start of a tick: swings opened or closed since the last view, special hits whose window passed.
func begin_tick(fighters: Array, tick: int) -> void:
	_specials.begin_tick(fighters, tick)
	var seen := _attacks.observe(_prev, fighters)
	for slot: int in seen["whiffs"]:
		_count(slot, "whiffs")
	for opened: Array in seen["opened"]:
		_items.on_swing(int(opened[0]), int(opened[1]), _emit, _count)
	_dealer.clear()


## Handles one sim event; returns extra payload fields for its raw row (analysis.sql reads them).
func on_event(e: Dictionary, tick: int, fighters: Array, arena_radius: float) -> Dictionary:
	var type := String(e["type"])
	var extra := {}
	match type:
		"hit", "guard_hit":
			var attacker := int(e["attacker"])
			var target := int(e["target"])
			_attacks.mark_hit(attacker)
			_loss.note_attack(target, attacker, tick)
			_dealer[target] = attacker
			_count(target if type == "guard_hit" else attacker, "guards" if type == "guard_hit" else "hits")
			extra["attack_kind"] = MatchSummary.attack_kind_name(fighters, attacker)
		"grab":
			_count(int(e["attacker"]), "grabs")
			_loss.note_attack(int(e["target"]), int(e["attacker"]), tick)
		"ringout":
			extra = _on_ringout(e, tick, arena_radius)
	if type.begins_with(GIMMICK_PREFIX) or GIMMICK_TYPES.has(type):
		var victim := MatchSummary.fighter_of(e)
		if victim >= 0:
			_loss.note_gimmick(victim, String(e.get("kind", type)), tick)
		_emit.call("gimmick_triggered", {"kind": String(e.get("kind", type)), "victim_slot": victim})
	_items.on_event(e, _emit, _count)
	_specials.on_event(e.merged(extra), tick, fighters)
	return extra


## End of a tick: damage deltas are credited, then this view becomes the previous one.
func end_tick(fighters: Array) -> void:
	_track_damage(fighters)
	_prev = fighters


## Match end: every swing still open is closed (and counted as a whiff when it never landed) and
## every open special hit is sent.
func finish() -> void:
	_specials.finish()
	for slot: int in _attacks.close_all():
		_count(slot, "whiffs")


func _on_ringout(e: Dictionary, tick: int, arena_radius: float) -> Dictionary:
	var victim := int(e["id"])
	var pos: Vector3 = e["pos"]
	var why := _loss.classify(victim, tick)
	var attacker := int(why["attacker_slot"])
	_count(victim, "falls")
	if attacker >= 0:
		_count(attacker, "ringouts_scored")
	_emit.call("stock_lost", {"victim_slot": victim, "attacker_slot": attacker, "cause": why["cause"],
		"damage_at_death": MatchSummary.damage_of(_prev, victim), "angle_deg": StockLoss.angle_deg(pos),
		"zone": StockLoss.zone(pos, arena_radius), "stocks_left": int(e["stocks_left"])})
	if why["cause"] == "gimmick":
		_count(victim, "falls_by_gimmick")
		_emit.call("gimmick_ringout", {"kind": why["gimmick_kind"], "victim_slot": victim})
	return {"cause": why["cause"], "attacker_slot": attacker}


## Damage rises between ticks of the same life are taken by the victim and dealt by this tick's hitter.
func _track_damage(fighters: Array) -> void:
	for i: int in mini(_prev.size(), fighters.size()):
		var a: Dictionary = _prev[i]
		var b: Dictionary = fighters[i]
		var delta := float(b["damage"]) - float(a["damage"])
		if int(a["spawn_id"]) != int(b["spawn_id"]) or delta <= 0.0:
			continue
		var victim := int(b["id"])
		(_stat.call(victim) as SlotStats).damage_taken += delta
		if _dealer.has(victim) and int(_dealer[victim]) != victim:
			(_stat.call(int(_dealer[victim])) as SlotStats).damage_dealt += delta


func _count(slot: int, counter: String) -> void:
	(_stat.call(slot) as SlotStats).add(counter)
