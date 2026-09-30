class_name FighterView
extends Node3D
## Draws one fighter (design.md DS-VIS-03, GD-FEEL-03): the KayKit character for its slot (capsule fallback if the model fails to load),
## with a flat foot ring and a P-label. Interpolates prev -> curr by alpha, snaps when
## spawn_id changes (respawn), blinks while invulnerable, hides when KO. Reads view values only.
## Shows the carried item in hand, with use dots for bats (DS-VIS-05).

const RIM := 0.35
const RING_INNER_RATIO := 1.15
const RING_OUTER_RATIO := 1.45
const RING_FLATTEN := 0.08
const RING_LIFT := 0.02
const LABEL_GAP := 0.6
const LABEL_PIXEL_SIZE := 0.01
const BLINK_END_SECONDS := 0.5
const HELD_SCALE := 0.75
const HAND_SIDE := 0.9
const HAND_FORWARD := 0.4
const DOT_RADIUS := 0.06
const DOT_SPACING := 0.16
const DOT_GAP := 0.25
const BUBBLE_RADIUS_RATIO := 0.62
const WOBBLE_SQUASH := Vector3(1.12, 0.88, 1.12)

var _config: GameConfig
var _body: MeshInstance3D
var _model: CharacterModel = null
var _animator: CharacterAnimator = null
var _ring: MeshInstance3D
var _label: Label3D
var _held: MeshInstance3D
var _held_kind: int = Fighter.NONE
var _dots: Array[MeshInstance3D] = []
var _bubble: MeshInstance3D


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
	_model = CharacterModel.new()
	add_child(_model)
	if _model.setup(CharacterCatalog.for_player(index), config):
		_body.visible = false
		if _model.animation_player() != null:
			_animator = CharacterAnimator.new()
			add_child(_animator)
			_animator.setup(_model.animation_player(), config)
	else:
		_model.queue_free()
		_model = null

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

	_held = MeshInstance3D.new()
	_held.scale = Vector3.ONE * HELD_SCALE
	_held.position = Vector3(config.fighter_radius * HAND_SIDE,
			config.fighter_height * ItemActions.HAND_HEIGHT_RATIO, config.fighter_radius * HAND_FORWARD)
	_held.visible = false
	add_child(_held)
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = DOT_RADIUS
	dot_mesh.height = DOT_RADIUS * 2.0
	for i: int in config.bat_uses:
		var dot := MeshInstance3D.new()
		dot.mesh = dot_mesh
		dot.material_override = ToonMaterials.toon(DS.GLOW)
		dot.position = Vector3((i - (config.bat_uses - 1) * 0.5) * DOT_SPACING, config.fighter_height + DOT_GAP, 0.0)
		dot.visible = false
		add_child(dot)
		_dots.append(dot)

	var sphere := SphereMesh.new()
	sphere.radius = config.fighter_height * BUBBLE_RADIUS_RATIO
	sphere.height = sphere.radius * 2.0
	_bubble = MeshInstance3D.new()
	_bubble.mesh = sphere
	_bubble.material_override = ToonMaterials.translucent(DS.GUARD_BUBBLE)
	_bubble.position.y = config.fighter_height * 0.5
	_bubble.visible = false
	add_child(_bubble)


func apply(prev: Dictionary, curr: Dictionary, alpha: float, tick: int) -> void:
	if int(curr["state"]) == Fighter.State.KO:
		visible = false
		return
	visible = true
	position = interpolate(prev, curr, alpha)
	var facing: Vector3 = curr["facing"]
	rotation.y = Collision.yaw_of(facing)
	var shown := blink_visible(int(curr["invuln_ticks"]), tick, _config)
	if _model != null:
		_model.visible = shown
	else:
		_body.visible = shown
	_show_item(int(curr.get("item_kind", Fighter.NONE)), int(curr.get("item_uses", 0)))
	_bubble.visible = int(curr["state"]) == Fighter.State.GUARD


## Advances the character animation from the latest sim view (main calls this every frame).
func animate(curr: Dictionary, delta: float) -> void:
	if _animator != null and int(curr["state"]) != Fighter.State.KO:
		_animator.apply(curr, delta)


func animator() -> CharacterAnimator:
	return _animator


func model() -> CharacterModel:
	return _model


## Soap-bubble wobble when a guarded hit lands (DS-VFX-02).
func wobble() -> void:
	_bubble.scale = WOBBLE_SQUASH
	var tw := create_tween()
	tw.tween_property(_bubble, "scale", Vector3.ONE, DS.MOTION_SQUISH).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func bubble_visible() -> bool:
	return _bubble.visible


func _show_item(kind: int, uses: int) -> void:
	_held.visible = kind != Fighter.NONE
	if kind != Fighter.NONE and kind != _held_kind:
		_held.mesh = ItemView.shape_mesh(kind)
		_held.material_override = ToonMaterials.toon(ItemView.kind_color(kind), ItemView.RIM)
	_held_kind = kind
	for i: int in _dots.size():
		_dots[i].visible = kind == Item.Kind.BAT and i < uses


func held_visible() -> bool:
	return _held.visible


func dots_shown() -> int:
	var n := 0
	for dot: MeshInstance3D in _dots:
		if dot.visible:
			n += 1
	return n


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
