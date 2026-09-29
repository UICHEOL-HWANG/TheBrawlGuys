class_name FighterView
extends Node3D
## Draws one fighter (design.md DS-VIS-03, GD-FEEL-03): toon capsule in the player color with a
## rim light, a flat foot ring and a P-label. Interpolates prev -> curr by alpha, snaps when
## spawn_id changes (respawn), blinks while invulnerable, hides when KO. Reads view values only.

const RIM := 0.35
const RING_INNER_RATIO := 1.15
const RING_OUTER_RATIO := 1.45
const RING_FLATTEN := 0.08
const RING_LIFT := 0.02
const LABEL_GAP := 0.6
const LABEL_PIXEL_SIZE := 0.01
const BLINK_END_SECONDS := 0.5

var _config: GameConfig
var _body: MeshInstance3D
var _ring: MeshInstance3D
var _label: Label3D


func setup(index: int, config: GameConfig) -> void:
	_config = config
	var color := PlayerStyle.color(index)

	var capsule := CapsuleMesh.new()
	capsule.radius = config.fighter_radius
	capsule.height = config.fighter_height
	_body = MeshInstance3D.new()
	_body.mesh = capsule
	_body.material_override = ToonMaterials.toon(color, RIM)
	_body.position.y = config.fighter_height * 0.5
	add_child(_body)

	var torus := TorusMesh.new()
	torus.inner_radius = config.fighter_radius * RING_INNER_RATIO
	torus.outer_radius = config.fighter_radius * RING_OUTER_RATIO
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.scale = Vector3(1.0, RING_FLATTEN, 1.0)
	_ring.position.y = RING_LIFT
	_ring.material_override = ToonMaterials.toon(color)
	add_child(_ring)

	_label = Label3D.new()
	_label.text = PlayerStyle.label(index)
	_label.font = load(DS.FONT_DISPLAY_PATH) as Font
	_label.font_size = DS.SIZE_TITLE
	_label.pixel_size = LABEL_PIXEL_SIZE
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = DS.UI_SURFACE
	_label.outline_modulate = DS.CANOPY_DEEP
	_label.outline_size = DS.TEXT_OUTLINE * 2
	_label.position.y = config.fighter_height + LABEL_GAP
	add_child(_label)


func apply(prev: Dictionary, curr: Dictionary, alpha: float, tick: int) -> void:
	if int(curr["state"]) == Fighter.State.KO:
		visible = false
		return
	visible = true
	position = interpolate(prev, curr, alpha)
	var facing: Vector3 = curr["facing"]
	rotation.y = Collision.yaw_of(facing)
	_body.visible = blink_visible(int(curr["invuln_ticks"]), tick, _config)


static func interpolate(prev: Dictionary, curr: Dictionary, alpha: float) -> Vector3:
	var to: Vector3 = curr["pos"]
	if prev.is_empty() or prev.get("spawn_id") != curr.get("spawn_id"):
		return to
	var from: Vector3 = prev["pos"]
	return from.lerp(to, alpha)


static func blink_visible(invuln_ticks: int, tick: int, config: GameConfig) -> bool:
	if invuln_ticks <= 0:
		return true
	var hz := config.blink_hz_end if invuln_ticks <= SimTime.to_ticks(BLINK_END_SECONDS) else config.blink_hz
	var phase := floori(float(tick) * hz * 2.0 / SimTime.TICK_RATE)
	return phase % 2 == 0
