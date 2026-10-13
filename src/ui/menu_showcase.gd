class_name MenuShowcase
extends UiPanel
## Shared character exhibit: a full-body portrait and readable combat identity.

signal character_step(direction: int)

const ROLES := {
	"barbarian": ["근접 압박", "가까이 붙어 강하게 밀어내요"],
	"rogue": ["돌진 연타", "빈틈을 파고들어 몰아쳐요"],
	"knight": ["범위 장악", "넓게 휘둘러 접근을 막아요"],
	"mage": ["원거리 견제", "거리를 벌려 불덩이를 날려요"],
}
var _navigation: HBoxContainer
var _position: Label
var _previous: UiMenuButton
var _next: UiMenuButton
var _portraits: Dictionary = {}
var _title: Label
var _role: Label
var _challenge: Label
var _progress: Label
var _progress_bar: ProgressBar
var _special: Label
var _tip: Label
var _compact := false
var _character := ""
var _stage: Control


func build(config: GameConfig, compact: bool = false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.S6)
	add_child(row)
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(DS.CARD_WIDTH, DS.CARD_THUMB_HEIGHT)
	row.add_child(_stage)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", DS.S3)
	row.add_child(text)
	_role = label("", DS.SIZE_CAPTION)
	_title = label("", DS.SIZE_TITLE)
	_tip = label("", DS.SIZE_BODY)
	_special = label("", DS.SIZE_CAPTION)
	for l: Label in [_role, _title, _tip, _special]:
		text.add_child(l)
	_progress = label("")
	_progress.visible = false
	text.add_child(_progress)
	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.max_value = BotProgress.LEVEL_XP
	_progress_bar.custom_minimum_size.y = DS.S2
	_progress_bar.visible = false
	text.add_child(_progress_bar)
	_challenge = label("")
	_challenge.visible = false
	text.add_child(_challenge)
	_navigation = HBoxContainer.new()
	_navigation.add_theme_constant_override("separation", DS.S2)
	_navigation.visible = false
	text.add_child(_navigation)
	_previous = _navigation_button("‹ 이전", -1)
	_position = label("")
	_position.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_position.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_navigation.add_child(_position)
	_next = _navigation_button("다음 ›", 1)
	for id: String in CharacterCards.ORDER:
		var portrait := CharacterPortrait.new()
		portrait.custom_minimum_size = Vector2.ZERO
		_stage.add_child(portrait)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.setup(CharacterCards.entry(id)["model"], config)
		portrait.visible = false
		_portraits[id] = portrait
	set_compact(compact)
	show_character(CharacterCards.ORDER[0])


func show_character(id: String) -> void:
	if not _portraits.has(id):
		return
	for key: String in _portraits:
		var portrait: CharacterPortrait = _portraits[key]
		portrait.visible = key == id
		portrait.set_live(key == id)
	_character = id
	_position.text = "%d / %d" % [CharacterCards.ORDER.find(id) + 1, CharacterCards.ORDER.size()]
	var entry := CharacterCards.entry(id)
	_title.text = "%s · %s" % [entry["title"], ROLES[id][0]] if _compact else String(entry["title"])
	_role.text = "파이터 소개 · %s" % ROLES[id][0]
	_tip.text = String(ROLES[id][1])
	_special.text = "필살기 · %s" % entry["special_name"]


func set_compact(compact: bool) -> void:
	_compact = compact
	_role.visible = not compact
	_stage.custom_minimum_size.y = DS.S8 + DS.S6 if compact else DS.CARD_WIDTH
	_tip.visible = not compact
	if not _character.is_empty():
		show_character(_character)


static func label(text: String, font_size: int = DS.SIZE_CAPTION) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load(DS.FONT_BODY_PATH) as Font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", DS.UI_TEXT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func set_preview() -> void:
	build(GameConfig.new())
	show_character(CharacterData.KNIGHT)


func show_progress(progress: BotProgress) -> void:
	var stats := progress.summary(_character)
	_progress.text = "봇전 숙련도 Lv.%d · %d / %d XP\n%d전 %d승 %d패 %d무 · 이 기기 기록" % [
		stats["level"], stats["within"], BotProgress.LEVEL_XP,
		stats["played"], stats["wins"], stats["losses"], stats["draws"]]
	_progress.visible = true
	_progress_bar.value = stats["within"]
	_progress_bar.visible = true
	_challenge.text = CharacterChallenges.next_text(stats)
	_challenge.visible = true


func enable_navigation() -> void:
	_navigation.visible = true


func _navigation_button(caption: String, direction: int) -> UiMenuButton:
	var button := UiMenuButton.new()
	button.text = caption
	button.kind = UiMenuButton.Kind.SECONDARY
	button.tooltip_text = "이전 캐릭터 선택" if direction < 0 else "다음 캐릭터 선택"
	button.ready.connect(func() -> void:
		button.custom_minimum_size = Vector2(0, DS.S8)
		button.add_theme_font_size_override("font_size", DS.SIZE_CAPTION))
	_navigation.add_child(button)
	button.pressed.connect(func() -> void: character_step.emit(direction))
	return button


func next_button() -> UiMenuButton:
	return _next


func previous_button() -> UiMenuButton:
	return _previous


func character() -> String:
	return _character


func progress_text() -> String:
	return _progress.text


func challenge_text() -> String:
	return _challenge.text
