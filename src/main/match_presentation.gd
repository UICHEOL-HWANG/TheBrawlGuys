class_name MatchPresentation
extends Node
## Everything a match scene shows and plays around the drawn world (platform B1 extraction from
## main.gd): the framing camera, game feel, the special cut-in, SFX and BGM, the local grab hint
## and charge gauges.
## Fed the sim view and this frame's events; never writes to the sim.

var _config: GameConfig
var _camera: CameraRig
var _feel: FeelDirector
var _cutin: SpecialCutInDirector
var _sfx: SfxDirector
var _music: MusicDirector
var _grab_hint: GrabHint
var _gauges: ChargeGaugeLayer
var _arena_id: String = ""
## Finishing replay close shot (MatchFinale, GD-CAM-02); weight 0 leaves the cut-in's focus.
var _finisher_at: Vector3 = Vector3.ZERO
var _finisher_weight: float = 0.0


func setup(config: GameConfig) -> void:
	_config = config
	_camera = CameraRig.new()
	add_child(_camera)
	_camera.setup(config)
	_feel = FeelDirector.new()
	add_child(_feel)
	_feel.setup(config, _camera)
	_cutin = SpecialCutInDirector.new()
	add_child(_cutin)
	_cutin.setup(_camera, false, config)
	_sfx = SfxDirector.new()
	add_child(_sfx)
	_sfx.setup(config)
	_music = MusicDirector.new()
	add_child(_music)
	_music.setup(config)
	_grab_hint = GrabHint.new()
	add_child(_grab_hint)
	_grab_hint.setup(config)
	_gauges = ChargeGaugeLayer.new()
	add_child(_gauges)


## A new match: calm feel, battle BGM from the top.
func restart() -> void:
	_feel.reset()
	_cutin.reset(SpecialCutInDirector.reduce_motion_setting(SettingsStore.new()))
	_music.play_battle()


## Shares of the screen height the HUD strip covers {top, bottom} (Hud.reserve): the camera
## frames the fight in between.
func set_hud_reserve(reserve: Dictionary) -> void:
	_camera.set_hud_reserve(float(reserve["top"]), float(reserve["bottom"]))


func camera_rig() -> CameraRig:
	return _camera


## The finishing replay's close shot: the knocked-out fighter's feet and its weight (0..1).
func set_finisher_focus(at: Vector3, weight: float) -> void:
	_finisher_at = at
	_finisher_weight = weight


func play_ui(sound: String) -> void:
	_sfx.play_ui(sound)


func present(view: Dictionary, events: Array, view_events: Array, delta: float, local_slot: int,
		touch: TouchInput) -> void:
	_music.update_from(view)
	_follow_arena(String(view.get("arena", ArenaCatalog.DEFAULT_ID)))
	_feel.on_events(events, view.get("fighters", []))
	_feel.on_view_events(view_events)
	_sfx.on_events(events)
	_sfx.on_events(view_events)
	LocalHints.update(view, local_slot, _config, touch, _grab_hint)
	_cutin.present(view, events, delta)
	if _finisher_weight > 0.0:
		_camera.set_focus(_finisher_at, _finisher_weight)
	_camera.follow(CameraFraming.match_targets(view, _config), delta)
	_gauges.update_from(view, _config, _camera.unproject, _camera.sees)


## Ring-out splashes follow the arena being played (only real water splashes).
func _follow_arena(arena_id: String) -> void:
	if arena_id == _arena_id:
		return
	_arena_id = arena_id
	_feel.set_arena(arena_id)
	_sfx.set_arena(arena_id)
