extends GutTest
## Online match telemetry (event schema 9, NetSummary, migration 0007): the net summary reaches
## match_ended and the Supabase rows, offline matches keep their shape, and the match id can be
## shared by every peer.

const MIGRATION := "res://supabase/migrations/0007_online_stats.sql"
const SQL_TYPES := "uuid|text|bigint|integer|smallint|real|boolean|jsonb|timestamptz"

var _sent: Array = []


func _net() -> Dictionary:
	var stats := NetStats.new(true)
	stats.add_rtt(80.0)
	stats.add_rtt(120.0)
	stats.add_disconnect(HostSession.REASON_LEFT, 1)
	return stats.props()


func _ended(net: Dictionary, mode: String = MatchSetup.MODE_ONLINE) -> MatchTelemetry:
	_sent.clear()
	var config := load("res://src/config/default_config.tres") as GameConfig
	var setup := MatchSetup.vs_bots(2, 4)
	setup.mode = mode
	var t := MatchTelemetry.new(func(n: String, p: Dictionary) -> void: _sent.append([n, p]))
	t.begin(TelemetrySetup.from_match_setup(setup, config, {"match_id": "shared-id"}))
	t.end(setup.build_world(config).state_view(), false, 0, net)
	return t


func _event(event_name: String) -> Dictionary:
	for e: Array in _sent:
		if e[0] == event_name:
			return e[1]
	return {}


func test_match_ended_carries_the_net_summary() -> void:
	_ended(_net())
	var props := _event("match_ended")
	for key: String in NetSummary.KEYS:
		assert_true(props.has(key), "match_ended.%s" % key)
	assert_eq(props["net_host"], true)
	assert_eq(props["disconnects"], 1)
	assert_eq(props["disconnect_reason"], "left")
	assert_eq(props["match_id"], "shared-id", "the shared match id is used")
	assert_eq((props["players"] as Array)[1]["disconnect_reason"], "left")
	assert_eq(EventCatalog.validate("match_ended", props), PackedStringArray())


func test_rows_carry_the_net_summary_in_declared_columns() -> void:
	var t := _ended(_net())
	var sql := FileAccess.get_file_as_string(MIGRATION)
	for key: String in NetSummary.KEYS:
		assert_true(t.match_row().has(key))
		assert_true(_declared(sql, key), "matches.%s is in 0007" % key)
	assert_eq(t.player_rows()[1]["disconnect_reason"], "left")
	assert_null(t.player_rows()[0]["disconnect_reason"])
	assert_true(_declared(sql, "disconnect_reason"))


func test_offline_matches_keep_their_shape() -> void:
	var t := _ended({}, MatchSetup.MODE_BOT)
	for key: String in NetSummary.KEYS:
		assert_false(t.match_row().has(key), "no %s offline (uploads work before 0007)" % key)
		assert_false(_event("match_ended").has(key))
	assert_false(t.player_rows()[0].has("disconnect_reason"))


func test_online_match_ended_without_net_keys_fails_validation() -> void:
	_ended({})
	var errors := EventCatalog.validate("match_ended", _event("match_ended"))
	assert_gt(errors.size(), 0, "schema 9: online matches must carry the net summary")


static func _declared(sql: String, column: String) -> bool:
	var re := RegEx.create_from_string("(?m)^\\s+(add column if not exists\\s+)?%s\\s+(%s)\\b" % [column, SQL_TYPES])
	return re.search(sql) != null
