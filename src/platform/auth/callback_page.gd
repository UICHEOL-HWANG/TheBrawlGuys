class_name CallbackPage
extends RefCounted
## Browser page the desktop loopback server answers after Google sign-in (PRD-AUTH-01).
## Mirrors the login card (DS-CMP-14): calm sage backdrop, frosted card, the crest (DS-CMP-15)
## as inline SVG built from CrestLogo's own geometry, and DS token colors only.

const DONE_TITLE := "로그인 완료"
const DONE_HINT := "이 창을 닫고 게임으로 돌아가세요."
const FAIL_TITLE := "로그인하지 못했어요"
const FAIL_HINT := "게임으로 돌아가 다시 시도해 주세요."
const PAGE_TITLE := "The Brawl Guys"
## The tab tries to close itself after this long (only works when the browser allows it).
const AUTO_CLOSE_MS := 2500


static func html(success: bool) -> String:
	var title := DONE_TITLE if success else FAIL_TITLE
	var hint := DONE_HINT if success else FAIL_HINT
	var close_script := "<script>setTimeout(function(){window.close()},%d)</script>" % AUTO_CLOSE_MS if success else ""
	return "<!doctype html><html lang=\"ko\"><head><meta charset=\"utf-8\">" \
		+ "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">" \
		+ "<title>%s</title><style>%s</style></head><body><main class=\"card\">" % [PAGE_TITLE, _css()] \
		+ crest_svg() + "<p class=\"brand\">%s</p><h1>%s</h1><p class=\"hint\">%s</p>" % [PAGE_TITLE, title, hint] \
		+ "</main>%s</body></html>" % close_script


## The crest in unit space (viewBox -1..1), same shapes and colors as CrestLogo._draw().
static func crest_svg() -> String:
	var bomb := CrestLogo.BOMB_CENTER
	var r := CrestLogo.BOMB_RADIUS
	var tip: Vector2 = CrestLogo.FUSE[CrestLogo.FUSE.size() - 1]
	var parts: Array[String] = [
		_polygon(CrestLogo.shield_points(1.0), DS.CANOPY_DEEP),
		_polygon(CrestLogo.shield_points(CrestLogo.INNER_SCALE), DS.CANOPY),
		"<g transform=\"rotate(%.1f)\">%s</g>" % [rad_to_deg(CrestLogo.SHAFT_ANGLE), _shaft()],
		"<g transform=\"rotate(%.1f)\">%s</g>" % [rad_to_deg(CrestLogo.BAT_ANGLE), _bat()],
		_rect(bomb + Vector2(-0.06, -r - 0.05), Vector2(0.12, 0.08), DS.CANOPY_DEEP),
		_circle(bomb, r, DS.CANOPY_DEEP),
		_circle(bomb + Vector2(-0.1, -0.1), 0.075, DS.UI_TEXT_SOFT),
		"<polyline points=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"0.045\" stroke-linecap=\"round\"/>" % [
			_points(PackedVector2Array(CrestLogo.FUSE)), _hex(DS.DIRT)],
		_polygon(CrestLogo.star_points(tip, CrestLogo.SPARK_RADIUS, CrestLogo.SPARK_POINTS), DS.FIRE, "spark"),
	]
	return "<svg class=\"crest\" viewBox=\"-1 -1 2 2\" role=\"img\" aria-label=\"crest\">%s</svg>" % "".join(parts)


static func _shaft() -> String:
	return _line(Vector2(0.0, -0.74), Vector2(0.0, 0.64), DS.STONE_SHADE, 0.09)


static func _bat() -> String:
	var barrel := PackedVector2Array([Vector2(-0.1, -0.7), Vector2(0.1, -0.7), Vector2(0.045, 0.05),
		Vector2(-0.045, 0.05)])
	return _circle(Vector2(0.0, -0.7), 0.1, DS.DIRT) + _polygon(barrel, DS.DIRT) \
		+ _line(Vector2(0.0, 0.03), Vector2(0.0, 0.62), DS.BARK, 0.07) + _circle(Vector2(0.0, 0.66), 0.07, DS.BARK)


static func _css() -> String:
	var tip: Vector2 = CrestLogo.FUSE[CrestLogo.FUSE.size() - 1]
	return ("html,body{margin:0;height:100%%}body{display:flex;align-items:center;justify-content:center;"
		+ "background:radial-gradient(circle at 50%% 35%%,%s,%s 70%%);"
		+ "font-family:-apple-system,BlinkMacSystemFont,'Pretendard','Apple SD Gothic Neo',sans-serif;color:%s}"
		+ ".card{width:min(420px,86vw);padding:40px 32px;border-radius:36px;text-align:center;"
		+ "background:%s;border:1px solid %s;box-shadow:0 18px 48px %s}"
		+ ".crest{width:104px;height:104px;display:block;margin:0 auto 14px}"
		+ ".brand{margin:0;font-size:14px;letter-spacing:.3em;color:%s}"
		+ "h1{margin:10px 0 8px;font-size:30px;font-weight:800;color:%s}"
		+ ".hint{margin:0;font-size:16px;line-height:1.6;color:%s}"
		+ ".spark{transform-box:view-box;transform-origin:%.3fpx %.3fpx;animation:f 1.2s ease-in-out infinite alternate}"
		+ "@keyframes f{from{transform:scale(.85)}to{transform:scale(1.15)}}") % [
		_hex(DS.GLOW), _hex(DS.UI_SURFACE_DIM), _hex(DS.UI_TEXT), _rgba(DS.UI_SURFACE, 0.72),
		_rgba(DS.WHITE, 0.8), _rgba(DS.CANOPY_DEEP, 0.18), _hex(DS.UI_TEXT_SOFT), _hex(DS.CANOPY_DEEP),
		_hex(DS.UI_TEXT_SOFT), tip.x + 1.0, tip.y + 1.0]


static func _polygon(pts: PackedVector2Array, c: Color, css_class: String = "") -> String:
	var cls := "" if css_class.is_empty() else " class=\"%s\"" % css_class
	return "<polygon%s points=\"%s\" fill=\"%s\"/>" % [cls, _points(pts), _hex(c)]


static func _circle(center: Vector2, radius: float, c: Color) -> String:
	return "<circle cx=\"%.3f\" cy=\"%.3f\" r=\"%.3f\" fill=\"%s\"/>" % [center.x, center.y, radius, _hex(c)]


static func _rect(pos: Vector2, rect_size: Vector2, c: Color) -> String:
	return "<rect x=\"%.3f\" y=\"%.3f\" width=\"%.3f\" height=\"%.3f\" fill=\"%s\"/>" % [
		pos.x, pos.y, rect_size.x, rect_size.y, _hex(c)]


static func _line(a: Vector2, b: Vector2, c: Color, width: float) -> String:
	return "<line x1=\"%.3f\" y1=\"%.3f\" x2=\"%.3f\" y2=\"%.3f\" stroke=\"%s\" stroke-width=\"%.3f\" stroke-linecap=\"round\"/>" % [
		a.x, a.y, b.x, b.y, _hex(c), width]


static func _points(pts: PackedVector2Array) -> String:
	var out: PackedStringArray = []
	for p: Vector2 in pts:
		out.append("%.3f,%.3f" % [p.x, p.y])
	return " ".join(out)


static func _hex(c: Color) -> String:
	return "#" + c.to_html(false)


static func _rgba(c: Color, alpha: float) -> String:
	return "rgba(%d,%d,%d,%.2f)" % [c.r8, c.g8, c.b8, alpha]
