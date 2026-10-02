class_name BatUseDots
extends Node3D
## Swing dots over a fighter's head (design.md DS-VIS-05): one glowing dot per swing left while
## the fighter carries a melee item (bat, hammer, glove), centered over the head whatever the
## count, none otherwise. Origin at the fighter's feet.

const DOT_RADIUS := 0.06
const DOT_SPACING := 0.16
const DOT_GAP := 0.25

var _dots: Array[MeshInstance3D] = []


func setup(config: GameConfig) -> void:
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = DOT_RADIUS
	dot_mesh.height = DOT_RADIUS * 2.0
	var most := maxi(config.bat_uses, maxi(config.hammer_uses, config.glove_uses))
	for i: int in most:
		var dot := MeshInstance3D.new()
		dot.mesh = dot_mesh
		dot.material_override = ToonMaterials.toon(DS.GLOW)
		dot.position = Vector3(0.0, config.fighter_height + DOT_GAP, 0.0)
		dot.visible = false
		add_child(dot)
		_dots.append(dot)


func show_uses(item_kind: int, uses: int) -> void:
	var n := mini(uses, _dots.size()) if Item.is_melee(item_kind) else 0
	for i: int in _dots.size():
		_dots[i].visible = i < n
		_dots[i].position.x = (i - (n - 1) * 0.5) * DOT_SPACING  # the row stays centered


func shown() -> int:
	var n := 0
	for dot: MeshInstance3D in _dots:
		if dot.visible:
			n += 1
	return n
