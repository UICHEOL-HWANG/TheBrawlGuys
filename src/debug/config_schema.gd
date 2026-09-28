class_name ConfigSchema
extends RefCounted
## Converts @export_range properties of a Resource into slider specs for the debug panel.

const DEFAULT_STEP := 0.01


static func sliders_for(res: Resource) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var group := ""
	for p: Dictionary in res.get_property_list():
		var usage: int = p["usage"]
		if usage & PROPERTY_USAGE_GROUP:
			group = p["name"]
			continue
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or p["hint"] != PROPERTY_HINT_RANGE:
			continue
		var parts := String(p["hint_string"]).split(",")
		out.append({
			"name": String(p["name"]),
			"group": group,
			"min": float(parts[0]),
			"max": float(parts[1]),
			"step": float(parts[2]) if parts.size() > 2 else DEFAULT_STEP,
			"is_int": p["type"] == TYPE_INT,
		})
	return out
