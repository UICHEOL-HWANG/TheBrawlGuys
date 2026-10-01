extends SceneTree
## Difficulty dial monotonicity sweep (PRD-BOT-03): for each d in --points, MATCHES 1v1 bot
## matches of a dial bot at d against a reference bot at --ref (0.5) on the classic arena. Match i
## cycles every ordered character pair (16) and swaps the slots every 16 matches, one seed per
## match, so character and slot effects cancel. Win rate counts a draw as half a win, with a 95 %
## Wilson interval. A match past MAX_TICKS is decided like balance_sim (stocks, then damage).
## Run: godot --headless --path . -s res://scripts/dda_sweep.gd -- --points=0,0.25 [--ref=0.5]
##   [--matches=150] [--out=path] [--set=param:value,...]   (shard by points; scripts/dda_sweep.sh
##   runs them in parallel). --set overrides BotSkill values of the dial bot (ablation runs).

const BalanceSim := preload("res://scripts/balance_sim.gd")

const MATCHES := 150
const REF_D := 0.5
const FIRST_SEED := 5000
const MAX_TICKS := 60 * 60 * 8
const Z95 := 1.96
static var _ablate: Dictionary = {}

const HEADER := "d,ref_d,matches,wins,losses,draws,win_rate,ci_lo,ci_hi,avg_ticks"


func _init() -> void:
	var args := _args()
	var matches := int(args.get("matches", MATCHES))
	var ref := float(args.get("ref", REF_D))
	for pair: String in String(args.get("set", "")).split(",", false):
		_ablate[pair.get_slice(":", 0)] = pair.get_slice(":", 1).to_float()
	var lines: Array[String] = [HEADER]
	for p: String in String(args.get("points", "0,0.25,0.5,0.75,1")).split(",", false):
		var r := sweep_point(p.to_float(), ref, matches)
		lines.append(row(p.to_float(), ref, matches, r))
		print(lines.back())
	var out := String(args.get("out", ""))
	if not out.is_empty():
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f == null:
			printerr("dda_sweep: cannot write %s" % out)
			quit(1)
			return
		f.store_string("\n".join(lines) + "\n")
	quit(0)


static func sweep_point(d: float, ref: float, matches: int) -> Dictionary:
	var r := {"win": 0, "loss": 0, "draw": 0, "ticks": 0}
	var ids := CharacterData.IDS
	for i: int in matches:
		var mine := ids[i % ids.size()]
		var theirs := ids[(i / ids.size()) % ids.size()]
		var swap := (i / (ids.size() * ids.size())) % 2 == 1
		var res := play(mine, theirs, d, ref, swap, FIRST_SEED + i)
		r[res["result"]] += 1
		r["ticks"] += int(res["ticks"])
	return r


## One match: the dial bot (character `mine`, dial d) vs the reference (theirs, dial ref).
## {"result": "win" | "loss" | "draw" (for the dial bot), "ticks": int}
static func play(mine: String, theirs: String, d: float, ref: float, swap: bool, seed: int) -> Dictionary:
	var config := GameConfig.new()
	var me := 1 if swap else 0
	var chars: Array[String] = [mine, theirs]
	if swap:
		chars = [theirs, mine]
	var w := World.new(config, seed, 2, null, chars)
	var bots: Array[BotController] = [
		BotController.new(0, config, ref if swap else d), BotController.new(1, config, d if swap else ref)]
	for key: String in _ablate:
		bots[me].skill().set(key, type_convert(_ablate[key], typeof(bots[me].skill().get(key))))
	while not w.match_over and w.tick_count < MAX_TICKS:
		var view := w.state_view()
		w.tick([bots[0].sample(view), bots[1].sample(view)] as Array[InputFrame])
	var winner := BalanceSim._winner(w)
	var result := "draw"
	if winner != "draw":
		result = "win" if (winner == "a") == (me == 0) else "loss"
	return {"result": result, "ticks": w.tick_count}


static func row(d: float, ref: float, matches: int, r: Dictionary) -> String:
	var rate := (float(r["win"]) + 0.5 * float(r["draw"])) / maxf(float(matches), 1.0)
	var ci := wilson(rate, matches)
	return "%.2f,%.2f,%d,%d,%d,%d,%.3f,%.3f,%.3f,%.1f" % [d, ref, matches, r["win"], r["loss"], r["draw"],
		rate, ci.x, ci.y, float(r["ticks"]) / maxf(float(matches), 1.0)]


## 95 % Wilson score interval of a rate over n trials.
static func wilson(rate: float, n: int) -> Vector2:
	if n <= 0:
		return Vector2(0.0, 1.0)
	var z2 := Z95 * Z95
	var centre := (rate + z2 / (2.0 * n)) / (1.0 + z2 / n)
	var half := Z95 * sqrt(rate * (1.0 - rate) / n + z2 / (4.0 * n * n)) / (1.0 + z2 / n)
	return Vector2(maxf(0.0, centre - half), minf(1.0, centre + half))


func _args() -> Dictionary:
	var out := {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var kv := arg.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	return out
