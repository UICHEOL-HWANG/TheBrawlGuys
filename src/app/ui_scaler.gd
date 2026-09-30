extends Node
## UiScaler autoload (design.md DS-LAY-04): the thin applier of UiScale. On start and on every
## window resize / orientation change it reads the screen (DisplayProbe), sets the root
## Window.content_scale_factor (2D canvas only — the 3D view keeps filling the window), shows the
## RotateOverlay on a touch device held in portrait, and keeps the analytics globals
## viewport_class / orientation / ui_scale current (tracking-plan.md §2).

## Tests set this false before adding the node: then apply() only drives the overlay.
var live: bool = true

var _overlay: RotateOverlay
var _profile: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = RotateOverlay.new()
	add_child(_overlay)
	if live:
		get_tree().root.size_changed.connect(_refresh)
		_refresh()


## Applies a UiScale.profile(): scale factor, rotate prompt and analytics globals.
func apply(p: Dictionary) -> void:
	_profile = p
	_overlay.set_active(bool(p["rotate"]))
	if not live:
		return
	var root := get_tree().root
	var f := float(p["ui_scale"])
	if not is_equal_approx(root.content_scale_factor, f):
		root.content_scale_factor = f  # emits size_changed; the same profile comes back, no loop
	var props := UiScale.tracking(p)
	for key: String in props:
		Analytics.set_super_property(key, props[key])


func applied_factor() -> float:
	return float(_profile.get("ui_scale", 1.0))


func profile() -> Dictionary:
	return _profile


func overlay() -> RotateOverlay:
	return _overlay


func _refresh() -> void:
	var p := DisplayProbe.profile()
	if p != _profile:
		apply(p)
