class_name LoginPanel
extends Control
## First-screen Google sign-in (design.md DS-CMP-14, 🖼 draft): logo, tagline, the Google
## MenuButton, a one-line message and a debug-only skip. States idle · loading (waiting for the
## browser) · error (one-line cause + retry). Three layouts / entrances are candidates for the
## 🖼 gate, picked by `variant` (default ① until the user decides). Shows only what it is given.

signal google_pressed
signal skip_pressed

enum State { IDLE, LOADING, ERROR }
enum Variant { CARD = LoginLayout.CARD, SIDE = LoginLayout.SIDE, LOGO_DROP = LoginLayout.LOGO_DROP }

const TITLE_TEXT := "The Brawl Guys"
const TAGLINE_TEXT := "치고, 날리고, 끝까지 버티기"
const GOOGLE_TEXT := "Google로 계속하기"
const RETRY_TEXT := "다시 시도"
const LOADING_TEXT := "로그인 중…"
const SKIP_TEXT := "건너뛰기 (디버그)"
const PREVIEW_SIZE := Vector2(960, 540)

@export var variant: Variant = Variant.CARD

var _state: int = State.IDLE
var _layout: Dictionary = {}
var _logo: Label
var _tagline: Label
var _google: UiMenuButton
var _message: Label
var _skip: UiMenuButton
var _google_enabled: bool = true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func set_variant(v: Variant) -> void:
	variant = v
	if is_node_ready():
		_build()


func set_state(s: int, message: String = "") -> void:
	_state = s
	_message.text = message
	_message.visible = not message.is_empty()
	_google.text = RETRY_TEXT if s == State.ERROR else (LOADING_TEXT if s == State.LOADING else GOOGLE_TEXT)
	var usable := _google_enabled and s != State.LOADING
	_google.set_state(UiMenuButton.State.IDLE if usable else UiMenuButton.State.DISABLED)


## Unavailable sign-in (mobile, missing keys): the button stays disabled in every state.
func set_google_enabled(enabled: bool) -> void:
	_google_enabled = enabled
	set_state(_state, _message.text)


func set_skip_visible(on: bool) -> void:
	_skip.visible = on


func play_entrance() -> Tween:
	return LoginEntrance.play(variant, _layout, self)


func entrance_duration() -> float:
	return LoginEntrance.duration(variant, (_layout["items"] as Array).size())


func state() -> int:
	return _state


func message_text() -> String:
	return _message.text


func google_button() -> UiMenuButton:
	return _google


func skip_button() -> UiMenuButton:
	return _skip


func logo() -> Label:
	return _logo


func set_preview() -> void:
	custom_minimum_size = PREVIEW_SIZE


func _build() -> void:
	if not _layout.is_empty():
		var old := _layout["root"] as Node
		remove_child(old)
		old.queue_free()
	_logo = _label(TITLE_TEXT)
	_tagline = _label(TAGLINE_TEXT)
	_message = _label("")
	_google = _button(GOOGLE_TEXT, UiMenuButton.Kind.PRIMARY, google_pressed)
	_skip = _button(SKIP_TEXT, UiMenuButton.Kind.SECONDARY, skip_pressed)
	_skip.visible = false
	_layout = LoginLayout.build(variant, {"logo": _logo, "tagline": _tagline, "google": _google,
		"message": _message, "skip": _skip})
	add_child(_layout["root"] as Node)
	set_state(_state, "")


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _button(text: String, kind: UiMenuButton.Kind, sig: Signal) -> UiMenuButton:
	var b := UiMenuButton.new()
	b.kind = kind
	b.text = text
	b.pressed.connect(func() -> void: sig.emit())
	return b
