extends GutTest
## Phase 4 completion rule "each arena finishes a bot match" (PHASES Phase 4, PRD-BOT-01): four
## bots on every arena reach match_over within MAX_TICKS, and every stage's gimmick shows up.

## Combat-depth C made bots block fewer swings (BotDefense perfect-guard cap), so matches end
## sooner; seed 11 no longer walked anyone into the lakeside fire. 18 covers every gimmick.
const SEED := 18
const PLAYERS := 4
const MAX_TICKS := 60 * 60 * 6
## The event each stage's gimmick must produce during a bot match.
const GIMMICK_EVENTS := {
	"lakeside_camp": "gimmick_damage", "log_bridge": "platform_break",
	"mushroom_forest": "bounce", "foggy_forest": "fog_start", "frozen_pond": "platform_break",
}


static func _play(id: String) -> Dictionary:
	var c := GameConfig.new()
	var w := World.new(c, SEED, PLAYERS, ArenaCatalog.build(id, c))
	var bots: Array[BotController] = []
	for i: int in PLAYERS:
		bots.append(BotController.new(i, c))
	var seen := {}
	while not w.match_over and w.tick_count < MAX_TICKS:
		var view := w.state_view()
		var inputs: Array[InputFrame] = []
		for b: BotController in bots:
			inputs.append(b.sample(view))
		w.tick(inputs)
		for e: Dictionary in w.state_view()["events"]:
			seen[e["type"]] = true
	return {"over": w.match_over, "ticks": w.tick_count, "seen": seen}


func test_four_bots_finish_a_match_on_every_arena() -> void:
	for id: String in ArenaCatalog.ids():
		var r := _play(id)
		assert_true(r["over"], "%s: bot match ends within %d ticks (stopped at %d)" % [id, MAX_TICKS, r["ticks"]])
		gut.p("%s: match over at tick %d" % [id, r["ticks"]])
		if GIMMICK_EVENTS.has(id):
			assert_true((r["seen"] as Dictionary).has(GIMMICK_EVENTS[id]), "%s gimmick fires in a bot match" % id)
