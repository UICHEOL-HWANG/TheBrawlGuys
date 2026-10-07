extends GutTest
## A9 synthetic dataset generator helpers (scripts/dataset): reproducible specs, CSV cells,
## timeline rows and one played match producing the Supabase row shapes.

const DatasetSpec := preload("res://scripts/dataset/dataset_spec.gd")
const DatasetMatch := preload("res://scripts/dataset/dataset_match.gd")
const TimelineSampler := preload("res://scripts/dataset/timeline_sampler.gd")
const CsvTable := preload("res://scripts/dataset/csv_table.gd")


func test_spec_is_reproducible_and_valid() -> void:
	var config := GameConfig.new()
	var a := DatasetSpec.make(42, config)
	var b := DatasetSpec.make(42, config)
	assert_eq(a["rule"], b["rule"])
	assert_eq(a["characters"], b["characters"])
	assert_eq(a["difficulties"], b["difficulties"])
	var setup := DatasetSpec.to_match_setup(a)
	assert_eq(setup.validate().size(), 0, "spec builds a valid MatchSetup")
	assert_eq(setup.local_slot(), -1, "bots only")


func test_csv_cells_quote_and_encode() -> void:
	assert_eq(CsvTable.cell(null), "")
	assert_eq(CsvTable.cell(true), "true")
	assert_eq(CsvTable.cell("a,b"), "\"a,b\"")
	assert_eq(CsvTable.cell({"k": "v"}), "\"{\"\"k\"\":\"\"v\"\"}\"")
	assert_eq(CsvTable.line({"b": 2, "a": 1}, ["a", "b", "c"] as Array[String]), "1,2,")


func test_buffered_table_writes_union_header() -> void:
	var path := "user://test_gen_dataset.csv"
	var t := CsvTable.new(path)
	t.add({"a": 1})
	t.add({"a": 2, "b": 3})
	t.close()
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	assert_eq(Array(lines), ["a,b", "1,", "2,3"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_timeline_rows_one_per_fighter() -> void:
	var w := World.new(GameConfig.new(), 1)
	var rows := TimelineSampler.rows("m", w.state_view())
	assert_eq(rows.size(), w.fighters.size())
	for key: String in TimelineSampler.COLUMNS:
		assert_true(rows[0].has(key), key)
	assert_gt(float(rows[0]["edge_dist"]), 0.0, "spawn is inside the arena")


func test_play_produces_supabase_row_shapes() -> void:
	var played := DatasetMatch.play(0, 1, load("res://src/config/default_config.tres") as GameConfig)
	var row: Dictionary = played["match"]
	assert_eq(row["id"], DatasetMatch.match_uuid(0))
	assert_eq(row["platform"], DatasetMatch.PLATFORM)
	assert_eq((played["players"] as Array).size(), int(row["player_count"]))
	assert_false((played["events"] as Array).is_empty())
	assert_false((played["timeline"] as Array).is_empty())
	var p: Dictionary = played["players"][0]
	for key: String in ["match_id", "slot", "character", "result", "bot_difficulty", "bot_params_hash"]:
		assert_true(p.has(key), key)
