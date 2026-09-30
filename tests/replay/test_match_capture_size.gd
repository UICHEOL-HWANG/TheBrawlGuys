extends GutTest
## Upload size of one match (platform A7/A8, analytics-strategy §4) from a 4-bot, 3-minute headless
## match (the stock cap raised so it lasts), and proof that the recorded inputs replay it exactly.
## Prints the byte counts per table (JSON as sent to PostgREST); the bounds only catch regressions.

const BotMatchRun := preload("res://tests/unit/support/bot_match_run.gd")
const PLAYERS := 4
const TICKS := 3 * 60 * SimTime.TICK_RATE
const SEED := 13
const MAX_INPUT_BYTES := 28 * 1024
const MAX_TOTAL_BYTES := 512 * 1024
## Enough stocks that four bots are still fighting at three minutes.
const STOCKS := 12

var _run: Dictionary = {}
var _config := GameConfig.new()


func before_all() -> void:
	_config.stocks = STOCKS
	_run = BotMatchRun.play(ArenaCatalog.DEFAULT_ID, PLAYERS, SEED, TICKS, _config)


static func _json_bytes(rows: Variant) -> int:
	return JSON.stringify(rows).to_utf8_buffer().size()


func test_bytes_per_match() -> void:
	var t: MatchTelemetry = _run["telemetry"]
	var events := t.event_rows()
	var pos := events.filter(func(r: Dictionary) -> bool: return r["type"] == "pos")
	var sizes := {
		"matches": _json_bytes([t.match_row()]), "match_players": _json_bytes(t.player_rows()),
		"match_events": _json_bytes(events), "match_events_pos_only": _json_bytes(pos),
		"match_inputs": _json_bytes(t.input_rows()),
	}
	var total := int(sizes["matches"]) + int(sizes["match_players"]) + int(sizes["match_events"]) \
			+ int(sizes["match_inputs"])
	gut.p("bytes per match (%d bots, %d ticks, %d event rows of which %d pos): %s total=%d" % [
		PLAYERS, (_run["world"] as World).tick_count, events.size(), pos.size(), sizes, total])
	assert_lt(int(sizes["match_inputs"]), MAX_INPUT_BYTES, "run-length + gzip keeps the replay log small")
	assert_lt(total, MAX_TOTAL_BYTES)


func test_the_recorded_match_replays_exactly() -> void:
	var export := MatchExport.build(_run["telemetry"])
	assert_eq((_run["world"] as World).tick_count, TICKS, "a full three-minute match")
	var result := ReplayVerifier.verify(export, _config)
	assert_true(result["ok"], ReplayVerifier.line(result))
