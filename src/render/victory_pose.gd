class_name VictoryPose
extends RefCounted
## The winners' victory cheer (VictoryCeremony, GD-CAM-02): the Cheer clip forced on their
## animators and a turn toward the camera, held until the next match. Render only.

const TURN_RATE := 8.0
## Yaw 0 faces +Z, the side the match camera looks from.
const CAMERA_YAW := 0.0

## slot -> the yaw it is turning through.
var _yaw: Dictionary = {}


## slots cheer from now on; [] puts every animator back on its sim view.
func start(views: Array[FighterView], slots: Array[int]) -> void:
	_yaw.clear()
	for i: int in views.size():
		if slots.has(i):
			_yaw[i] = views[i].rotation.y
		if views[i].animator() != null:
			views[i].animator().force(AnimMap.Anim.CHEER if slots.has(i) else -1)


## After the views took their sim facing this frame: the cheering ones turn to the camera.
func apply(views: Array[FighterView], delta: float) -> void:
	var k := 1.0 - exp(-TURN_RATE * delta)
	for i: int in _yaw:
		if i < views.size():
			_yaw[i] = lerp_angle(float(_yaw[i]), CAMERA_YAW, k)
			views[i].rotation.y = _yaw[i]


func slots() -> Array:
	return _yaw.keys()
