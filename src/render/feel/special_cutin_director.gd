class_name SpecialCutInDirector
extends Node
## Plays the special cut-in (Phase 5 T4, GD-CAM-01): SpecialCutIn timing -> the camera's close shot
## on the caster and the SpecialCutInBanner. The caster's own motion comes from its SPECIAL
## animation (AnimMap). Fed the sim view and this frame's events; never writes to the sim.
## Reduce motion ([accessibility] reduce_motion in SettingsStore) keeps the camera on the
## match framing and only fades the banner; it is read again at every match start. The focus pans
## to a new caster (and follows a moving one) instead of snapping, except when the shot starts.

const SETTINGS_SECTION := "accessibility"
const SETTINGS_KEY := "reduce_motion"
## How fast the focus point closes on the caster (1/s, exponential).
const FOCUS_FOLLOW := 10.0

var _camera: CameraRig
var _cut: SpecialCutIn
var _banner: SpecialCutInBanner
var _last_weight: float = 0.0


## config: the sim tuning each special's hold is read from (null: the default hold).
func setup(camera: CameraRig, reduce_motion: bool, config: GameConfig = null) -> void:
	_camera = camera
	_cut = SpecialCutIn.new(reduce_motion, config)
	_banner = SpecialCutInBanner.new()
	add_child(_banner)


## The player's reduce-motion setting (false when unset).
static func reduce_motion_setting(store: SettingsStore) -> bool:
	return store.get_bool(SETTINGS_SECTION, SETTINGS_KEY, false)


## A new match: no cut-in, and the reduce-motion setting as it is now.
func reset(reduce_motion: bool = false) -> void:
	_cut.reset()
	_cut.set_reduce_motion(reduce_motion)
	_last_weight = 0.0
	_apply({}, 0.0)


func present(view: Dictionary, events: Array, delta: float) -> void:
	_cut.on_events(events)
	_cut.update(delta)
	var caster := _caster(view)
	if not caster.is_empty() and int(caster.get("state", Fighter.State.IDLE)) == Fighter.State.KO:
		caster = {}  # the camera does not follow a body falling out of the arena
	if _cut.is_active() and caster.is_empty():
		_cut.cancel()
	_apply(caster, delta)


func cut_in() -> SpecialCutIn:
	return _cut


## caster: its fighter view, or {} to keep the last focus point while the shot eases out.
func _apply(caster: Dictionary, delta: float) -> void:
	var at := _camera.focus_point()
	if caster.has("pos"):
		var k := 1.0 if _last_weight <= 0.0 else 1.0 - exp(-FOCUS_FOLLOW * delta)
		at = at.lerp(caster["pos"], k)
	_last_weight = _cut.camera_weight()
	_camera.set_focus(at, _last_weight)
	_banner.show_cut(_cut.slot(), _cut.special(), _cut.weight(), _cut.is_reduced())


func _caster(view: Dictionary) -> Dictionary:
	for f: Dictionary in view.get("fighters", []):
		if int(f.get("id", SpecialCutIn.NONE)) == _cut.slot():
			return f
	return {}
