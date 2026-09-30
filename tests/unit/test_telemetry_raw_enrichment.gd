extends GutTest
## Raw match_events rows carry the analysis fields that supabase/queries/analysis.sql reads:
## hit/guard_hit rows name the attacker's attack kind (sim hit events do not carry it), and
## ringout rows name the cause and the credited attacker (same classification as stock_lost).

const K := AttackSet.Kind
const S := Fighter.State

var _t: MatchTelemetry
var _view: Dictionary


func before_each() -> void:
	_t = MatchTelemetry.new(func(_n: String, _p: Dictionary) -> void: pass)
	_t.begin({
		"match_id": "m-2", "mode": "bot", "arena": "default", "seed": 1, "local_slot": 0,
		"started_at": "2026-09-30T12:00:00Z",
		"slots": [
			{"slot": 0, "is_bot": false, "character": "Knight", "style": "", "input_device": "keyboard"},
			{"slot": 1, "is_bot": true, "character": "Mage", "style": "", "input_device": "bot"},
		],
	})
	_view = {"tick": 0, "arena_radius": 10.0, "match_over": false, "winner": -1,
		"fighters": [_f(0), _f(1)], "items": [], "events": []}


func _f(id: int) -> Dictionary:
	return {"id": id, "spawn_id": 0, "pos": Vector3.ZERO, "state": S.IDLE, "on_ground": true,
		"damage": 0.0, "stocks": 3, "attack_kind": 0, "attack_ticks": 0}


func _frame(tick: int, events: Array, changes: Dictionary = {}) -> void:
	var fighters: Array = []
	for f: Dictionary in _view["fighters"]:
		fighters.append(f.duplicate())
	for id: int in changes:
		fighters[id].merge(changes[id], true)
	_view = _view.duplicate()
	_view["fighters"] = fighters
	_view["tick"] = tick
	_t.on_frame(events, [], _view)


func _row(type: String) -> Dictionary:
	for r: Dictionary in _t.event_rows():
		if r["type"] == type:
			return r
	return {}


func test_hit_row_names_the_attack_kind_from_the_attacker_view() -> void:
	_frame(1, [{"type": "hit", "attacker": 0, "target": 1, "pos": Vector3.ZERO, "knockback": 3.0}],
			{0: {"state": S.ATTACK, "attack_kind": K.HEAVY}})
	var hit := _row("hit")
	assert_eq(hit["payload"]["attack_kind"], "HEAVY")
	assert_eq(hit["payload"]["knockback"], 3.0)
	assert_eq(hit.keys().size(), 6, "column set unchanged")


func test_ringout_row_names_cause_and_credited_attacker() -> void:
	_frame(1, [{"type": "hit", "attacker": 0, "target": 1, "pos": Vector3.ZERO, "knockback": 9.0}],
			{0: {"state": S.ATTACK, "attack_kind": K.LIGHT_1}})
	_frame(60, [{"type": "ringout", "id": 1, "pos": Vector3(20, -5, 0), "stocks_left": 2}])
	var ringout := _row("ringout")
	assert_eq(ringout["actor_slot"], 1, "the fighter who fell stays the actor")
	assert_eq(ringout["payload"]["cause"], "knockback")
	assert_eq(ringout["payload"]["attacker_slot"], 0)


func test_ringout_without_attacker_is_self() -> void:
	_frame(5, [{"type": "ringout", "id": 0, "pos": Vector3(0, -9, 0), "stocks_left": 2}])
	var ringout := _row("ringout")
	assert_eq(ringout["payload"]["cause"], "self")
	assert_eq(ringout["payload"]["attacker_slot"], -1)
