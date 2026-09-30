extends GutTest
## LoginPanel (design.md DS-CMP-14): frosted glass card with emblem, title, tagline, Google pill,
## helper line, language link and debug skip; states, signals and the calm entrance.

const LOGIN_PANEL := preload("res://src/ui/components/login_panel/login_panel.tscn")


func _login() -> LoginPanel:
	var p := LOGIN_PANEL.instantiate() as LoginPanel
	add_child_autofree(p)
	return p


func test_gallery_registers_the_login_panel() -> void:
	var registered: Array[String] = []
	for entry: Array in (load("res://src/debug/ds_gallery.gd") as GDScript).get_script_constant_map()["COMPONENTS"]:
		registered.append(String(entry[1]))
	assert_true(registered.has("res://src/ui/components/login_panel/login_panel.tscn"))


func test_calm_token() -> void:
	var calm := UiMotion.spec(UiMotion.Token.CALM)
	assert_eq(calm["duration"], DS.MOTION_CALM)
	assert_eq(calm["trans"], Tween.TRANS_SINE, "no bounce")


func test_card_contents() -> void:
	var p := _login()
	assert_eq(p.logo().text, "The Brawl Guys")
	assert_eq(p.google_button().text, "Google로 시작하기")
	assert_true(p.google_button() is GoogleButton)
	assert_eq(p.language_button().text, "English")
	assert_true(p.card() is GlassCard)
	var box := p.card().get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(box.corner_radius_top_left, DS.RADIUS_XL)
	assert_not_null(p.card().material, "frosted blur shader")


func test_glass_falls_back_to_more_tint_without_blur() -> void:
	assert_eq(GlassCard.tint_strength("gl_compatibility"), DS.GLASS_TINT_STRENGTH_NO_BLUR)
	assert_eq(GlassCard.tint_strength("mobile"), DS.GLASS_TINT_STRENGTH)
	assert_gt(DS.GLASS_TINT_STRENGTH_NO_BLUR, DS.GLASS_TINT_STRENGTH)


func test_login_panel_states() -> void:
	var p := _login()
	assert_eq(p.state(), LoginPanel.State.IDLE)
	assert_false(p.google_button().disabled)
	p.set_state(LoginPanel.State.LOADING, "브라우저에서 로그인을 마쳐 주세요")
	assert_true(p.google_button().disabled, "no double sign-in while waiting")
	assert_eq(p.google_button().text, "로그인 중…")
	assert_eq(p.message_text(), "브라우저에서 로그인을 마쳐 주세요")
	p.set_state(LoginPanel.State.ERROR, "시간이 지나 로그인이 취소됐어요")
	assert_false(p.google_button().disabled, "retry")
	assert_eq(p.google_button().text, "다시 시도")


func test_unavailable_sign_in_keeps_the_button_disabled() -> void:
	var p := _login()
	p.set_google_enabled(false)
	p.set_state(LoginPanel.State.ERROR, "x")
	assert_true(p.google_button().disabled)


func test_signals_and_skip() -> void:
	var p := _login()
	assert_false(p.skip_button().visible, "skip hidden by default")
	p.set_skip_visible(true)
	assert_true(p.skip_button().visible)
	watch_signals(p)
	p.google_button().pressed.emit()
	p.skip_button().pressed.emit()
	assert_signal_emitted(p, "google_pressed")
	assert_signal_emitted(p, "skip_pressed")


func test_language_link_flips_the_card() -> void:
	var p := _login()
	watch_signals(p)
	p.language_button().pressed.emit()
	assert_eq(p.language(), LoginText.EN)
	assert_eq(p.google_button().text, "Continue with Google")
	assert_eq(p.language_button().text, "한국어")
	assert_signal_emitted_with_parameters(p, "language_changed", [LoginText.KO, LoginText.EN])
	p.toggle_language()
	assert_eq(p.google_button().text, "Google로 시작하기")


func test_card_is_centered() -> void:
	var p := _login()
	await wait_process_frames(2)
	var center := p.card().get_global_rect().get_center()
	assert_almost_eq(center.x, p.size.x * 0.5, 2.0)
	assert_almost_eq(center.y, p.size.y * 0.5, 2.0)


func test_calm_entrance_brings_everything_in() -> void:
	var p := _login()
	await wait_process_frames(2)
	var rest := p.card().position
	p.play_entrance()
	assert_almost_eq(p.card().modulate.a, 0.0, 0.01, "the card starts invisible")
	assert_gt(p.card().position.y, rest.y, "and a little low")
	assert_lt(p.card().scale.x, 1.0)
	assert_almost_eq(p.google_button().modulate.a, 0.0, 0.01, "contents wait for their stagger")
	await wait_seconds(p.entrance_duration() + 0.2)
	assert_almost_eq(p.card().position.y, rest.y, 0.5)
	assert_almost_eq(p.card().modulate.a, 1.0, 0.01)
	assert_almost_eq(p.google_button().modulate.a, 1.0, 0.01)
	assert_almost_eq(p.logo().modulate.a, 1.0, 0.01)
