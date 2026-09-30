extends SceneTree
## Phase 4 T8 evidence: the procedural item models. Shot 1 is the ItemLineup (falling crate over
## its shadow, fresh / cracked bat, unlit / lit bomb, resting / tumbling rock); shot 2 is a
## close-up of three fighters idling with a bat, a bomb and a rock in hand.
##
## Usage (windowed, NOT headless; keep the window on top on macOS):
##   godot --path . --resolution 1280x720 --always-on-top -s res://scripts/capture_items.gd -- \
##       --out-dir=/abs/dir [--tag=SUFFIX]
## Writes <out-dir>/items-lineup<tag>.png and <out-dir>/items-held<tag>.png.

const SETTLE_FRAMES := 20
const HELD_FRAMES := 45
const HELD_KINDS: Array[int] = [Item.Kind.BAT, Item.Kind.BOMB, Item.Kind.ROCK]
const HELD_SPACING := 1.6

var _out: String = ""
var _tag: String = ""
var _frame: int = 0
var _stage: Node3D
var _views: Array[FighterView] = []
var _config := GameConfig.new()


func _init() -> void:
	var args := CaptureArgs.parse(OS.get_cmdline_user_args())
	_out = String(args.get("out-dir", ""))
	_tag = String(args.get("tag", ""))
	if _out.is_empty():
		push_error("capture_items: usage: -- --out-dir=/abs/dir [--tag=SUFFIX]")
		quit(1)
		return
	_lineup()
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	for v: FighterView in _views:
		v.animate(_idle(v), 1.0 / 60.0)
	if _frame == SETTLE_FRAMES:
		CaptureArgs.save(root, "%s/items-lineup%s.png" % [_out, _tag])
		_held()
	elif _frame == SETTLE_FRAMES + HELD_FRAMES:
		CaptureArgs.save(root, "%s/items-held%s.png" % [_out, _tag])
		quit(0)


func _lineup() -> void:
	_stage = CaptureArgs.grass_stage(root)
	var lineup := ItemLineup.new()
	_stage.add_child(lineup)
	lineup.setup(_config)
	CaptureArgs.camera(_stage, Vector3(0, 2.6, 7.4), Vector3(0, 0.55, 0), 42.0)


func _held() -> void:
	_stage.queue_free()
	_stage = CaptureArgs.grass_stage(root)
	for i: int in HELD_KINDS.size():
		var v := FighterView.new()
		_stage.add_child(v)
		v.setup(i, _config)
		v.set_identity_visible(false)
		var d := _idle_view(i, HELD_KINDS[i])
		v.apply(d, d, 1.0, 0)
		_views.append(v)
	CaptureArgs.camera(_stage, Vector3(0.6, 1.9, 4.2), Vector3(0, 0.9, 0), 40.0)


func _idle_view(i: int, kind: int) -> Dictionary:
	return {"id": i, "spawn_id": 0, "pos": Vector3((i - 1) * HELD_SPACING, 0, 0), "facing": Vector3(0.5, 0, 1).normalized(),
		"state": Fighter.State.IDLE, "on_ground": true, "invuln_ticks": 0, "item_kind": kind,
		"item_uses": 2, "attack_kind": -1, "charge_ticks": 0, "hitstop_ticks": 0}


func _idle(v: FighterView) -> Dictionary:
	var i := _views.find(v)
	return _idle_view(i, HELD_KINDS[i])
