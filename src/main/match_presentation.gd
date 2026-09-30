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
	_cutin.setup(_camera, SpecialCutInDirector.reduce_motion_setting(SettingsStore.new()))
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
	_cutin.reset()
	_music.play_battle()


func play_ui(sound: String) -> void:
	_sfx.play_ui(sound)


func present(view: Dictionary, events: Array, view_events: Array, delta: float, local_slot: int,
		touch: TouchInput) -> void:
	_music.update_from(view)
	_follow_arena(String(view.get("arena", ArenaCatalog.DEFAULT_ID)))
	_feel.on_events(events)
	_feel.on_view_events(view_events)
	_sfx.on_events(events)
	_sfx.on_events(view_events)
	LocalHints.update(view, local_slot, _config, touch, _grab_hint)
	_cutin.present(view, events, delta)
	_camera.follow(CameraFraming.match_targets(view, _config), delta)
	_gauges.update_from(view, _config, _camera.unproject)


## Ring-out splashes follow the arena being played (only real water splashes).
func _follow_arena(arena_id: String) -> void:
	if arena_id == _arena_id:
		return
	_arena_id = arena_id
	_feel.set_arena(arena_id)
	_sfx.set_arena(arena_id)
