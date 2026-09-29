class_name ItemView
extends Node3D
## One loose item (design.md DS-VIS-05): a cream box while falling, with a soft round shadow on
## the ground below that grows as it drops (the race starts here), then the item's own shape in
## a point color with a glow rim. A lit bomb blinks its fuse. Reads item view values only.

const RIM := 0.45
const BOX_SIZE := 0.7
const BAT_RADIUS := 0.1
const BAT_LENGTH := 0.9
const BOMB_RADIUS := 0.3
const ROCK_RADIUS := 0.24
const FUSE_RADIUS := 0.09
const SHADOW_RADIUS := 0.6
const SHADOW_HEIGHT := 0.01
const SHADOW_LIFT := 0.02
const SHADOW_MIN_SCALE := 0.4
const FUSE_BLINK_HZ := 4.0

var _config: GameConfig
var _box: MeshInstance3D
var _shape: MeshInstance3D
var _fuse: MeshInstance3D
var _shadow: MeshInstance3D


static func kind_color(kind: int) -> Color:
	match kind:
		Item.Kind.BOMB:
			return DS.BERRY
		Item.Kind.ROCK:
			return DS.PETAL_BLUE
	return DS.PETAL_PINK


static func shape_mesh(kind: int) -> Mesh:
	match kind:
		Item.Kind.BAT:
			var bat := CapsuleMesh.new()
			bat.radius = BAT_RADIUS
			bat.height = BAT_LENGTH
			return bat
		Item.Kind.BOMB:
			var bomb := SphereMesh.new()
			bomb.radius = BOMB_RADIUS
			bomb.height = BOMB_RADIUS * 2.0
			return bomb
	var rock := SphereMesh.new()
	rock.radius = ROCK_RADIUS
	rock.height = ROCK_RADIUS * 1.6
	return rock


static func shadow_scale(height: float, drop_height: float) -> float:
	var t := 1.0 - clampf(height / maxf(drop_height, 0.01), 0.0, 1.0)
	return lerpf(SHADOW_MIN_SCALE, 1.0, t)


static func fuse_visible(fuse_ticks: int, tick: int) -> bool:
	if fuse_ticks <= 0:
		return false
	return floori(float(tick) * FUSE_BLINK_HZ * 2.0 / SimTime.TICK_RATE) % 2 == 0


func setup(kind: int, config: GameConfig) -> void:
	_config = config
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE * BOX_SIZE
	_box = _mesh(box_mesh, ToonMaterials.toon(DS.STONE_CREAM, RIM))
	_box.position.y = BOX_SIZE * 0.5
	_shape = _mesh(shape_mesh(kind), ToonMaterials.toon(kind_color(kind), RIM))
	_shape.position.y = BOMB_RADIUS
	if kind == Item.Kind.BAT:
		_shape.rotation.z = PI * 0.5  # lies on the ground
	var fuse_mesh := SphereMesh.new()
	fuse_mesh.radius = FUSE_RADIUS
	fuse_mesh.height = FUSE_RADIUS * 2.0
	_fuse = _mesh(fuse_mesh, ToonMaterials.toon(DS.FIRE))
	_fuse.position.y = BOMB_RADIUS * 2.0 + FUSE_RADIUS
	var disc := CylinderMesh.new()
	disc.top_radius = SHADOW_RADIUS
	disc.bottom_radius = SHADOW_RADIUS
	disc.height = SHADOW_HEIGHT
	_shadow = _mesh(disc, ToonMaterials.translucent(DS.GROUND_SHADOW))


func apply(prev: Dictionary, curr: Dictionary, alpha: float, tick: int) -> void:
	var to: Vector3 = curr["pos"]
	position = (prev["pos"] as Vector3).lerp(to, alpha) if not prev.is_empty() else to
	var falling := int(curr["state"]) == Item.State.FALLING
	_box.visible = falling
	_shape.visible = not falling
	_shadow.visible = falling
	if falling:
		_shadow.position.y = SHADOW_LIFT - position.y
		var s := shadow_scale(position.y, _config.item_drop_height)
		_shadow.scale = Vector3(s, 1.0, s)
	_fuse.visible = not falling and fuse_visible(int(curr["fuse_ticks"]), tick)


func box_visible() -> bool:
	return _box.visible


func shape_visible() -> bool:
	return _shape.visible


func shadow_visible() -> bool:
	return _shadow.visible


func _mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material
	add_child(m)
	return m
