class_name MenuBackdrop
extends Node3D
## Orbit diorama behind every menu screen (platform B2, design.md DS-LAY-03): the match's
## MatchStage (sun, arena, decor, fighters, items) drawn from a BackdropMatch of four bots, a low
## 3/4 OrbitCamera and the menu BGM, softened by sage-gray depth fog and the MenuHaze overlay so
## it reads as a calm background (the haze fog is held over each arena theme). Every restart moves
## to the next arena (BackdropMatch.ARENA_CYCLE). No HUD, no player rings or labels, no hit SFX,
## no telemetry.
## Leaving the tree (entering a match) pauses it; re-entering resumes it.

const CONFIG_PATH := "res://src/config/default_config.tres"
const SEED := 11

var _config: GameConfig
var _stage: MatchStage
var _match: BackdropMatch
var _camera: OrbitCamera
var _music: MusicDirector
var _haze: MenuHaze
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
	_stage.set_identity_visible(false)
	_stage.environment_rig().hold_fog(DS.HAZE, _config.menu_fog_density)
	_match = BackdropMatch.new(_config, SEED)
	_camera = OrbitCamera.new()
	add_child(_camera)
	_camera.setup(_config)
	_music = MusicDirector.new()
	add_child(_music)
	_music.setup(_config)
	_haze = MenuHaze.new()
	add_child(_haze)
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
	_stage.set_arena(_match.arena_id())  # no-op until a restart moves to the next arena
	_stage.draw(_match.prev_state, _match.curr_state, _match.alpha(), delta)
	_stage.on_events(events)
	_camera.follow(_match.fight_center(_config.arena_radius * _config.menu_orbit_arena_share))
	_camera.advance(delta)


## The diorama fades in out of full haze (first screen).
func reveal() -> Tween:
	return _haze.reveal()


func world() -> World:
	return _match.world


func camera() -> OrbitCamera:
	return _camera


func stage() -> MatchStage:
	return _stage


func haze() -> MenuHaze:
	return _haze


## Keeps the fight in the screen area the current menu leaves free (NDC, x right / y up).
func set_focus(ndc: Vector2, instant: bool = false) -> void:
	_camera.set_focus(ndc, instant)


func is_playing_menu_music() -> bool:
	return _menu_music


func _resume() -> void:
	if not is_inside_tree():
		return
	_camera.make_current()
	_music.play_menu()
	_menu_music = true
