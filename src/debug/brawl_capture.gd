extends "res://src/debug/perf_match.gd"
## polish-pass 2 evidence: a real four-bot match (full Main: HUD, feel, cut-ins, sound) with
## Knight, Mage, Barbarian and Rogue, photographed by the match camera once a second and laid
## out as contact sheets, so swings, grabs, specials and magic can be checked in actual play
## without signing in. Run as the main scene (autoloads load; `-s` scripts cannot open Main):
##   godot --path . --resolution 1280x720 --always-on-top res://src/debug/brawl_capture.tscn -- \
##       --out-dir=/abs/dir [--seconds=24] [--seed=11]
## Writes <out-dir>/brawl-<n>.png (4x3 thumbnails each) and quits; without --out-dir it only plays.

const WARMUP_FRAMES := 90
const SHOT_EVERY := 60
const THUMB := Vector2i(480, 270)
const GRID := Vector2i(4, 3)
const CHARACTERS := {0: "knight", 1: "mage", 2: "barbarian", 3: "rogue"}

var _out: String = ""
var _shots_wanted: int = 24
var _frame: int = 0
var _thumbs: Array[Image] = []
var _sheet: int = 0


func _ready() -> void:
	var args := CaptureArgs.parse(OS.get_cmdline_user_args())
	_out = String(args.get("out-dir", ""))
	_shots_wanted = int(args.get("seconds", "24"))
	setup = MatchSetup.vs_bots(PERF_PLAYERS, int(args.get("seed", "11")))
	setup.set_characters(CHARACTERS)
	super._ready()
	if _out.is_empty():
		return  # no capture asked for: just a four-character bot match (opened by tests too)
	get_tree().process_frame.connect(_shoot)


func _shoot() -> void:
	_frame += 1
	if _frame < WARMUP_FRAMES or (_frame - WARMUP_FRAMES) % SHOT_EVERY != 0:
		return
	var img := get_viewport().get_texture().get_image()
	img.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
	_thumbs.append(img)
	if _thumbs.size() == GRID.x * GRID.y:
		_flush()
	if _sheet * GRID.x * GRID.y + _thumbs.size() >= _shots_wanted:
		_flush()
		get_tree().quit(0)


func _flush() -> void:
	if _thumbs.is_empty():
		return
	var sheet := Image.create(THUMB.x * GRID.x, THUMB.y * GRID.y, false, _thumbs[0].get_format())
	for i: int in _thumbs.size():
		sheet.blit_rect(_thumbs[i], Rect2i(Vector2i.ZERO, THUMB), Vector2i(i % GRID.x * THUMB.x, i / GRID.x * THUMB.y))
	_sheet += 1
	var path := "%s/brawl-%d.png" % [_out, _sheet]
	sheet.save_png(path)
	print("capture: saved %s" % path)
	_thumbs.clear()
