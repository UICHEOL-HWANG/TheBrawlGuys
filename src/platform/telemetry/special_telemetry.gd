class_name SpecialTelemetry
extends RefCounted
## Special-move moments for Amplitude (Phase 5 T10, tracking-plan §3.5): gauge_full, special_used
## and special_hit, plus the specials / special_hits SlotStats counters. special_hit is one event
## per activation: it opens on the activation's first hit, gathers later targets and is sent when
## a hit target rings out (caused_ringout) or once StockLoss.WINDOW_TICKS pass, the next special
## of that slot starts, or the match ends. emit(name, props) sends; count(slot, counter) counts.

const NO_TIME := -1

var _emit: Callable
var _count: Callable
var _full_tick: Dictionary = {}  # slot -> tick its gauge last filled
var _open: Dictionary = {}  # slot -> {character, special, first_tick, targets: Array}


func _init(emit: Callable, count: Callable) -> void:
	_emit = emit
	_count = count


func on_event(e: Dictionary, tick: int, fighters: Array) -> void:
	match String(e["type"]):
		"gauge_full":
			var slot := int(e["fighter"])
			_full_tick[slot] = tick
			_emit.call("gauge_full", {"slot": slot, "character": String(e.get("character", "")),
				"match_time_s": MatchSummary.seconds(tick)})
		"special_start":
			_on_start(e, tick, fighters)
		"special_hit":
			_on_hit(e, tick)
		"ringout":
			_on_ringout(int(e["id"]))


## Sends every open activation whose ring-out window has passed.
func flush_due(tick: int) -> void:
	for slot: int in _open.keys():
		if tick - int(_open[slot]["first_tick"]) > StockLoss.WINDOW_TICKS:
			_send(slot, false)


## Match end: every open activation is sent as it stands.
func finish() -> void:
	for slot: int in _open.keys():
		_send(slot, false)


func _on_start(e: Dictionary, tick: int, fighters: Array) -> void:
	var slot := int(e["fighter"])
	if _open.has(slot):
		_send(slot, false)
	_count.call(slot, "specials")
	var since := NO_TIME
	if _full_tick.has(slot):
		since = roundi(float(tick - int(_full_tick[slot])) * 1000.0 / SimTime.TICK_RATE)
		_full_tick.erase(slot)
	_emit.call("special_used", {"slot": slot, "character": String(e.get("character", "")),
		"special": String(e.get("special", "")), "ms_since_full": since,
		"target_damage": nearest_foe_damage(fighters, slot)})


func _on_hit(e: Dictionary, tick: int) -> void:
	var slot := int(e["attacker"])
	var target := int(e["target"])
	_count.call(slot, "special_hits")
	if not _open.has(slot):
		_open[slot] = {"character": String(e.get("character", "")), "special": String(e.get("special", "")),
			"first_tick": tick, "targets": []}
	var targets: Array = _open[slot]["targets"]
	if not targets.has(target):
		targets.append(target)


func _on_ringout(victim: int) -> void:
	for slot: int in _open.keys():
		if (_open[slot]["targets"] as Array).has(victim):
			_send(slot, true)


func _send(slot: int, caused_ringout: bool) -> void:
	var open: Dictionary = _open[slot]
	_open.erase(slot)
	var targets: Array = open["targets"]
	_emit.call("special_hit", {"slot": slot, "character": open["character"], "special": open["special"],
		"targets_hit": targets.size(), "target_slot": int(targets[0]), "caused_ringout": caused_ringout})


## Damage % of the living foe nearest to slot on the ground plane (0 when there is none).
static func nearest_foe_damage(fighters: Array, slot: int) -> float:
	var me: Dictionary = {}
	for f: Dictionary in fighters:
		if int(f["id"]) == slot:
			me = f
	if me.is_empty():
		return 0.0
	var at: Vector3 = me["pos"]
	var best := INF
	var damage := 0.0
	for f: Dictionary in fighters:
		if int(f["id"]) == slot or int(f["state"]) == Fighter.State.KO:
			continue
		var p: Vector3 = f["pos"]
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d < best:
			best = d
			damage = float(f["damage"])
	return damage
