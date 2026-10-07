class_name FighterView
extends Node3D
## Draws one fighter (design.md DS-VIS-03, GD-FEEL-03): the KayKit model of its character (the
## slot's model for the classic fighter; capsule fallback if the model fails to load), with its
## FighterIdentity (shaped foot ring + P-label). Interpolates prev -> curr by alpha, snaps when
## spawn_id changes (respawn), blinks while invulnerable, hides when KO. Reads view values only.
## Shows the carried item in hand, with use dots for bats (DS-VIS-05), and the style gear (StyleGear, DS-VIS-02).

const RIM := 0.35
const BLINK_END_SECONDS := 0.5
const HAND_SIDE := 0.9
const HAND_FORWARD := 0.4

var _config: GameConfig
var _body: MeshInstance3D
var _model: CharacterModel = null
var _animator: CharacterAnimator = null
var _identity: FighterIdentity
var _held: HeldItem
var _charge_glow: ChargeGlow
var _dots: BatUseDots
var _bubble: GuardBubble
var _gear: StyleGear
var _blob: BlobShadow
var _blob_wanted: bool = false
var _lift: float = 0.0


## character: the slot's CharacterData id — its model (Phase 5 T9); "" keeps the slot's model.
func setup(index: int, config: GameConfig, character: String = CharacterData.DEFAULT) -> void:
	_config = config
	_build_body(index, config, CharacterCatalog.for_character(character, index))
	_identity = FighterIdentity.new()
	add_child(_identity)
	_identity.setup(index, config)
	var hand_spot := Vector3(config.fighter_radius * HAND_SIDE,
			config.fighter_height * ItemActions.HAND_HEIGHT_RATIO, config.fighter_radius * HAND_FORWARD)
	_attach_held(config, hand_spot)
	_charge_glow = ChargeGlow.new()
	_charge_glow.position = hand_spot
	add_child(_charge_glow)
	_dots = BatUseDots.new()
	add_child(_dots)
	_dots.setup(config)
	_bubble = GuardBubble.new()
	add_child(_bubble)
	_bubble.setup(config)
	_gear = StyleGear.new(_model, _animator)
	_blob = BlobShadow.new()
	add_child(_blob)
	_blob.setup(config)


func apply(prev: Dictionary, curr: Dictionary, alpha: float, tick: int) -> void:
	if int(curr["state"]) == Fighter.State.KO:
		visible = false
		_blob.visible = false
		return
	visible = true
	_lift = GrabLift.step(_lift, int(curr["state"]) == Fighter.State.HELD)
	position = interpolate(prev, curr, alpha) + Vector3.UP * _lift
	_blob.follow(position)
	_blob.visible = _blob_wanted
	var facing: Vector3 = curr["facing"]
	rotation.y = Collision.yaw_of(facing)
	var charging := int(curr["state"]) == Fighter.State.CHARGE
	_charge_glow.set_charge(float(curr.get("charge_ticks", 0)) / maxf(SimTime.to_ticks(_config.heavy_charge_max_time), 1.0) if charging else 0.0)
	var shown := blink_visible(int(curr["invuln_ticks"]), tick, _config)
	if _model != null:
		_model.visible = shown
	else:
		_body.visible = shown
	_held.show_item(int(curr.get("item_kind", Fighter.NONE)), int(curr.get("item_uses", 0)))
	_dots.show_uses(int(curr.get("item_kind", Fighter.NONE)), int(curr.get("item_uses", 0)))
	_gear.follow(curr)
	_bubble.visible = int(curr["state"]) == Fighter.State.GUARD


## Advances the character animation from the latest sim view (main calls this every frame).
func animate(curr: Dictionary, delta: float) -> void:
	if _animator != null and int(curr["state"]) != Fighter.State.KO:
		_animator.apply(curr, delta)


func animator() -> CharacterAnimator:
	return _animator


func model() -> CharacterModel:
	return _model


func gear() -> StyleGear:
	return _gear


## Soap-bubble wobble when a guarded hit lands (DS-VFX-02).
func wobble() -> void:
	_bubble.wobble()


## Foot ring and P-label (DS-VIS-03). The menu backdrop hides them: no player identity in menus.
func set_identity_visible(on: bool) -> void:
	_identity.set_shown(on)


func identity_visible() -> bool:
	return _identity.is_shown()


func identity() -> FighterIdentity:
	return _identity


## The character model (or the capsule in the player color when it cannot load) and its animator.
func _build_body(index: int, config: GameConfig, entry: Dictionary) -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = config.fighter_radius
	capsule.height = config.fighter_height
	_body = MeshInstance3D.new()
	_body.mesh = capsule
	_body.material_override = ToonMaterials.toon(PlayerStyle.color(index), RIM)
	_body.position.y = config.fighter_height * 0.5
	add_child(_body)
	_model = CharacterModel.new()
	add_child(_model)
	if not _model.setup(entry, config):
		_model.queue_free()
		_model = null
		return
	_body.visible = false
	if _model.animation_player() != null:
		_animator = CharacterAnimator.new()
		add_child(_animator)
		_animator.setup(_model.animation_player(), config)


func set_blob_shadow(on: bool) -> void:
	_blob_wanted = on
	_blob.visible = on


func blob_visible() -> bool:
	return _blob.visible


func blob() -> BlobShadow:
	return _blob


func bubble_visible() -> bool:
	return _bubble.visible


## The guard bubble (DefenseFx sizes and flashes it by the guard meter).
func bubble() -> MeshInstance3D:
	return _bubble


## The carried item rides on the character's hand slot (or a fixed spot on the capsule).
func _attach_held(config: GameConfig, hand_spot: Vector3) -> void:
	_held = HeldItem.new()
	_held.position = hand_spot
	add_child(_held)
	var hand := _model.hand_slot() if _model != null else null
	if hand == null:
		_held.setup(config)
		return
	var hand_scale := hand.global_transform.basis.get_scale().x if hand.is_inside_tree() else _model.model_scale()
	_held.setup(config, hand, hand_scale)


func held_item() -> HeldItem:
	return _held


func held_visible() -> bool:
	return _held.visible


func dots_shown() -> int:
	return _dots.shown()


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
