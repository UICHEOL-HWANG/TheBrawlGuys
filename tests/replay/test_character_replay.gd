extends GutTest
## Per-character replay regression (Phase 5, PHASES "스타일별 해시"). Each character plays slot 0
## against the next character in CharacterData.IDS on the classic arena with a fixed input script
## (_inputs_at: a function of the tick and positions only); slot 0 starts with a full gauge so its
## special fires early. CHARACTER_HASHES must change only with deliberate sim changes (say why in
## the commit message). Values are tied to Godot 4.7.2 (engine floats).

const SEED := 9
const TICKS := 1200
const HALF := 600
## Slot 1 starts part-filled so its gauge fills (gauge_full) during the run.
const PRIMED_GAUGE := 60.0
const CLOSE := 1.2
const XC_HOLD := 20
const CHARACTER_HASHES := {
	"barbarian": 2926200867,
	"rogue": 479106545,
	"knight": 501189268,
	"mage": 2234885451,
}


## Both fighters walk at each other (standing still once within CLOSE), P0 presses light and
## holds heavy, P1 presses light, guards in bursts and grabs; each holds X+C for XC_HOLD ticks
## now and then (from guard it fires as soon as the gauge is full).
static func _inputs_at(w: World) -> Array[InputFrame]:
	var t := w.tick_count
	var out: Array[InputFrame] = []
	for id: int in 2:
		var me := w.fighters[id].pos
		var foe := w.fighters[1 - id].pos
		var d := Vector2(foe.x - me.x, foe.z - me.z)
		var m := d.normalized() if d.length() > CLOSE else Vector2.ZERO
		if id == 0:
			var xc := t % 200 >= 150 and t % 200 < 150 + XC_HOLD
			var heavy := xc or (t % 240 >= 100 and t % 240 < 115)
			out.append(InputFrame.make(m.x, m.y, false, t % 23 == 0, heavy, xc))
		else:
			var xc := t % 250 >= 200 and t % 250 < 200 + XC_HOLD
			var guard := xc or (t % 180 >= 120 and t % 180 < 140)
			out.append(InputFrame.make(m.x, m.y, t % 97 == 40, t % 29 == 7, xc, guard, t % 131 == 60))
	return out


static func _world(character: String) -> World:
	var ids := CharacterData.IDS
	var chars: Array[String] = [character, ids[(ids.find(character) + 1) % ids.size()]]
	var w := World.new(GameConfig.new(), SEED, 2, null, chars)
	w.fighters[0].gauge = SpecialGauge.MAX
	w.fighters[1].gauge = PRIMED_GAUGE
	return w


## Runs `ticks` ticks: {"hash": hash of per-tick state hashes, "seen": event types}.
static func _run(w: World, ticks: int) -> Dictionary:
	var seq: Array[int] = []
	var seen := {}
	for i: int in ticks:
		w.tick(_inputs_at(w))
		seq.append(w.state_hash())
		for e: Dictionary in w.state_view()["events"]:
			seen[e["type"]] = true
	return {"hash": hash(seq), "seen": seen}


func test_each_character_replays_to_its_golden_hash() -> void:
	for id: String in CharacterData.IDS:
		var r := _run(_world(id), TICKS)
		var seen: Dictionary = r["seen"]
		assert_true(seen.has("special_start"), "%s: the special fires" % id)
		assert_true(seen.has("hit"), "%s: fighters trade hits" % id)
		var expected: int = CHARACTER_HASHES[id]
		assert_ne(expected, 0, "%s hash not set yet; set it to %d" % [id, r["hash"]])
		assert_eq(r["hash"], expected, "%s changed; if deliberate, update CHARACTER_HASHES to %d" % [id, r["hash"]])


func test_the_scripts_exercise_projectiles_and_special_hits() -> void:
	var seen := {}
	for id: String in CharacterData.IDS:
		seen.merge(_run(_world(id), TICKS)["seen"])
	for needed: String in ["projectile_spawn", "projectile_hit", "special_hit", "gauge_full"]:
		assert_true(seen.has(needed), "%s must happen in some character replay" % needed)


func test_each_character_restores_mid_run_and_continues_identically() -> void:
	for id: String in CharacterData.IDS:
		var straight := _world(id)
		_run(straight, HALF)
		var snap := straight.snapshot()
		var rest := _run(straight, TICKS - HALF)
		var resumed := _world(id)
		assert_true(resumed.restore(snap), id)
		assert_eq(_run(resumed, TICKS - HALF)["hash"], rest["hash"], "%s after restore" % id)
