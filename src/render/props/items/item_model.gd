class_name ItemModel
extends Node3D
## Base of the procedural item models (design.md DS-VIS-05, Phase 4 T8): low-poly soft-toon
## parts in DS tokens with a glow rim, origin on the ground under the item. Subclasses build
## their parts in _build(), react to the item view in show_state() and say how the hand holds
## them in hold_transform(). Drawing only: they read view values and never touch the sim.

## Glow rim on every item part so items pop off the grass (DS-VIS-05).
const RIM := 0.45

var _parts: Array[MeshInstance3D] = []


func _init() -> void:
	_build()


## Updates the model from an item view ({state, uses, fuse_ticks, ...}) at a sim tick.
func show_state(_view: Dictionary, _tick: int) -> void:
	pass


## Where this model sits relative to a hand slot (grip at the origin).
func hold_transform() -> Transform3D:
	return Transform3D.IDENTITY


## How the model lies on the ground or flies (its pose when not held).
func ground_transform() -> Transform3D:
	return Transform3D.IDENTITY


func part_count() -> int:
	return _parts.size()


## Local bounds of the visible parts (this node's space, before its own transform).
func bounds() -> AABB:
	var out := AABB()
	var first := true
	for p: MeshInstance3D in _parts:
		if not p.visible:
			continue
		var box := _local_xform(p) * p.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _build() -> void:
	pass


## Adds a part with a toon material in `color` at `xform` (relative to `parent`, default self).
func _part(mesh: Mesh, color: Color, xform: Transform3D, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ToonMaterials.toon(color, RIM)
	mi.transform = xform
	(parent if parent != null else self).add_child(mi)
	_parts.append(mi)
	return mi


func _local_xform(node: Node3D) -> Transform3D:
	var xf := node.transform
	var p := node.get_parent() as Node3D
	while p != null and p != self:
		xf = p.transform * xf
		p = p.get_parent() as Node3D
	return xf
