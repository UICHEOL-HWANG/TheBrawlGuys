class_name MatchExport
extends RefCounted
## One match as a self-contained JSON document (platform A7) for the offline replay verifier:
## {"format": FORMAT, "version": VERSION, "match": matches row, "players": match_players rows,
## "inputs": match_inputs rows}. The same shape can be assembled from Supabase with SQL.

const FORMAT := "tbg-replay"
const VERSION := 1


static func build(telemetry: MatchTelemetry) -> Dictionary:
	return {
		"format": FORMAT, "version": VERSION, "match": telemetry.match_row(),
		"players": telemetry.player_rows(), "inputs": telemetry.input_rows(),
	}


static func save(export: Dictionary, path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("MatchExport: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(JsonSafe.to_json_value(export)))
	f.close()
	return OK


## {} when the file is missing or is not a JSON object.
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JsonSafe.parse(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
