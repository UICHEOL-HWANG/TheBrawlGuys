extends SceneTree
## DDA convergence check (PRD-BOT-06): a fixed-d "player" bot (treated as the human, slot 0 or 1)
## plays MATCHES 1v1 matches in a row against a BotSquad bot with the dda variant on (probe while
## the rating holds < dda_probe_matches observations, rating carried across the run, DDA with the
## models in res://data/models/) or off (bot fixed at the normal preset). Characters cycle every
## ordered pair; one seed per match. Prints and writes one CSV row per (player d, variant).
## Run: godot --headless --path . -s res://scripts/dda_converge.gd -- --player-d=0.3 --variant=on
##   [--matches=100] [--out=path]   (scripts/dda_converge.sh runs the grid in parallel)

const BalanceSim := preload("res://scripts/balance_sim.gd")
const DdaSweep := preload("res://scripts/dda_sweep.gd")

const MATCHES := 100
const FIRST_SEED := 9000
const MAX_TICKS := 60 * 60 * 8
const HEADER := "player_d,variant,matches,player_win_rate,ci_lo,ci_hi,bot_d_end_mean,adjustments_mean,probe_estimate_mean,rating_end"


func _init() -> void:
	var args := _args()
	var d := float(args.get("player-d", 0.5))
	var variant := String(args.get("variant", BotSquad.ON))
	var matches := int(args.get("matches", MATCHES))
	var line := run(d, variant, matches)
	print(HEADER)
	print(line)
	var out := String(args.get("out", ""))
	if not out.is_empty():
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f != null:
			f.store_string(HEADER + "\n" + line + "\n")
	quit(0)


static func run(d: float, variant: String, matches: int) -> String:
	var config := GameConfig.new()
	var rating := SkillRating.new()
	var models := {"win_prob": BotSquadFactory.model(BotSquadFactory.WIN_PROB_PATH),
		"estimator": BotSquadFactory.model(BotSquadFactory.ESTIMATOR_PATH)}
	var t := {"wins": 0.0, "d_end": 0.0, "adjust": 0.0, "probe": 0.0, "probes": 0}
	var ids := CharacterData.IDS
	for i: int in matches:
		var chars: Array[String] = [ids[i % ids.size()], ids[(i / ids.size()) % ids.size()]]
		var me := (i / (ids.size() * ids.size())) % 2  # the player swaps slots every 16 matches
		var r := play(config, chars, d, variant, rating, models, FIRST_SEED + i, me)
		t["wins"] += float(r["score"])
		t["d_end"] += float(r["bot_d_end"])
		t["adjust"] += float(r["adjustments"])
		if r["probe_estimate"] != null:
			t["probe"] += float(r["probe_estimate"])
			t["probes"] += 1
	var rate := float(t["wins"]) / matches
	var ci := DdaSweep.wilson(rate, matches)
	var probe: float = float(t["probe"]) / t["probes"] if int(t["probes"]) > 0 else -1.0
	return "%.2f,%s,%d,%.3f,%.3f,%.3f,%.3f,%.2f,%.3f,%.3f" % [d, variant, matches, rate, ci.x, ci.y,
		float(t["d_end"]) / matches, float(t["adjust"]) / matches, probe, rating.rating()]


## One match; score = 1 win, 0.5 draw, 0 loss for the player.
static func play(config: GameConfig, chars: Array[String], d: float, variant: String, rating: SkillRating,
		models: Dictionary, seed: int, me: int = 0) -> Dictionary:
	var bot_slot := 1 - me
	var w := World.new(config, seed, 2, null, chars if me == 0 else ([chars[1], chars[0]] as Array[String]))
	var player := BotController.new(me, config, d)
	var squad := BotSquad.new(config, [bot_slot] as Array[int], [me] as Array[int], {"variant": variant,
		"rating": rating, "probe": rating.matches() < config.dda_probe_matches,
		"win_prob": models["win_prob"], "estimator": models["estimator"]})
	var view := w.state_view()
	while not w.match_over and w.tick_count < MAX_TICKS:
		var inputs: Array[InputFrame] = [player.sample(view), squad.sample(bot_slot, view)]
		if me == 1:
			inputs.reverse()
		w.tick(inputs)
		view = w.state_view()
		squad.after_tick(view, null)
	squad.finish(view)
	var winner := BalanceSim._winner(w)
	var summary := squad.slot_summary(bot_slot)
	var mine := "a" if me == 0 else "b"
	return {"score": 1.0 if winner == mine else (0.5 if winner == "draw" else 0.0),
		"bot_d_end": summary["bot_d_end"], "adjustments": summary["dda_adjustments"],
		"probe_estimate": summary["probe_estimate"]}


func _args() -> Dictionary:
	var out := {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var kv := arg.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	return out
