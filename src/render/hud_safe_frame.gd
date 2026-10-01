class_name HudSafeFrame
extends RefCounted
## Keeps the fight out from under the HUD strip (combat-depth D, GD-CAM-01): the match camera
## frames its targets into the screen between a reserved top share a and bottom share b instead
## of the whole screen, with an off-axis (shifted) frustum so the on-screen field of view stays
## cam_fov. Pure math.
##
## Tangent space (half heights at unit depth): the full screen spans [c - T, c + T] with
## T = tan(fov / 2); CameraFraming fits targets into [-t, t] around the optical axis. Asking that
## fit window to be the free band, [c - T + 2Tb, c + T - 2Ta], gives t = T(1 - a - b) and
## c = T(a - b) (window shifted up for a top HUD, down for a bottom one). Horizontally nothing is
## reserved: the fit aspect is aspect / (1 - a - b) so t * fit_aspect = T * aspect.

## Never reserve more than this share of the screen height.
const MAX_SHARE := 0.45


## {"fov": fit fov in degrees, "aspect": fit aspect, "shift": c / T (0 = centered)} for top and
## bottom shares of the screen height (together clamped to MAX_SHARE).
static func fit(fov_deg: float, aspect: float, top: float, bottom: float = 0.0) -> Dictionary:
	var a := clampf(top, 0.0, MAX_SHARE)
	var b := clampf(bottom, 0.0, MAX_SHARE - a)
	var t := tan(deg_to_rad(fov_deg) * 0.5)
	var free := 1.0 - a - b
	return {"fov": rad_to_deg(2.0 * atan(t * free)), "aspect": aspect / free, "shift": a - b}


## Frustum projection values for a Camera3D (keep height): near-plane window height and offset.
static func frustum(fov_deg: float, near: float, shift: float) -> Dictionary:
	var t := tan(deg_to_rad(fov_deg) * 0.5)
	return {"size": 2.0 * t * near, "offset": Vector2(0.0, t * shift * near)}
