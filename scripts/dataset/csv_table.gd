extends RefCounted
## Minimal CSV writer for scripts/gen_dataset.gd (A9). Fixed-column tables stream rows to disk;
## buffered tables collect rows and write the union of their keys at close (match_players gains
## team / score only in some rules). null -> empty cell, containers -> JSON text, RFC 4180 quoting.

var _path: String
var _columns: Array[String] = []
var _buffered: bool
var _rows: Array[Dictionary] = []
var _file: FileAccess = null


## columns empty = buffered (header = union of row keys in first-seen order).
func _init(path: String, columns: Array[String] = []) -> void:
	_path = path
	_columns = columns
	_buffered = columns.is_empty()
	if not _buffered:
		_file = _open()
		if _file != null:
			_file.store_line(",".join(_columns))


func add(row: Dictionary) -> void:
	if _buffered:
		_rows.append(row)
	elif _file != null:
		_file.store_line(line(row, _columns))


func add_all(rows: Array) -> void:
	for r: Dictionary in rows:
		add(r)


func close() -> void:
	if _buffered:
		_file = _open()
		if _file == null:
			return
		_columns = union_columns(_rows)
		_file.store_line(",".join(_columns))
		for r: Dictionary in _rows:
			_file.store_line(line(r, _columns))
	if _file != null:
		_file.close()
		_file = null


static func union_columns(rows: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for r: Dictionary in rows:
		for k: Variant in r:
			if not out.has(String(k)):
				out.append(String(k))
	return out


static func line(row: Dictionary, columns: Array[String]) -> String:
	var cells := PackedStringArray()
	for c: String in columns:
		cells.append(cell(row.get(c)))
	return ",".join(cells)


static func cell(v: Variant) -> String:
	var text := ""
	match typeof(v):
		TYPE_NIL:
			return ""
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_DICTIONARY, TYPE_ARRAY:
			text = JSON.stringify(JsonSafe.to_json_value(v))
		_:
			text = str(JsonSafe.to_json_value(v))
	if text.contains(",") or text.contains("\"") or text.contains("\n"):
		return "\"%s\"" % text.replace("\"", "\"\"")
	return text


func _open() -> FileAccess:
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f == null:
		push_error("CsvTable: cannot write %s (%s)" % [_path, error_string(FileAccess.get_open_error())])
	return f
