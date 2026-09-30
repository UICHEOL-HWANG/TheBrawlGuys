class_name GimmickViews
extends RefCounted
## Registry of gimmick views: maps a Gimmick.kind() to the view that draws it (DS-VIS-04).


## A new view for kind, or null (with a warning) when nothing draws that kind yet.
static func create(kind: String) -> GimmickView:
	match kind:
		"burn_zone":
			return CampfireView.new()
		"platform":
			return PlankView.new()
		"bounce_pad":
			return MushroomPadView.new()
		"fog":
			return FogView.new()
	push_warning("GimmickViews: no view for gimmick kind '%s'" % kind)
	return null
