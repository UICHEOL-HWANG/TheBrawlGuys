class_name MatchFeatures
extends RefCounted
## Per-slot behaviour features of one match (platform A8, analytics-strategy §3.2): input habits
## (InputFeatures), spatial habits (SpatialFeatures) and match flow (FlowFeatures), plus rates from
## the SlotStats summary. summary() keys are match_players columns (COLUMNS, migration 0002) and
## ride along in match_ended.players.

const RATIO_STEP := 0.001
const RATE_STEP := 0.1
const TICKS_PER_MINUTE := 60.0 * SimTime.TICK_RATE
const COLUMNS: Array[String] = [
	"press_light", "press_heavy", "press_guard", "press_grab", "press_jump", "press_special",
	"inputs_per_min", "direction_changes", "mash_ratio", "guard_hold_ratio", "idle_gaps",
	"hit_accuracy", "max_combo", "damage_per_min", "distance_travelled", "avg_nearest_opponent_dist",
	"edge_time_ratio", "air_time_ratio", "item_hold_ticks", "first_item_tick", "contested_pickups",
	"first_blood", "comeback_win",
]

var _inputs: InputFeatures
var _spatial: SpatialFeatures
var _flow: FlowFeatures


func _init(slot_count: int) -> void:
	_inputs = InputFeatures.new(slot_count)
	_spatial = SpatialFeatures.new(slot_count)
	_flow = FlowFeatures.new(slot_count)


## One tick: enriched sim events, last and current fighter views, and the inputs (may be empty).
func observe(tick: int, events: Array, prev: Array, fighters: Array, arena_radius: float, inputs: Array) -> void:
	if not inputs.is_empty():
		_inputs.observe(inputs)
	_spatial.observe(prev, fighters, arena_radius)
	_flow.observe(tick, events, prev, fighters)


## base: the SlotStats summary with "result" (hits, whiffs, damage_dealt are read).
func summary(slot: int, base: Dictionary, ticks: int) -> Dictionary:
	var out := _inputs.summary(slot)
	out.merge(_spatial.summary(slot))
	out.merge(_flow.summary(slot, String(base.get("result", ""))))
	var swings := int(base.get("hits", 0)) + int(base.get("whiffs", 0))
	out["hit_accuracy"] = snappedf(float(base["hits"]) / swings, RATIO_STEP) if swings > 0 else null
	var minutes := maxf(ticks / TICKS_PER_MINUTE, 1.0 / TICKS_PER_MINUTE)
	out["damage_per_min"] = snappedf(float(base.get("damage_dealt", 0.0)) / minutes, RATE_STEP)
	return out


func abandon_context(local_slot: int, fighters: Array, tick: int) -> Dictionary:
	return _flow.abandon_context(local_slot, fighters, tick)
