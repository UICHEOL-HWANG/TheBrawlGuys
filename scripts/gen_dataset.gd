extends SceneTree
## A9 synthetic dataset generator: plays N bot-only matches (varied rule, arena, player count,
## characters and bot tuning — DatasetSpec) with the shipped sim config, runs each through the
## game's telemetry code and writes the Supabase table shapes as CSV plus a 1 Hz state timeline:
##   matches.csv, match_players.csv, match_events.csv, timeline.csv
## Match i uses seed (--seed + i) and id 5e7d0000-...-<i>, so a run is reproducible and --first
## lets shards run in parallel into separate directories (the analysis loader concatenates them).
## Run: godot --headless --path . -s res://scripts/gen_dataset.gd -- --matches=400 --seed=1
##   --out-dir=analysis/data/synthetic [--first=0]

const DatasetMatch := preload("res://scripts/dataset/dataset_match.gd")
const TimelineSampler := preload("res://scripts/dataset/timeline_sampler.gd")
const CsvTable := preload("res://scripts/dataset/csv_table.gd")

const CONFIG_PATH := "res://src/config/default_config.tres"
const DEFAULT_MATCHES := 20
const DEFAULT_SEED := 1
const DEFAULT_OUT := "analysis/data/synthetic"
const EVENT_COLUMNS: Array[String] = ["match_id", "tick", "type", "actor_slot", "target_slot", "payload"]
const PROGRESS_EVERY := 25


func _init() -> void:
	var args := _args()
	var config := load(CONFIG_PATH) as GameConfig
	if config == null:
		printerr("gen_dataset: GameConfig missing at %s" % CONFIG_PATH)
		quit(1)
		return
	var out_dir := _out_dir(String(args.get("out-dir", DEFAULT_OUT)))
	if DirAccess.make_dir_recursive_absolute(out_dir) != OK and not DirAccess.dir_exists_absolute(out_dir):
		printerr("gen_dataset: cannot create %s" % out_dir)
		quit(1)
		return
	var count := int(args.get("matches", DEFAULT_MATCHES))
	var summary := _run(count, int(args.get("seed", DEFAULT_SEED)), int(args.get("first", 0)), out_dir, config)
	print("gen_dataset: %d matches (%d finished, %d hit the tick cap), %d timeline rows -> %s" % [
		count, summary["finished"], count - int(summary["finished"]), summary["timeline"], out_dir])
	quit(0)


func _run(count: int, seed: int, first: int, out_dir: String, config: GameConfig) -> Dictionary:
	var matches := CsvTable.new(out_dir.path_join("matches.csv"))
	var players := CsvTable.new(out_dir.path_join("match_players.csv"))
	var events := CsvTable.new(out_dir.path_join("match_events.csv"), EVENT_COLUMNS)
	var timeline := CsvTable.new(out_dir.path_join("timeline.csv"), TimelineSampler.COLUMNS)
	var summary := {"finished": 0, "timeline": 0}
	var started := Time.get_ticks_msec()
	for i: int in count:
		var index := first + i
		var played := DatasetMatch.play(index, seed + index, config)
		matches.add(played["match"])
		players.add_all(played["players"])
		events.add_all(played["events"])
		timeline.add_all(played["timeline"])
		summary["timeline"] += (played["timeline"] as Array).size()
		if played["match"]["winner_slot"] != null or _any_draw(played["players"]):
			summary["finished"] += 1
		if (i + 1) % PROGRESS_EVERY == 0:
			print("gen_dataset: %d/%d (%.1f s)" % [i + 1, count, (Time.get_ticks_msec() - started) / 1000.0])
	for t: Variant in [matches, players, events, timeline]:
		t.close()
	return summary


static func _any_draw(players: Array) -> bool:
	for p: Dictionary in players:
		if p.get("result") == "draw":
			return true
	return false


## Relative paths resolve against the project directory (res://), absolute ones stay.
static func _out_dir(path: String) -> String:
	if path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path("res://").path_join(path)


func _args() -> Dictionary:
	var out := {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var kv := arg.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	return out
