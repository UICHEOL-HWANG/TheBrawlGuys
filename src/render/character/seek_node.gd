class_name SeekNode
extends RefCounted
## A state-machine node whose clip position is set from outside every frame (combat-motion A2):
## Animation -> TimeSeek -> TimeScale(0). The scale of 0 keeps the clip from running on its own,
## so the play position is exactly the last seek (SwingTiming / SwingClips decide it).

const CLIP := "clip"
const SEEK := "seek"
const SCALE := "scale"


static func build(clip: String) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var anim := AnimationNodeAnimation.new()
	anim.animation = StringName(clip)
	anim.loop_mode = Animation.LOOP_NONE
	tree.add_node(CLIP, anim)
	var seek := AnimationNodeTimeSeek.new()
	seek.explicit_elapse = false
	tree.add_node(SEEK, seek)
	tree.add_node(SCALE, AnimationNodeTimeScale.new())
	tree.connect_node(SEEK, 0, CLIP)
	tree.connect_node(SCALE, 0, SEEK)
	tree.connect_node("output", 0, SCALE)
	return tree


static func set_clip(node: AnimationNodeBlendTree, clip: String) -> void:
	(node.get_node(CLIP) as AnimationNodeAnimation).animation = StringName(clip)


static func clip_of(node: AnimationNodeBlendTree) -> String:
	return String((node.get_node(CLIP) as AnimationNodeAnimation).animation)


## Stops the node's own clock (state: the node's name in the machine).
static func freeze(tree: AnimationTree, state: String) -> void:
	tree.set("parameters/%s/%s/scale" % [state, SCALE], 0.0)


static func seek(tree: AnimationTree, state: String, time: float) -> void:
	tree.set("parameters/%s/%s/seek_request" % [state, SEEK], time)
