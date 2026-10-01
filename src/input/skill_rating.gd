class_name SkillRating
extends RefCounted
## The device's player skill on the dial scale (PRD-BOT-05): user://skill.cfg [skill] rating (0..1)
## and matches (how many observations it holds), the MatchCounter / SettingsStore ConfigFile
## pattern. An empty path keeps it in memory only (headless and test runs never write user://).
## record() blends a new observation in: the first one is taken as is, later ones by `weight`.

const DEFAULT_PATH := "user://skill.cfg"
const SECTION := "skill"
const UNRATED := 0.5

var _path: String
var _cfg := ConfigFile.new()


func _init(path: String = "") -> void:
	_path = path
	if not _path.is_empty() and FileAccess.file_exists(_path):
		var err := _cfg.load(_path)
		if err != OK:
			push_warning("SkillRating: cannot read %s (%s); starting unrated" % [_path, error_string(err)])


## Live runs persist; headless and test runs keep it in memory.
static func create_default() -> SkillRating:
	return SkillRating.new(DEFAULT_PATH if PlatformEnv.is_live() else "")


func rating() -> float:
	return clampf(float(_cfg.get_value(SECTION, "rating", UNRATED)), 0.0, 1.0)


func matches() -> int:
	return int(_cfg.get_value(SECTION, "matches", 0))


func record(observation: float, weight: float) -> float:
	var obs := clampf(observation, 0.0, 1.0)
	var next := obs if matches() == 0 else lerpf(rating(), obs, clampf(weight, 0.0, 1.0))
	_cfg.set_value(SECTION, "rating", next)
	_cfg.set_value(SECTION, "matches", matches() + 1)
	if not _path.is_empty():
		var err := _cfg.save(_path)
		if err != OK:
			push_warning("SkillRating: cannot save %s (%s)" % [_path, error_string(err)])
	return next
