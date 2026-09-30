extends SceneTree
## Phase 5 T6 balance simulation (PRD-STYLE-01~03): every ordered character pair (A in slot 0,
## B in slot 1, mirrors included) plays MATCHES bot-vs-bot 1v1 matches on the classic arena, one
## seed per match. Prints A's win-rate table and writes a CSV. A match that runs past MAX_TICKS is
## decided by stocks, then lower damage; a full tie counts as a draw (half a win each).
## Run: godot --headless --path . -s res://scripts/balance_sim.gd -- [--matches=N] [--a=id] [--out=path]
##   [--set=name:value,name:value]
## --a limits the rows to one character (for running rows in parallel); the default runs all.
## --set overrides GameConfig values for a tuning experiment (the committed table uses none).

const MATCHES := 100
const FIRST_SEED := 1000
const MAX_TICKS := 60 * 60 * 8
const OUT := "res://dev/active/phase-5/evidence/balance.csv"
const HEADER := "a,b,matches,a_wins,b_wins,draws,a_win_rate,avg_ticks"

static var _overrides: Dictionary = {}


func _init() -> void:
	var args := _args()
	var matches := int(args.get("matches", MATCHES))
	_overrides = _parse_overrides(String(args.get("set", "")))
	var rows: Array[String] = CharacterData.IDS
	if args.has("a"):
		rows = [String(args["a"])]
	var lines: Array[String] = [HEADER]
	for a: String in rows:
		for b: String in CharacterData.IDS:
			var r := _matchup(a, b, matches)
			lines.append("%s,%s,%d,%d,%d,%d,%.3f,%.1f" % [a, b, matches, r["a"], r["b"], r["draw"],
					_rate(r, matches), float(r["ticks"]) / matches])
	_print_table(lines)
	var out := String(args.get("out", OUT))
	_write(out, lines)
	print("balance_sim: wrote %s" % out)
	quit(0)


func _matchup(a: String, b: String, matches: int) -> Dictionary:
	var r := {"a": 0, "b": 0, "draw": 0, "ticks": 0}
	for i: int in matches:
		var result := play(a, b, FIRST_SEED + i)
		r[result["winner"]] += 1
		r["ticks"] += int(result["ticks"])
	return r


## One bot-vs-bot match: {"winner": "a" | "b" | "draw", "ticks": int}.
static func play(a: String, b: String, seed: int) -> Dictionary:
	var config := GameConfig.new()
	for key: String in _overrides:
		config.set(key, type_convert(_overrides[key], typeof(config.get(key))))
	var chars: Array[String] = [a, b]
	var w := World.new(config, seed, 2, null, chars)
	var bots: Array[BotController] = [BotController.new(0, config), BotController.new(1, config)]
	while not w.match_over and w.tick_count < MAX_TICKS:
		var view := w.state_view()
		w.tick([bots[0].sample(view), bots[1].sample(view)] as Array[InputFrame])
	return {"winner": _winner(w), "ticks": w.tick_count}


static func _winner(w: World) -> String:
	var f0 := w.fighters[0]
	var f1 := w.fighters[1]
	if w.match_over and w.winner_id >= 0:
		return "a" if w.winner_id == 0 else "b"
	if f0.stocks != f1.stocks:
		return "a" if f0.stocks > f1.stocks else "b"
	if not is_equal_approx(f0.damage, f1.damage):
		return "a" if f0.damage < f1.damage else "b"
	return "draw"


static func _rate(r: Dictionary, matches: int) -> float:
	return (float(r["a"]) + 0.5 * float(r["draw"])) / maxf(float(matches), 1.0)


func _print_table(lines: Array[String]) -> void:
	var rates := {}
	for line: String in lines.slice(1):
		var cols := line.split(",")
		rates["%s|%s" % [cols[0], cols[1]]] = float(cols[6])
	var head := "A \\ B".rpad(11)
	for b: String in CharacterData.IDS:
		head += b.rpad(11)
	print(head)
	for a: String in CharacterData.IDS:
		if not rates.has("%s|%s" % [a, CharacterData.IDS[0]]):
			continue
		var row := a.rpad(11)
		for b: String in CharacterData.IDS:
			row += ("%.0f%%" % (100.0 * float(rates["%s|%s" % [a, b]]))).rpad(11)
		print(row)


func _write(path: String, lines: Array[String]) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("balance_sim: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	f.store_string("\n".join(lines) + "\n")


static func _parse_overrides(spec: String) -> Dictionary:
	var out := {}
	for pair: String in spec.split(",", false):
		var kv := pair.split(":", true, 1)
		if kv.size() == 2 and GameConfig.new().get(kv[0]) != null:
			out[kv[0]] = kv[1].to_float()
		else:
			push_error("balance_sim: bad --set entry '%s'" % pair)
	return out


func _args() -> Dictionary:
	var out := {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var kv := arg.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	return out
