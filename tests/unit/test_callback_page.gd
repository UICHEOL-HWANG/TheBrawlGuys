extends GutTest
## Desktop sign-in callback page (platform B, PRD-AUTH-01): the browser tab the loopback server
## answers matches the login card (crest, DS colors, calm copy) instead of a bare heading.


func test_success_page_has_crest_title_and_hint() -> void:
	var html := CallbackPage.html(true)
	assert_true(html.begins_with("<!doctype html>"))
	assert_string_contains(html, "<svg")
	assert_string_contains(html, CallbackPage.DONE_TITLE)
	assert_string_contains(html, CallbackPage.DONE_HINT)
	assert_false(html.contains(CallbackPage.FAIL_TITLE))


func test_failure_page_asks_to_retry() -> void:
	var html := CallbackPage.html(false)
	assert_string_contains(html, CallbackPage.FAIL_TITLE)
	assert_string_contains(html, CallbackPage.FAIL_HINT)


func test_page_colors_come_from_design_tokens() -> void:
	var html := CallbackPage.html(true)
	for c: Color in [DS.CANOPY_DEEP, DS.CANOPY, DS.FIRE, DS.UI_TEXT_SOFT, DS.UI_SURFACE_DIM]:
		assert_string_contains(html, "#" + c.to_html(false))


func test_crest_svg_uses_the_logo_shield_outline() -> void:
	var svg := CallbackPage.crest_svg()
	var first: Vector2 = CrestLogo.shield_points(1.0)[0]
	assert_string_contains(svg, "%.3f,%.3f" % [first.x, first.y])


func test_loopback_serves_the_page_with_exact_length() -> void:
	var reply := LoopbackServer.http_response(200, CallbackPage.html(true))
	var body := reply.get_slice("\r\n\r\n", 1)
	assert_string_contains(reply, "Content-Length: %d" % body.to_utf8_buffer().size())
	assert_string_contains(body, CallbackPage.DONE_TITLE)
