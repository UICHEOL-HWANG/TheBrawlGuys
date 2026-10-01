class_name SkillFeatures
extends RefCounted
## Skill and context signals per slot (event schema 8, docs/superpowers/specs analytics-ml Part 1):
## reactions and roll evades (ReactionFeatures), DI and survived tumbles (LaunchFeatures), choices
## at the edge or high damage (DangerFeatures) and team assists (AssistFeatures). summary() keys are
## match_players columns (COLUMNS, migration 0004) and ride along in match_ended.players.

const COLUMNS: Array[String] = [
	"threats_faced", "reactions", "reaction_ticks_avg", "roll_evades", "tech_attempts",
	"di_inputs", "di_perp_avg", "tumbles", "tumbles_survived",
	"edge_guard_presses", "edge_attack_presses", "edge_dodges",
	"high_dmg_guard_presses", "high_dmg_attack_presses", "high_dmg_dodges", "high_dmg_ticks",
	"team_assists",
]

var _reaction: ReactionFeatures
var _launch: LaunchFeatures
var _danger: DangerFeatures
var _assist: AssistFeatures
var _held: Array[Dictionary] = []  # per slot: buttons held on the last tick


func _init(slot_count: int) -> void:
	_reaction = ReactionFeatures.new(slot_count)
	_launch = LaunchFeatures.new(slot_count)
	_danger = DangerFeatures.new(slot_count)
	_assist = AssistFeatures.new(slot_count)
	for i: int in slot_count:
		_held.append({"guard": false, "attack": false})


## One tick: enriched sim events, last and current views, inputs (may be empty), teams (team mode).
func observe(tick: int, events: Array, prev: Array, fighters: Array, arena_radius: float, inputs: Array,
		teams: Array) -> void:
	var presses := _presses(inputs)
	_reaction.observe(tick, events, prev, fighters, presses, teams)
	_launch.observe(events, prev, fighters, inputs)
	_danger.observe(events, prev, arena_radius, presses)
	_assist.observe(tick, events, teams)


func summary(slot: int) -> Dictionary:
	var out := _reaction.summary(slot)
	out.merge(_launch.summary(slot))
	out.merge(_danger.summary(slot))
	out.merge(_assist.summary(slot))
	return out


## Rising edges this tick per slot: {"guard": bool, "attack": bool (light or heavy)}.
func _presses(inputs: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot: int in mini(inputs.size(), _held.size()):
		var f: InputFrame = inputs[slot]
		var held := {"guard": f.guard, "attack": f.light or f.heavy}
		out.append({"guard": held["guard"] and not _held[slot]["guard"],
			"attack": held["attack"] and not _held[slot]["attack"]})
		_held[slot] = held
	return out
