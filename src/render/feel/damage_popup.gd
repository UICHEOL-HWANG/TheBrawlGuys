class_name DamagePopup
extends Node3D
## Floating damage numbers (design.md DS-VFX-09): "+12%" above the victim, in the DamageCounter
## ramp color of the victim's new total (DamageColor), sized by the hit tier. Pops, rises and
## fades. A fixed pool of Label3D nodes is reused (FxPool). Off when GameConfig.damage_popups = 0.

const LIFETIME := 0.75
const RISE := 1.1
const FADE_FROM := 0.45
const POP_TIME := 0.08
const POP_OVERSHOOT := 1.35
const HEAD_GAP := 1.1
const PIXEL_SIZE := 0.00065
const FONT_SIZE := DS.SIZE_DISPLAY_L

var _config: GameConfig
var _pool: FxPool
var _labels: Array[Label3D] = []
var _ages: Array[float] = []
var _starts: Array[Vector3] = []


func setup(config: GameConfig) -> void:
	_config = config
	_pool = FxPool.new(ImpactTier.pool_cap(Quality.particle_scale(config)))
	var font := load(DS.FONT_DISPLAY_PATH) as Font
	for i: int in _pool.size():
		_labels.append(_label(font))
		_ages.append(LIFETIME)
		_starts.append(Vector3.ZERO)


func capacity() -> int:
	return _labels.size()


## Shows dealt% above `at` (the victim's feet); returns the label used, or null when turned off.
func show_hit(at: Vector3, dealt: float, total: float, tier: int) -> Label3D:
	if _config == null or _config.damage_popups == 0:
		return null
	var i := _pool.acquire()
	var label := _labels[i]
	label.text = ImpactTier.popup_text(dealt)
	label.font_size = roundi(FONT_SIZE * ImpactTier.popup_scale(tier))
	label.outline_size = DS.TEXT_OUTLINE * 4
	label.modulate = DamageColor.for_percent(total)
	_starts[i] = at + Vector3.UP * (_config.fighter_height + HEAD_GAP)
	_ages[i] = 0.0
	label.visible = true
	_place(i)
	return label


func clear() -> void:
	for i: int in _labels.size():
		_ages[i] = LIFETIME
		_labels[i].visible = false


func active_count() -> int:
	var n := 0
	for age: float in _ages:
		if age < LIFETIME:
			n += 1
	return n


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	for i: int in _labels.size():
		if _ages[i] >= LIFETIME:
			continue
		_ages[i] += delta
		if _ages[i] >= LIFETIME:
			_labels[i].visible = false
			continue
		_place(i)


## Position, pop scale and fade for the label's age.
func _place(i: int) -> void:
	var t := _ages[i] / LIFETIME
	var label := _labels[i]
	label.position = _starts[i] + Vector3.UP * RISE * (1.0 - (1.0 - t) * (1.0 - t))
	var pop := minf(_ages[i] / POP_TIME, 1.0)
	label.scale = Vector3.ONE * lerpf(POP_OVERSHOOT, 1.0, pop)
	var a := 1.0 - clampf((t - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)
	label.modulate.a = a
	label.outline_modulate.a = a


func _label(font: Font) -> Label3D:
	var label := Label3D.new()
	label.font = font
	label.pixel_size = PIXEL_SIZE
	label.fixed_size = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 3
	label.outline_render_priority = 2
	label.outline_modulate = DS.CANOPY_DEEP
	label.visible = false
	add_child(label)
	return label
