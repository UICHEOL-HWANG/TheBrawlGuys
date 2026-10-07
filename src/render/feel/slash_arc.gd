class_name SlashArc
extends Node3D
## The spin slash swirl (combat-motion B2): two flat crescent swooshes around the Knight at
## waist height, a wide one in his color and a thin white blade edge, each bright at the head and
## fading along the tail, whirling while the sweep is active and fading out after it.

## Arc sweep (rad), segments, inner edge as a share of the radius at the head.
const SWEEP := TAU * 0.8
const SEGMENTS := 40
const WIDTH := 0.38
const EDGE_WIDTH := 0.1
const SPIN := -TAU * 3.0
const FADE := 0.2
const HEIGHT := 0.8
const ALPHA := 0.85

static var _meshes: Dictionary = {}

var _wide: MeshInstance3D
var _edge: MeshInstance3D
var _on: bool = false
var _fade: float = 0.0
## Reduce motion: the crescent shows the reach and fades, without whirling.
var still: bool = false


func setup(radius: float, color: Color) -> void:
	_wide = FxMaterials.attach(self, arc_mesh(WIDTH), color, false, 1)
	_edge = FxMaterials.attach(self, arc_mesh(EDGE_WIDTH), DS.WHITE, false, 2)
	for mi: MeshInstance3D in [_wide, _edge]:
		(mi.material_override as StandardMaterial3D).vertex_color_use_as_albedo = true
	_edge.scale = Vector3.ONE * 1.02
	scale = Vector3.ONE * radius
	visible = false


## A unit-radius crescent in the XZ plane: full width at the head (angle 0), a point at the tail,
## vertex alpha falling off along it.
static func arc_mesh(width: float) -> ArrayMesh:
	var key := "%.3f" % width
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var a := -SWEEP * t
		var dir := Vector3(cos(a), 0.0, sin(a))
		var shade := FxMaterials.faded(DS.WHITE, pow(1.0 - t, 1.5))
		st.set_color(shade)
		st.add_vertex(dir)
		st.set_color(shade)
		st.add_vertex(dir * (1.0 - width * (1.0 - t)))
	_meshes[key] = st.commit()
	return _meshes[key]


## Sweeping (true) or done (false: fade out). at: the Knight's feet.
func show_at(at: Vector3, sweeping: bool) -> void:
	position = at + Vector3.UP * HEIGHT
	if sweeping and not _on:
		visible = true
		_fade = 1.0
	_on = sweeping


## The sweep ended (or was cut short): fade out where it is.
func release() -> void:
	_on = false


func advance(delta: float) -> void:
	if not visible:
		return
	if not still:
		rotate_y(SPIN * delta)
	if not _on:
		_fade -= delta / FADE
		if _fade <= 0.0:
			visible = false
			return
	FxMaterials.set_alpha(_wide, ALPHA * _fade)
	FxMaterials.set_alpha(_edge, _fade)


func stop() -> void:
	_on = false
	visible = false
