extends SceneTree
## Offline replay verifier (platform A7): re-runs a match export (MatchExport JSON: matches row +
## match_inputs rows) in a headless World with the project's sim config and prints OK / MISMATCH /
## ERROR against the recorded final_state_hash. Exit code 0 only for OK.
## Run: godot --headless --path . -s res://scripts/replay_verify.gd -- path/to/match.json

const CONFIG_PATH := "res://src/config/default_config.tres"
const EXIT_OK := 0
const EXIT_FAIL := 1
const EXIT_USAGE := 2


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("usage: godot --headless --path . -s res://scripts/replay_verify.gd -- <match.json>")
		quit(EXIT_USAGE)
		return
	var config := load(CONFIG_PATH) as GameConfig
	if config == null:
		printerr("replay_verify: GameConfig missing at %s" % CONFIG_PATH)
		quit(EXIT_FAIL)
		return
	var result := ReplayVerifier.verify_file(args[0], config)
	print(ReplayVerifier.line(result))
	quit(EXIT_OK if result["ok"] else EXIT_FAIL)
