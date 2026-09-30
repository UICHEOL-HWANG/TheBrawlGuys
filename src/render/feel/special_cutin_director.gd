class_name SpecialCutInDirector
extends Node
## Plays the special cut-in (Phase 5 T4, GD-CAM-01): SpecialCutIn timing -> the camera's close shot
## on the caster and the SpecialCutInBanner. The caster's own motion comes from its SPECIAL
## animation (AnimMap). Fed the sim view and this frame's events; never writes to the sim.
## Reduce motion ([accessibility] reduce_motion in SettingsStore) keeps the camera on the
## match framing and only fades the banner.

const SETTINGS_SECTION := "accessibility"
const SETTINGS_KEY := "reduce_motion"

var _camera: CameraRig
var _cut: SpecialCutIn
var _banner: SpecialCutInBanner


func setup(camera: CameraRig, reduce_motion: bool) -> void:
	_camera = camera
	_cut = SpecialCutIn.new(reduce_motion)
	_banner = SpecialCutInBanner.new()
	add_child(_banner)


## The player's reduce-motion setting (false when unset).
static func reduce_motion_setting(store: SettingsStore) -> bool:
	return store.get_bool(SETTINGS_SECTION, SETTINGS_KEY, false)


func reset() -> void:
	_cut.reset()
	_apply({})


func present(view: Dictionary, events: Array, delta: float) -> void:
	_cut.on_events(events)
	_cut.update(delta)
	var caster := _caster(view)
	if _cut.is_active() and (caster.is_empty() or int(caster["state"]) == Fighter.State.KO):
		_cut.cancel()
	_apply(caster)


func cut_in() -> SpecialCutIn:
	return _cut


## caster: its fighter view, or {} to keep the last focus point while the shot eases out.
func _apply(caster: Dictionary) -> void:
	var at: Vector3 = _camera.focus_point() if caster.is_empty() else caster["pos"]
	_camera.set_focus(at, _cut.camera_weight())
	_banner.show_cut(_cut.slot(), _cut.special(), _cut.weight(), _cut.is_reduced())


func _caster(view: Dictionary) -> Dictionary:
	for f: Dictionary in view.get("fighters", []):
		if int(f["id"]) == _cut.slot():
			return f
	return {}
