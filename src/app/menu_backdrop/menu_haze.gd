class_name MenuHaze
extends CanvasLayer
## Full-screen haze over the menu diorama (design.md DS-LAY-03): desaturation plus a warm
## sage-gray wash (DS tokens), sitting above the 3D view and below the app UI. reveal() clears it
## from fully hazed to the resting amount on the calm motion token.

const SHADER := preload("res://src/app/menu_backdrop/menu_haze.gdshader")
const LAYER := 1
const AMOUNT_PARAM := "shader_parameter/amount"

var _material: ShaderMaterial


func _ready() -> void:
	layer = LAYER
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("haze_color", DS.HAZE)
	_material.set_shader_parameter("desaturate", DS.HAZE_DESATURATE)
	var rect := ColorRect.new()
	rect.material = _material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	set_amount(DS.HAZE_AMOUNT)


func set_amount(value: float) -> void:
	_material.set(AMOUNT_PARAM, value)


func amount() -> float:
	return float(_material.get(AMOUNT_PARAM))


## The diorama fades in out of the haze.
func reveal() -> Tween:
	set_amount(1.0)
	var tw := UiMotion.parallel(self)
	UiMotion.step(tw, _material, AMOUNT_PARAM, DS.HAZE_AMOUNT, UiMotion.Token.CALM)
	return tw
