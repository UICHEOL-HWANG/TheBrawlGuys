class_name LinearModel
extends RefCounted
## A standardized linear model exported by `python -m brawl_analysis export-models`
## (analysis/src/brawl_analysis/models/export_models.py) into res://data/models/*.json:
##   {"name", "kind": "logistic" | "linear", "features": [names], "mean": [..], "scale": [..],
##    "coef": [..], "intercept": z0, "clip": [lo, hi] (optional), "fixtures": [{"x": {..}, "y": p}]}
## predict(x) = sigmoid or identity of intercept + sum coef_i * (x_i - mean_i) / scale_i; a
## missing feature counts as its mean. "fixtures" are Python predictions the GUT tests replay.

const LOGISTIC := "logistic"
const LINEAR := "linear"

var name: String = ""
var kind: String = LINEAR
var features: Array[String] = []
var fixtures: Array = []
var _mean: PackedFloat64Array = []
var _scale: PackedFloat64Array = []
var _coef: PackedFloat64Array = []
var _intercept: float = 0.0
var _clip := Vector2(-INF, INF)


## The model at `path`, or null (warned) when it is missing or malformed.
static func load_json(path: String) -> LinearModel:
	if not FileAccess.file_exists(path):
		push_warning("LinearModel: %s missing" % path)
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("LinearModel: %s is not a JSON object" % path)
		return null
	return from_dict(data)


static func from_dict(data: Dictionary) -> LinearModel:
	var m := LinearModel.new()
	m.name = String(data.get("name", ""))
	m.kind = String(data.get("kind", LINEAR))
	m.features.assign(data.get("features", []))
	m._mean = PackedFloat64Array(data.get("mean", []))
	m._scale = PackedFloat64Array(data.get("scale", []))
	m._coef = PackedFloat64Array(data.get("coef", []))
	m._intercept = float(data.get("intercept", 0.0))
	var clip: Array = data.get("clip", [])
	if clip.size() == 2:
		m._clip = Vector2(float(clip[0]), float(clip[1]))
	m.fixtures = data.get("fixtures", [])
	var n := m.features.size()
	if m._mean.size() != n or m._scale.size() != n or m._coef.size() != n:
		push_warning("LinearModel: %s has mismatched lengths" % m.name)
		return null
	return m


func predict(x: Dictionary) -> float:
	var z := _intercept
	for i: int in features.size():
		var v: Variant = x.get(features[i])
		if v == null:
			continue
		var s := _scale[i] if _scale[i] != 0.0 else 1.0
		z += _coef[i] * (float(v) - _mean[i]) / s
	if kind == LOGISTIC:
		return 1.0 / (1.0 + exp(-z))
	return clampf(z, _clip.x, _clip.y)
