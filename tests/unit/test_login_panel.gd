extends GutTest
## LoginPanel (design.md DS-CMP-14): states, signals and the three 🖼 entrance candidates.

const LOGIN_PANEL := preload("res://src/ui/components/login_panel/login_panel.tscn")


func _login(variant: int) -> LoginPanel:
	var p := LOGIN_PANEL.instantiate() as LoginPanel
	p.variant = variant
	add_child_autofree(p)
	return p


func test_default_variant_is_the_card() -> void:
	var p := LOGIN_PANEL.instantiate() as LoginPanel
	assert_eq(p.variant, LoginPanel.Variant.CARD)
	p.free()


func test_gallery_registers_the_login_panel() -> void:
	var registered: Array[String] = []
	for entry: Array in (load("res://src/debug/ds_gallery.gd") as GDScript).get_script_constant_map()["COMPONENTS"]:
		registered.append(String(entry[1]))
	assert_true(registered.has("res://src/ui/components/login_panel/login_panel.tscn"))


func test_entrance_tokens() -> void:
	var spring := UiMotion.spec(UiMotion.Token.SPRING)
	assert_eq(spring["duration"], DS.MOTION_ENTRANCE)
	assert_eq(spring["trans"], Tween.TRANS_BACK)
	assert_eq(UiMotion.spec(UiMotion.Token.DROP)["trans"], Tween.TRANS_BOUNCE)


func test_login_panel_states() -> void:
	var p := _login(LoginPanel.Variant.CARD)
	assert_eq(p.state(), LoginPanel.State.IDLE)
	assert_eq(p.google_button().text, "Google로 계속하기")
	assert_false(p.google_button().disabled)
	p.set_state(LoginPanel.State.LOADING, "브라우저에서 로그인을 마쳐 주세요")
	assert_true(p.google_button().disabled, "no double sign-in while waiting")
	assert_eq(p.message_text(), "브라우저에서 로그인을 마쳐 주세요")
	p.set_state(LoginPanel.State.ERROR, "시간이 지나 로그인이 취소됐어요")
	assert_false(p.google_button().disabled, "retry")
	assert_eq(p.google_button().text, "다시 시도")
	assert_eq(p.message_text(), "시간이 지나 로그인이 취소됐어요")


func test_unavailable_sign_in_keeps_the_button_disabled() -> void:
	var p := _login(LoginPanel.Variant.SIDE)
	p.set_google_enabled(false)
	p.set_state(LoginPanel.State.ERROR, "x")
	assert_true(p.google_button().disabled)


func test_login_panel_signals_and_skip() -> void:
	var p := _login(LoginPanel.Variant.CARD)
	assert_false(p.skip_button().visible, "skip hidden by default")
	p.set_skip_visible(true)
	assert_true(p.skip_button().visible)
	watch_signals(p)
	p.google_button().pressed.emit()
	p.skip_button().pressed.emit()
	assert_signal_emitted(p, "google_pressed")
	assert_signal_emitted(p, "skip_pressed")


func test_every_variant_builds_and_finishes_its_entrance() -> void:
	for v: int in [LoginPanel.Variant.CARD, LoginPanel.Variant.SIDE, LoginPanel.Variant.LOGO_DROP]:
		var p := _login(v)
		await wait_process_frames(2)
		var tw := p.play_entrance()
		assert_not_null(tw, "variant %d animates" % v)
		await wait_seconds(p.entrance_duration() + 0.2)
		assert_almost_eq(p.google_button().modulate.a, 1.0, 0.02, "variant %d button visible" % v)
		assert_almost_eq(p.logo().scale.x, 1.0, 0.02, "variant %d logo settled" % v)
		assert_true(p.google_button().is_visible_in_tree())
		assert_true(p.logo().is_visible_in_tree())
