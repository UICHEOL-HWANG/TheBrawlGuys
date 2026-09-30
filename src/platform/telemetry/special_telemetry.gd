class_name SpecialTelemetry
extends RefCounted
## Special-move moments for Amplitude (Phase 5 T10, tracking-plan §3.5): gauge_full, special_used
## and special_hit, plus the specials / special_hits SlotStats counters. special_hit is one event
## per activation: it opens on the activation's first hit, gathers later targets and is sent when
## a hit target rings out with the ring-out credited to this slot (StockLoss last attacker, so a
## gimmick or another player's later hit does not count: caused_ringout) or, with false, once
## StockLoss.WINDOW_TICKS pass, the next special of that slot starts, or the match ends.
## The sim emits every hit of a tick before its ringouts (World step: Rules.apply runs last), so a
## same-tick ring-out already sees its hit. ms_since_full leaves out the ticks the slot spent KO.
## emit(name, props) sends; count(slot, counter) counts. Malformed events warn and are skipped.

const NO_TIME := -1
const REQUIRED := {
	"gauge_full": ["fighter"], "special_start": ["fighter"], "special_hit": ["attacker", "target"],
	"ringout": ["id"],
}

var _emit: Callable
var _count: Callable
var _full_tick: Dictionary = {}  # slot -> tick its gauge last filled
var _ko_ticks: Dictionary = {}  # slot -> ticks spent KO since its gauge filled
var _last_tick: int = 0
var _was_ko: Dictionary = {}  # slots KO in the last view (the ticks since then were spent KO)
var _open: Dictionary = {}  # slot -> {character, special, first_tick, targets: Array}


func _init(emit: Callable, count: Callable) -> void:
	_emit = emit
	_count = count


## e: a sim event; a ringout carries CombatTelemetry's credit (attacker_slot, cause) merged in.
func on_event(e: Dictionary, tick: int, fighters: Array) -> void:
	var type := String(e.get("type", ""))
	if not REQUIRED.has(type):
		return
	for key: String in REQUIRED[type]:
		if not e.has(key):
			push_warning("SpecialTelemetry: %s event without '%s', skipped" % [type, key])
			return
	match type:
		"gauge_full":
			_on_full(e, tick)
		"special_start":
			_on_start(e, tick, fighters)
		"special_hit":
			_on_hit(e, tick)
		"ringout":
			_on_ringout(int(e["id"]), int(e.get("attacker_slot", StockLoss.NONE)))


## Start of a tick: KO time since a full gauge, then activations whose ring-out window passed.
func begin_tick(fighters: Array, tick: int) -> void:
	for f: Dictionary in fighters:
		var slot := int(f.get("id", -1))
		if _full_tick.has(slot) and _was_ko.has(slot):
			_ko_ticks[slot] = int(_ko_ticks.get(slot, 0)) + maxi(tick - _last_tick, 0)
	_was_ko.clear()
	for f: Dictionary in fighters:
		if int(f.get("state", Fighter.State.IDLE)) == Fighter.State.KO:
			_was_ko[int(f.get("id", -1))] = true
	_last_tick = tick
	for slot: int in _open.keys():
		if tick - int(_open[slot]["first_tick"]) > StockLoss.WINDOW_TICKS:
			_send(slot, false)


## Match end: every open activation is sent as it stands.
func finish() -> void:
	for slot: int in _open.keys():
		_send(slot, false)


func _on_full(e: Dictionary, tick: int) -> void:
	var slot := int(e["fighter"])
	_full_tick[slot] = tick
	_ko_ticks[slot] = 0
	_emit.call("gauge_full", {"slot": slot, "character": String(e.get("character", "")),
		"match_time_s": MatchSummary.seconds(tick)})


func _on_start(e: Dictionary, tick: int, fighters: Array) -> void:
	var slot := int(e["fighter"])
	if _open.has(slot):
		_send(slot, false)
	_count.call(slot, "specials")
	var since := NO_TIME
	if _full_tick.has(slot):
		var live := tick - int(_full_tick[slot]) - int(_ko_ticks.get(slot, 0))
		since = roundi(float(maxi(live, 0)) * 1000.0 / SimTime.TICK_RATE)
		_full_tick.erase(slot)
		_ko_ticks.erase(slot)
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


## Only the slot credited with the ring-out (StockLoss) caused it.
func _on_ringout(victim: int, credited: int) -> void:
	if _open.has(credited) and (_open[credited]["targets"] as Array).has(victim):
		_send(credited, true)


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
		if int(f.get("id", -1)) == slot:
			me = f
	if not me.has("pos"):
		return 0.0
	var at: Vector3 = me["pos"]
	var best := INF
	var damage := 0.0
	for f: Dictionary in fighters:
		if int(f.get("id", -1)) == slot or int(f.get("state", 0)) == Fighter.State.KO or not f.has("pos"):
			continue
		var p: Vector3 = f["pos"]
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d < best:
			best = d
			damage = float(f.get("damage", 0.0))
	return damage
