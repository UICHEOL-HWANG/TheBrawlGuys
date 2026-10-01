extends GutTest
## Every column the client sends exists in the migrations (platform A7/A8): PostgREST rejects a
## bulk insert that names an unknown column, which would silently lose the whole match upload.

const BotMatchRun := preload("res://tests/unit/support/bot_match_run.gd")
const MIGRATIONS: Array[String] = [
	"res://supabase/migrations/0001_match_telemetry.sql",
	"res://supabase/migrations/0002_replay_and_features.sql",
	"res://supabase/migrations/0003_special_hits.sql",
	"res://supabase/migrations/0004_match_rules.sql",
	"res://supabase/migrations/0006_bot_tracking.sql",
]
const SQL_TYPES := "uuid|text|bigint|integer|smallint|real|boolean|jsonb|timestamptz"

var _sql: String = ""
var _telemetry: MatchTelemetry


func before_all() -> void:
	for path: String in MIGRATIONS:
		_sql += FileAccess.get_file_as_string(path) + "\n"
	_telemetry = BotMatchRun.play(ArenaCatalog.DEFAULT_ID, 2, 3, 600)["telemetry"]


func _declared(column: String) -> bool:
	var re := RegEx.create_from_string("(?m)^\\s+(add column if not exists\\s+)?%s\\s+(%s)\\b" % [column, SQL_TYPES])
	return re.search(_sql) != null


func _assert_columns(table: String, row: Dictionary) -> void:
	for key: String in row:
		if key == "user_id":
			continue  # matches.user_id defaults to auth.uid()
		assert_true(_declared(key), "%s.%s is declared in a migration" % [table, key])


func test_matches_row_columns_exist() -> void:
	_assert_columns("matches", _telemetry.match_row())


func test_match_players_row_columns_exist() -> void:
	_assert_columns("match_players", _telemetry.player_rows()[0])


func test_match_events_and_inputs_row_columns_exist() -> void:
	_assert_columns("match_events", _telemetry.event_rows()[0])
	_assert_columns("match_inputs", _telemetry.input_rows()[0])
