class_name GimmickViews
extends RefCounted
## Registry of gimmick views: maps a Gimmick.kind() to the view that draws it (DS-VIS-04). On ice
## themes (frozen pond) breakable platforms are ice patches instead of wooden planks.


## A new view for kind, or null (with a warning) when nothing draws that kind yet.
static func create(kind: String, theme: ArenaTheme = null) -> GimmickView:
	match kind:
		"burn_zone":
			return CampfireView.new()
		"platform":
			return IcePatchView.new() if theme != null and theme.ice_floor else PlankView.new()
		"bounce_pad":
			return MushroomPadView.new()
		"fog":
			return FogView.new()
	push_warning("GimmickViews: no view for gimmick kind '%s'" % kind)
	return null
