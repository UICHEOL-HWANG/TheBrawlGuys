extends GutTest
## Per-arena replay regression (Phase 4 T5, PHASES "경기장별 고정 입력 시퀀스 해시"). Each stage
## runs a fixed input script: P0 walks a stage-specific waypoint tour through its gimmick (one
## waypoint every WAYPOINT_TICKS, standing still once there) while P1 walks at P0 pressing
## light, jump, guard and grab on fixed tick patterns. Inputs depend only on t and positions, so
## a run is fully reproducible. ARENA_HASHES must change only with deliberate sim changes (say
## why in the commit message). Values are tied to Godot 4.7.2 (engine floats). The frozen pond's
## Ice config group re-recorded the four Phase 4 values through the config fingerprint only: with
## config_fp stripped, their per-tick snapshots are bit-identical to before.

const SEED := 5
const TICKS := 2400
const HALF := 1200
const WAYPOINT_TICKS := 240
const ARRIVED := 0.3
const ARENA_HASHES := {
	"lakeside_camp": 1671949093,
	"log_bridge": 715661931,
	"mushroom_forest": 3823209953,
	"foggy_forest": 2068026426,
	"frozen_pond": 167019613,
}
const TOURS := {
	"lakeside_camp": [Vector3(-4.0, 0, -3.5), Vector3(0, 0, 0), Vector3(8.5, 0, 0)],
	"log_bridge": [Vector3(-9.0, 0, -1.5), Vector3(-3.0, 0, 0), Vector3(3.0, 0, 1.5)],
	"mushroom_forest": [Vector3(5.16, 0, 5.16), Vector3(0, 0, 0), Vector3(-7.05, 0, 1.89)],
	"foggy_forest": [Vector3(0, 0, 0), Vector3(-3.0, 0, 3.0), Vector3(3.0, 0, -3.0)],
	"frozen_pond": [Vector3(3.75, 0, 0), Vector3(0, 0, 0), Vector3(-3.75, 0, 3.75)],
}
## The gimmick event each tour must produce, or the hash guards nothing on that stage.
const GIMMICK_EVENTS := {
	"lakeside_camp": "gimmick_damage", "log_bridge": "platform_break",
	"mushroom_forest": "bounce", "foggy_forest": "fog_start", "frozen_pond": "platform_break",
}


static func _inputs_at(w: World, id: String) -> Array[InputFrame]:
	var t := w.tick_count
	var tour: Array = TOURS[id]
	var goal: Vector3 = tour[floori(float(t) / WAYPOINT_TICKS) % tour.size()]
	var p0 := w.fighters[0].pos
	var d := Vector2(goal.x - p0.x, goal.z - p0.z)
	var move := d.normalized() if d.length() > ARRIVED else Vector2.ZERO
	var p1 := w.fighters[1].pos
	var chase := Vector2(p0.x - p1.x, p0.z - p1.z)
	var c := chase.normalized() if chase.length() > 1.0 else Vector2.ZERO
	var guard := t % 180 >= 120 and t % 180 < 140
	var out: Array[InputFrame] = [
		InputFrame.make(move.x, move.y, false, t % 97 == 40),
		InputFrame.make(c.x, c.y, t % 70 == 35, t % 25 == 5, false, guard, t % 131 == 60),
	]
	return out


static func _world(id: String) -> World:
	var c := GameConfig.new()
	return World.new(c, SEED, 2, ArenaCatalog.build(id, c))


## Runs `ticks` ticks and returns {"hash": hash of per-tick state hashes, "seen": event types}.
static func _run(w: World, id: String, ticks: int) -> Dictionary:
	var seq: Array[int] = []
	var seen := {}
	for i: int in ticks:
		w.tick(_inputs_at(w, id))
		seq.append(w.state_hash())
		for e: Dictionary in w.state_view()["events"]:
			seen[e["type"]] = true
	return {"hash": hash(seq), "seen": seen}


func test_each_arena_replays_to_its_golden_hash() -> void:
	for id: String in ArenaCatalog.stage_ids():
		var r := _run(_world(id), id, TICKS)
		var seen: Dictionary = r["seen"]
		assert_true(seen.has(GIMMICK_EVENTS[id]), "%s: the tour triggers %s" % [id, GIMMICK_EVENTS[id]])
		assert_true(seen.has("hit"), "%s: fighters trade hits" % id)
		var expected: int = ARENA_HASHES[id]
		assert_ne(expected, 0, "%s hash not set yet; set it to %d" % [id, r["hash"]])
		assert_eq(r["hash"], expected, "%s changed; if deliberate, update ARENA_HASHES to %d" % [id, r["hash"]])


func test_each_arena_restores_mid_run_and_continues_identically() -> void:
	for id: String in ArenaCatalog.stage_ids():
		var straight := _world(id)
		_run(straight, id, HALF)
		var snap := straight.snapshot()
		var rest := _run(straight, id, TICKS - HALF)
		var resumed := _world(id)
		assert_true(resumed.restore(snap), id)
		assert_eq(_run(resumed, id, TICKS - HALF)["hash"], rest["hash"], "%s after restore" % id)
