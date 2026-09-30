class_name EmailLoginView
extends VBoxContainer
## Email mode of the login card (design.md DS-CMP-14, platform B6): step email — a TextField
## (DS-CMP-17) and "인증코드 받기" — then step code — a CodeInput (DS-CMP-18), "로그인" and
## "코드 다시 받기" with the resend cooldown — plus one status line and "← 다른 방법으로". Enter
## submits the step; Esc steps back (code → email → the other methods). Shows only what it is
## given: the login screen sends the requests and reports the results.

signal code_requested(email: String)
signal code_submitted(email: String, code: String)
signal resend_requested(email: String)
signal back_requested

enum Step { EMAIL, CODE }

const FIELD_SCENE := preload("res://src/ui/components/text_field/text_field.tscn")
const CODE_SCENE := preload("res://src/ui/components/code_input/code_input.tscn")
const ORDER: Array[String] = ["title", "helper", "field", "code", "submit", "message", "resend", "back"]

var _step: int = Step.EMAIL
var _lang: String = LoginText.KO
var _busy: bool = false
var _cooldown_s: int = 0
var _p: Dictionary = {}


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", DS.S4)
	_p = _build()
	for key: String in ORDER:
		add_child(_p[key] as Control)
	email_field().text_submitted.connect(func(_t: String) -> void: submit())
	code_input().submitted.connect(func(_c: String) -> void: submit())
	submit_button().pressed.connect(submit)
	resend_button().pressed.connect(func() -> void:
		if not _busy and _cooldown_s == 0:
			resend_requested.emit(email()))
	back_button().pressed.connect(func() -> void: back_requested.emit())
	show_step(Step.EMAIL)


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()


func show_step(s: int) -> void:
	_step = s
	email_field().visible = s == Step.EMAIL
	code_input().visible = s == Step.CODE
	resend_button().visible = s == Step.CODE
	if s == Step.CODE and code_input().is_node_ready():
		code_input().clear()
	set_message("", false)
	_apply_texts()
	focus_current()


func step() -> int:
	return _step


func set_language(lang: String) -> void:
	_lang = lang
	_apply_texts()


## While a request is out: the submit pill says so and nothing is sent twice.
func set_busy(on: bool) -> void:
	_busy = on
	_apply_texts()


## One status line; an error also rings the current input until the player types.
func set_message(text: String, error: bool) -> void:
	var line := _p["message"] as Label
	line.text = text
	line.visible = not text.is_empty()
	if not error:
		return
	if _step == Step.EMAIL:
		email_field().set_state(UiTextField.State.ERROR)
	else:
		code_input().set_state(CodeInput.State.ERROR)


## Seconds before "코드 다시 받기" works again (0 = now).
func set_cooldown(seconds: int) -> void:
	if seconds == _cooldown_s:
		return
	_cooldown_s = seconds
	_apply_resend()


func submit() -> void:
	if _busy:
		return
	if _step == Step.EMAIL:
		code_requested.emit(email())
	else:
		code_submitted.emit(email(), code())


func go_back() -> void:
	if _step == Step.CODE:
		show_step(Step.EMAIL)
	else:
		back_requested.emit()


func focus_current() -> void:
	if not is_visible_in_tree():
		return
	if _step == Step.EMAIL:
		email_field().grab_focus()
	else:
		code_input().grab_input_focus()


func email() -> String:
	return email_field().text.strip_edges()


func code() -> String:
	return code_input().code()


func email_field() -> UiTextField:
	return _p["field"] as UiTextField


func code_input() -> CodeInput:
	return _p["code"] as CodeInput


func submit_button() -> UiMenuButton:
	return _p["submit"] as UiMenuButton


func resend_button() -> LinkButton:
	return _p["resend"] as LinkButton


func back_button() -> LinkButton:
	return _p["back"] as LinkButton


func helper_text() -> String:
	return (_p["helper"] as Label).text


func message_text() -> String:
	return (_p["message"] as Label).text


static func _build() -> Dictionary:
	var title := LoginLayout.caption(false)
	title.add_theme_font_size_override("font_size", DS.SIZE_BODY)
	var field := FIELD_SCENE.instantiate() as UiTextField
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	field.custom_minimum_size.x = DS.BUTTON_MIN_WIDTH
	field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var code_box := CODE_SCENE.instantiate() as CodeInput
	code_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var submit_pill := UiMenuButton.new()
	submit_pill.kind = UiMenuButton.Kind.SECONDARY
	submit_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return {
		"title": title, "helper": LoginLayout.caption(false), "field": field, "code": code_box,
		"submit": submit_pill, "message": LoginLayout.caption(false), "resend": LoginLayout.link(),
		"back": LoginLayout.link(),
	}


func _t(key: String) -> String:
	return LoginText.of(_lang, key)


func _apply_texts() -> void:
	(_p["title"] as Label).text = _t("email_title")
	(_p["helper"] as Label).text = _t("email_helper") if _step == Step.EMAIL else _t("code_helper") % email()
	email_field().placeholder_text = _t("email_placeholder")
	var idle_key := "email_send" if _step == Step.EMAIL else "code_submit"
	var busy_key := "email_sending" if _step == Step.EMAIL else "code_checking"
	var pill := submit_button()
	pill.text = _t(busy_key if _busy else idle_key)
	var ready_state := UiMenuButton.State.FOCUS if pill.has_focus() else UiMenuButton.State.IDLE
	pill.set_state(UiMenuButton.State.DISABLED if _busy else ready_state)
	back_button().text = _t("back")
	_apply_resend()


func _apply_resend() -> void:
	var b := resend_button()
	b.text = _t("resend_wait") % _cooldown_s if _cooldown_s > 0 else _t("resend")
	b.disabled = _busy or _cooldown_s > 0
