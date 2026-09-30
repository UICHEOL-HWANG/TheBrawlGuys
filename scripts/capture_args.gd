class_name CaptureArgs
extends RefCounted
## Shared helpers for the Phase 4 evidence capture scripts (capture_items, capture_arenas,
## capture_arena_select): user-arg parsing, a sunny grass stage, a fixed camera and PNG saving.


## `--key=value` user args (after `--`) as a dictionary.
static func parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for a: String in args:
		if a.begins_with("--") and a.contains("="):
			out[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	return out


static func save(root: Window, path: String) -> void:
	var err := root.get_texture().get_image().save_png(path)
	if err != OK:
		push_error("capture: cannot save %s (%s)" % [path, error_string(err)])
		return
	print("capture: saved %s" % path)


## Sun, sky and a flat grass floor under root (a neutral backdrop for close-ups).
static func grass_stage(root: Node) -> Node3D:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := EnvironmentRig.new()
	stage.add_child(env)
	env.setup()
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.material_override = ToonMaterials.toon(DS.GRASS)
	stage.add_child(ground)
	return stage


static func camera(parent: Node3D, from: Vector3, to: Vector3, fov: float) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = fov
	parent.add_child(cam)
	cam.look_at_from_position(from, to, Vector3.UP)
	cam.make_current()
	return cam
