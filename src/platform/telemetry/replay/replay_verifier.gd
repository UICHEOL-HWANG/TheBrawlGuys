class_name ReplayVerifier
extends RefCounted
## Offline replay check (platform A7, analytics-strategy §1): rebuilds the World from a MatchExport
## header (seed, arena, player count) with the given sim config, feeds the recorded inputs tick by
## tick and compares World.state_hash() with the recorded final_state_hash. Matches that fail are
## excluded from analysis. Result: {ok, reason, match_id, ticks, expected, actual}.

const REASON_OK := "ok"
const REASON_FORMAT := "format"
const REASON_INPUTS := "inputs"
const REASON_SIM_VERSION := "sim_version"
const REASON_CONFIG := "config_fingerprint"
const REASON_HASH := "final_state_hash"
const HEADER_KEYS: Array[String] = ["seed", "arena", "player_count", "sim_version", "config_fingerprint",
	"final_state_hash"]


static func verify_file(path: String, config: GameConfig) -> Dictionary:
	return verify(MatchExport.load_file(path), config)


static func verify(export: Dictionary, config: GameConfig) -> Dictionary:
	var header: Dictionary = export.get("match", {}) if export.get("match") is Dictionary else {}
	var result := {"ok": false, "reason": REASON_FORMAT, "match_id": String(header.get("id", "")),
		"ticks": 0, "expected": 0, "actual": 0}
	if export.get("format") != MatchExport.FORMAT or not _has_header(header):
		return result
	var log := InputLog.from_rows(export.get("inputs", []) if export.get("inputs") is Array else [])
	if log == null or log.slot_count() != int(header["player_count"]) or log.frame_count() == 0 \
			or (header.get("duration_ticks") != null and int(header["duration_ticks"]) != log.frame_count()):
		result["reason"] = REASON_INPUTS
	elif int(header["sim_version"]) != World.SNAPSHOT_VERSION:
		result["reason"] = REASON_SIM_VERSION
	elif int(header["config_fingerprint"]) != config.fingerprint():
		result["reason"] = REASON_CONFIG
	else:
		_replay(header, log, config, result)
	return result


## One printable line: "OK ...", "MISMATCH ..." (hash differs) or "ERROR <reason> ...".
static func line(result: Dictionary) -> String:
	var tag := "OK" if result["ok"] else ("MISMATCH" if result["reason"] == REASON_HASH else "ERROR")
	return "%s %s match=%s ticks=%d expected=%d actual=%d" % [tag, result["reason"], result["match_id"],
		result["ticks"], result["expected"], result["actual"]]


static func _replay(header: Dictionary, log: InputLog, config: GameConfig, result: Dictionary) -> void:
	var setup := MatchSetup.new()
	setup.arena_id = String(header["arena"])
	var world := World.new(config, int(header["seed"]), log.slot_count(), setup.build_arena(config))
	for t: int in log.frame_count():
		world.tick(log.inputs_at(t))
	result["ticks"] = world.tick_count
	result["expected"] = int(header["final_state_hash"])
	result["actual"] = world.state_hash()
	result["ok"] = result["expected"] == result["actual"]
	result["reason"] = REASON_OK if result["ok"] else REASON_HASH


static func _has_header(header: Dictionary) -> bool:
	for key: String in HEADER_KEYS:
		if header.get(key) == null:
			return false
	return true
