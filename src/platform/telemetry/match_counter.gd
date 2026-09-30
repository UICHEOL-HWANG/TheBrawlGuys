class_name MatchCounter
extends RefCounted
## user_match_seq (platform A7, analytics-strategy §3.1): the n-th match this install played for a
## user id (signed out = "anonymous"), kept in a ConfigFile [seq] section. An empty path counts in
## memory only (headless and test runs never write user://).

const DEFAULT_PATH := "user://match_seq.cfg"
const SECTION := "seq"
const ANONYMOUS := "anonymous"

var _path: String
var _cfg := ConfigFile.new()


func _init(path: String = "") -> void:
	_path = path
	if not _path.is_empty() and FileAccess.file_exists(_path):
		var err := _cfg.load(_path)
		if err != OK:
			push_warning("MatchCounter: cannot read %s (%s); counting from 1" % [_path, error_string(err)])


## Live runs persist; headless and test runs count in memory.
static func create_default() -> MatchCounter:
	return MatchCounter.new(DEFAULT_PATH if PlatformEnv.is_live() else "")


## Counts one more match for the user and returns its sequence number (1 = first match).
func next(user_id: String) -> int:
	var key := user_id if not user_id.is_empty() else ANONYMOUS
	var seq := int(_cfg.get_value(SECTION, key, 0)) + 1
	_cfg.set_value(SECTION, key, seq)
	if not _path.is_empty():
		var err := _cfg.save(_path)
		if err != OK:
			push_warning("MatchCounter: cannot save %s (%s)" % [_path, error_string(err)])
	return seq
