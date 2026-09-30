class_name JsonSafe
extends RefCounted
## JSON-safe values for Amplitude properties and Supabase rows (platform A2/A6): vectors become
## rounded arrays, StringNames become Strings, containers are converted recursively.

## Decimal step kept for floats and vector components (millimetres are plenty for analysis).
const DECIMAL_STEP := 0.001


static func to_json_value(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR3:
			var p: Vector3 = v
			return [snappedf(p.x, DECIMAL_STEP), snappedf(p.y, DECIMAL_STEP), snappedf(p.z, DECIMAL_STEP)]
		TYPE_VECTOR2:
			var q: Vector2 = v
			return [snappedf(q.x, DECIMAL_STEP), snappedf(q.y, DECIMAL_STEP)]
		TYPE_STRING_NAME:
			return String(v)
		TYPE_FLOAT:
			return snappedf(float(v), DECIMAL_STEP)
		TYPE_DICTIONARY:
			var out := {}
			for k: Variant in (v as Dictionary):
				out[str(k)] = to_json_value((v as Dictionary)[k])
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for item: Variant in (v as Array):
				arr.append(to_json_value(item))
			return arr
	return v


static func is_safe(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_DICTIONARY:
			for k: Variant in (v as Dictionary):
				if typeof(k) != TYPE_STRING or not is_safe((v as Dictionary)[k]):
					return false
			return true
		TYPE_ARRAY:
			for item: Variant in (v as Array):
				if not is_safe(item):
					return false
			return true
	return false
