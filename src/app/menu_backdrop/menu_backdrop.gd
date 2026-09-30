class_name MenuBackdrop
extends Node3D
## Orbit diorama behind every menu screen (platform B2, design.md DS-LAY-03): the match's
## MatchStage (sun, arena, decor, fighters, items) drawn from a BackdropMatch of four bots, an
## OrbitCamera and the menu BGM. A light cream veil sinks it one step below the UI. No HUD, no
## hit SFX, no telemetry. Leaving the tree (entering a match) pauses it; re-entering resumes it.

const CONFIG_PATH := "res://src/config/default_config.tres"
const SEED := 11
## Veil sits above the 3D view and below the app UI layer.
const VEIL_LAYER := 1

var _config: GameConfig
var _stage: MatchStage
var _match: BackdropMatch
var _camera: OrbitCamera
var _music: MusicDirector
var _menu_music: bool = false


func _ready() -> void:
	_config = load(CONFIG_PATH) as GameConfig
	if _config == null:
		push_error("MenuBackdrop: GameConfig missing at %s" % CONFIG_PATH)
		set_process(false)
		return
	LookPreset.apply(_config.look_preset)
	_stage = MatchStage.new()
	add_child(_stage)
	_stage.setup(_config, SEED, BackdropMatch.PLAYERS)
	_match = BackdropMatch.new(_config, SEED)
	_camera = OrbitCamera.new()
	add_child(_camera)
	_camera.setup(_config)
	_music = MusicDirector.new()
	add_child(_music)
	_music.setup(_config)
	_add_veil()
	_resume()


func _enter_tree() -> void:
	if is_node_ready():
		_resume.call_deferred()  # children enter the tree after this callback


func _exit_tree() -> void:
	if _music != null:
		_music.stop()
	_menu_music = false


func _process(delta: float) -> void:
	var events := _match.advance(delta)
	_stage.draw(_match.prev_state, _match.curr_state, _match.alpha(), delta)
	_stage.wobble_guards(events)
	_camera.advance(delta)


func world() -> World:
	return _match.world


func camera() -> OrbitCamera:
	return _camera


func is_playing_menu_music() -> bool:
	return _menu_music


func _resume() -> void:
	if not is_inside_tree():
		return
	_camera.make_current()
	_music.play_menu()
	_menu_music = true


func _add_veil() -> void:
	var layer := CanvasLayer.new()
	layer.layer = VEIL_LAYER
	add_child(layer)
	var veil := ColorRect.new()
	veil.color = DS.BACKDROP_VEIL
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(veil)
