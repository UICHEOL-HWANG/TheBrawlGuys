class_name UiScale
extends RefCounted
## Responsive UI scale (design.md DS-LAY-04), pure math. The project is laid out at 1920x1080 with
## stretch canvas_items + expand, so on a phone the whole 2D canvas shrinks to ~0.35x of a CSS px
## and captions become unreadable. The factor returned here goes to Window.content_scale_factor:
## it enlarges only the 2D canvas (the 3D view keeps filling the window) until the smallest
## caption reaches the class minimum and the smallest touch button the touch minimum.
## Desktop-class windows always keep 1.0 (the original look). Sizes are in CSS px (points).

const PHONE := "phone"
const TABLET := "tablet"
const DESKTOP := "desktop"
const PORTRAIT := "portrait"
const LANDSCAPE := "landscape"
const BASE_SIZE := Vector2(1920, 1080)
## Factors are rounded up to 1/STEPS (0.05) so tiny resizes do not re-layout every frame.
const STEPS := 20.0
## Layout height (1920x1080 px units) the menus are built to fit. A very short window — a phone
## in landscape with the browser's address and tab bars showing (~280 CSS px) — gets a smaller
## factor rather than menus cut off at the bottom: captions drop below the class minimum there.
const MIN_LAYOUT_HEIGHT := 640.0


## phone: the short side is below DS.PHONE_MAX_SHORT_CSS (any input). tablet: a touch screen
## below DS.TABLET_MAX_SHORT_CSS. Everything else is desktop.
static func classify(css: Vector2, touch: bool) -> String:
	var short_side := minf(css.x, css.y)
	if short_side < DS.PHONE_MAX_SHORT_CSS:
		return PHONE
	if touch and short_side < DS.TABLET_MAX_SHORT_CSS:
		return TABLET
	return DESKTOP


static func orientation(css: Vector2) -> String:
	return PORTRAIT if css.y > css.x else LANDSCAPE


## CSS px per 1920x1080 layout px before the factor (stretch canvas_items, aspect expand).
static func base_scale(css: Vector2) -> float:
	return minf(css.x / BASE_SIZE.x, css.y / BASE_SIZE.y)


## Window.content_scale_factor for a window of css size (1.0 on desktop or unknown sizes).
static func factor(css: Vector2, touch: bool) -> float:
	var s := base_scale(css)
	var view_class := classify(css, touch)
	if s <= 0.0 or view_class == DESKTOP:
		return 1.0
	var caption_min := DS.CAPTION_MIN_PHONE_CSS if view_class == PHONE else DS.CAPTION_MIN_TABLET_CSS
	var need := caption_min / (DS.SIZE_CAPTION * s)
	if touch:
		need = maxf(need, DS.TOUCH_TARGET_MIN_CSS / (DS.TOUCH_TARGET_BASE_MIN * s))
	var fits := floorf(css.y / (s * MIN_LAYOUT_HEIGHT) * STEPS + 0.001) / STEPS
	return clampf(minf(ceilf(need * STEPS - 0.001) / STEPS, fits), 1.0, DS.UI_SCALE_MAX)


## Everything the applier and analytics need: viewport_class, orientation, ui_scale and
## rotate (true when a touch device is held in portrait: ask to turn it sideways).
static func profile(css: Vector2, touch: bool) -> Dictionary:
	var shape := orientation(css)
	return {
		"viewport_class": classify(css, touch), "orientation": shape,
		"ui_scale": factor(css, touch), "rotate": touch and shape == PORTRAIT,
	}


## Layout size (1920x1080 px units) the UI gets at this factor: what must fit on screen.
static func layout_size(css: Vector2, ui_factor: float) -> Vector2:
	var s := base_scale(css) * ui_factor
	return css / s if s > 0.0 else BASE_SIZE


## The analytics subset of a profile (tracking-plan.md §2 global properties).
static func tracking(p: Dictionary) -> Dictionary:
	return {"viewport_class": p["viewport_class"], "orientation": p["orientation"], "ui_scale": p["ui_scale"]}
