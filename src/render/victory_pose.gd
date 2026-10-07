class_name VictoryPose
extends RefCounted
## The winners' victory cheer (VictoryCeremony, GD-CAM-02): each character's own celebration
## (polish-pass 6: the knight and the mage raise sword / staff to the sky, the rogue hops, the
## barbarian pumps a fist) forced on their animators and a turn toward the camera, held until
## the next match. Render only.

const TURN_RATE := 8.0
## Model character id -> victory clip (keyed by the drawn glb, so the clip always fits the rig;
## the classic fighter celebrates like the model its slot draws). Unknown ids cheer.
const CLIPS := {"knight": "Spellcast_Raise", "mage": "Spellcast_Raise", "rogue": "Jump_Full_Short", "barbarian": "Cheer"}
const DEFAULT_CLIP := "Cheer"
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
		var animator := views[i].animator()
		if animator == null:
			continue
		if slots.has(i):
			animator.set_clip(AnimMap.Anim.CHEER, clip_for(views[i].model().character_id()))
		else:
			animator.reset_clip(AnimMap.Anim.CHEER)
		animator.force(AnimMap.Anim.CHEER if slots.has(i) else -1)


static func clip_for(character: String) -> String:
	return String(CLIPS.get(character, DEFAULT_CLIP))


## After the views took their sim facing this frame: the cheering ones turn to the camera.
func apply(views: Array[FighterView], delta: float) -> void:
	var k := 1.0 - exp(-TURN_RATE * delta)
	for i: int in _yaw:
		if i < views.size():
			_yaw[i] = lerp_angle(float(_yaw[i]), CAMERA_YAW, k)
			views[i].rotation.y = _yaw[i]


func slots() -> Array:
	return _yaw.keys()
