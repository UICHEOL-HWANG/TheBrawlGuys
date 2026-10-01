class_name LoginPanel
extends Control
## First-screen Google sign-in (design.md DS-CMP-14, decided 2026-09-30; reference
## docs/references/ref-login-calmforest.webp): a frosted glass card centered over the hazy menu
## diorama with the crest (DS-CMP-15), title, tagline, "Google로 시작하기", the ghost "이메일로
## 계속하기", a helper line, the language link and a debug-only skip link. States idle · loading
## (waiting for the browser) · error (one-line cause + retry) live inside the card. The email
## button swaps the card content for the EmailLoginView (mode email) and back. Shows only what it is given.

signal google_pressed
signal skip_pressed
signal language_changed(old_lang: String, new_lang: String)
signal email_code_requested(email: String)
signal email_code_submitted(email: String, code: String)
signal email_resend_requested(email: String)

enum State { IDLE, LOADING, ERROR }
enum Mode { METHODS, EMAIL }

const PREVIEW_SIZE := Vector2(1280, 720)
## Below this layout height (phones in landscape, DS-LAY-04) the crest is left out so the card fits.
const CREST_MIN_HEIGHT := 800.0

var _state: int = State.IDLE
var _mode: int = Mode.METHODS
var _layout: Dictionary = {}
var _parts: Dictionary = {}
var _lang: String = LoginText.KO
var _google_enabled: bool = true
var _email_enabled: bool = true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backbuffer := BackBufferCopy.new()  # the glass blurs the hazed scene, not the raw one
	backbuffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(backbuffer)
	_layout = LoginLayout.build()
	_parts = _layout["parts"]
	add_child(_layout["root"] as Node)
	google_button().pressed.connect(func() -> void: google_pressed.emit())
	skip_button().pressed.connect(func() -> void: skip_pressed.emit())
	(_parts["language_link"] as LinkButton).pressed.connect(toggle_language)
	_connect_email()
	skip_button().visible = false
	crest().set_state(CrestLogo.State.ANIMATED)
	_apply_texts()
	resized.connect(_fit_height)
	_fit_height()


func set_state(s: int, message: String = "") -> void:
	_state = s
	var line := _parts["message"] as Label
	line.text = message
	line.visible = not message.is_empty()
	_apply_google()


## Unavailable sign-in (mobile, missing keys): the button stays disabled in every state.
func set_google_enabled(enabled: bool) -> void:
	_google_enabled = enabled
	_apply_google()


## Email sign-in needs the Supabase keys, nothing else (it works on mobile too).
func set_email_enabled(enabled: bool) -> void:
	_email_enabled = enabled
	_apply_google()


## Swaps the methods for the email step, inside the same card.
func show_email() -> void:
	if _mode != Mode.EMAIL:
		_mode = Mode.EMAIL
		email_view().show_step(EmailLoginView.Step.EMAIL)
		_swap(_parts["methods"] as Control, email_view())
		email_view().focus_current.call_deferred()


func show_methods() -> void:
	if _mode != Mode.METHODS:
		_mode = Mode.METHODS
		_swap(email_view(), _parts["methods"] as Control)
		(google_button() if not google_button().disabled else email_button()).grab_focus.call_deferred()


func mode() -> int:
	return _mode


func set_skip_visible(on: bool) -> void:
	skip_button().visible = on


func language() -> String:
	return _lang


func set_language(lang: String) -> void:
	_lang = lang
	_apply_texts()


func toggle_language() -> void:
	var old := _lang
	set_language(LoginText.other(old))
	language_changed.emit(old, _lang)


func play_entrance() -> Tween:
	return LoginEntrance.play(_layout, self)


func entrance_duration() -> float:
	return LoginEntrance.duration((_layout["items"] as Array).size())


## Screen point (NDC, x right / y up) left free for the menu backdrop's fight.
func backdrop_focus() -> Vector2:
	return _layout["focus"]


func state() -> int:
	return _state


func message_text() -> String:
	return (_parts["message"] as Label).text


func google_button() -> UiMenuButton:
	return _parts["google"] as UiMenuButton


func email_button() -> UiMenuButton:
	return _parts["email"] as UiMenuButton


func email_view() -> EmailLoginView:
	return _parts["email_view"] as EmailLoginView


func skip_button() -> LinkButton:
	return _parts["skip"] as LinkButton


func language_button() -> LinkButton:
	return _parts["language_link"] as LinkButton


func logo() -> Label:
	return _parts["title"] as Label


func card() -> Control:
	return _layout["card"] as Control


func crest() -> CrestLogo:
	return _parts["emblem"] as CrestLogo


func set_preview() -> void:
	custom_minimum_size = PREVIEW_SIZE


func _fit_height() -> void:
	crest().visible = size.y <= 0.0 or size.y >= CREST_MIN_HEIGHT


func _apply_texts() -> void:
	(_parts["tagline"] as Label).text = LoginText.of(_lang, "tagline")
	(_parts["helper"] as Label).text = LoginText.of(_lang, "helper")
	language_button().text = LoginText.of(_lang, "language")
	skip_button().text = LoginText.of(_lang, "skip")
	email_button().text = LoginText.of(_lang, "email")
	email_view().set_language(_lang)
	_apply_google()


func _apply_google() -> void:
	var key := "retry" if _state == State.ERROR else ("loading" if _state == State.LOADING else "google")
	google_button().text = LoginText.of(_lang, key)
	var usable := _google_enabled and _state != State.LOADING
	google_button().set_state(UiMenuButton.State.IDLE if usable else UiMenuButton.State.DISABLED)
	google_button().queue_redraw()
	var email_usable := _email_enabled and _state != State.LOADING  # not while Google is out
	email_button().set_state(UiMenuButton.State.IDLE if email_usable else UiMenuButton.State.DISABLED)


func _connect_email() -> void:
	email_button().pressed.connect(show_email)
	var view := email_view()
	view.code_requested.connect(email_code_requested.emit)
	view.code_submitted.connect(email_code_submitted.emit)
	view.resend_requested.connect(email_resend_requested.emit)
	view.back_requested.connect(show_methods)


## Hide one, fade the other in (motion_base): the card stays, its content changes.
func _swap(from: Control, to: Control) -> void:
	from.visible = false
	to.visible = true
	if is_inside_tree():
		UiMotion.fade_in(to, UiMotion.Token.BASE)
