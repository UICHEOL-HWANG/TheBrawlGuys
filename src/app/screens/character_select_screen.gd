class_name CharacterSelectScreen
extends Control
## Character select (Phase 5 T9, PRD-UI-02, PRD-LOCAL-01, DS-CMP-08/10, DS-TOK-06): 모드 → 캐릭터
## → 경기장 → 대전. Four SelectCards and a PlayerSlot per match slot over the menu backdrop. Each
## human browses with an own cursor (CharacterSelectInput: keys, pads; mouse / touch drive P1)
## and confirms to lock in; cancel unlocks, and P1's cancel while choosing (or 뒤로) goes back.
## When every human is ready the setup gets their characters plus seed-drawn bot characters and
## character_selected is tracked per slot (CharacterSelectTracking). Shown again after a later
## step backed out, everyone chooses again. Prompts follow each human's device (SeatDevices).

signal characters_chosen
signal cancelled

const SCREEN := "character"
const TITLE_TEXT := "캐릭터 선택"
const BACK_TEXT := "뒤로"
const TOUCH_HINT := "카드를 눌러 고르세요"
const TWO_PLAYER_HINT := "둘 다 확정하면 시작해요 · 취소하면 다시 골라요"
const BACKDROP_FOCUS := Vector2(0.0, 0.42)

var track: Callable = func(event_name: String, props: Dictionary) -> void: Analytics.track(event_name, props)
var clock_ms: Callable = Time.get_ticks_msec
## The app's GameConfig (portraits fit models to it); null loads the default config.
var config: GameConfig = null
## The setup this screen fills (MatchSetup.vs_bots / local_versus); null = 1 vs 1 bot.
var setup: MatchSetup = null

var _model: CharacterSelectModel
var _router: CharacterSelectInput
var _devices: SeatDevices
var _view := CharacterSelectView.new()
var _shown_ms: int = 0
var _done: bool = false
var _back: UiMenuButton
var _hint: Label
var _parts: Dictionary = {}
var _compact := false
## Characters of the last line-up tracked (character_selected is sent once per line-up).
var _tracked: Array[String] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if setup == null:
		setup = MatchSetup.vs_bots()
	var humans := setup.local_slots()
	_model = CharacterSelectModel.new(humans, CharacterCards.ORDER.size())
	_devices = SeatDevices.new(humans.size())
	_router = CharacterSelectInput.new(humans.size() > 1, _devices.pad_seat)
	_shown_ms = int(clock_ms.call())
	_back = ArenaSelectLayout.back_button(BACK_TEXT)
	_back.pressed.connect(back)
	_hint = ArenaSelectLayout.hint_label("")
	var cfg := config if config != null else load(MenuBackdrop.CONFIG_PATH) as GameConfig
	_compact = CharacterSelectLayout.is_compact(get_viewport())
	var cards := _view.build_cards(cfg, _compact)
	_parts = CharacterSelectLayout.build(self, TITLE_TEXT, cards, _view.build_slots(setup), _back, _hint,
			_compact)
	for i: int in _view.cards.size():
		_view.cards[i].hovered.connect(_point.bind(i))
		_view.cards[i].pressed.connect(_click.bind(i))
	_on_resized()
	get_viewport().size_changed.connect(_on_resized)
	visibility_changed.connect(_on_visibility_changed)
	_devices.attach()
	_refresh()


func _exit_tree() -> void:
	_devices.detach()


func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	var r := _router.route(event)
	if r.is_empty():
		return
	var seat := int(r["seat"])
	var device := String(r["device"])
	match String(r["cmd"]):
		CharacterSelectInput.MOVE:
			_devices.note(seat, device, event.device if device == SelectPrompts.DEVICE_GAMEPAD else -1)
			_model.move(seat, int(r["step"]))
			_refresh()
		CharacterSelectInput.CONFIRM:
			confirm(seat, device)
		CharacterSelectInput.CANCEL:
			cancel(seat)
	get_viewport().set_input_as_handled()


## A seat locks its card; the last one to lock starts the next step.
func confirm(seat: int, device: String) -> void:
	if _done:
		return
	var result := _model.confirm(seat)
	if result == CharacterSelectModel.NONE:
		return
	_devices.note(seat, device)
	_refresh()
	if result == CharacterSelectModel.ALL_READY:
		_finish()


## Ready: unlock. P1 still choosing: leave the screen.
func cancel(seat: int) -> void:
	if _done:
		return
	if _model.cancel(seat) == CharacterSelectModel.BACK:
		back()
	else:
		_refresh()


func back() -> void:
	if _done:
		return
	_done = true
	track.call("select_cancelled", {"screen": SCREEN, "dwell_ms": int(clock_ms.call()) - _shown_ms})
	cancelled.emit()


func model() -> CharacterSelectModel:
	return _model


func view() -> CharacterSelectView:
	return _view


func devices() -> SeatDevices:
	return _devices


func back_button() -> UiMenuButton:
	return _back


func backdrop_focus() -> Vector2:
	return BACKDROP_FOCUS


func _finish() -> void:
	_done = true
	var picks := {}
	var model_picks := _model.picks()
	for slot: int in model_picks:
		picks[slot] = _view.ids[int(model_picks[slot])]
	setup.assign_characters(picks)
	if not CharacterSelectTracking.same_as(_tracked, setup.characters()):
		_tracked = setup.characters()
		for p: Dictionary in CharacterSelectTracking.props(setup, _model, _devices):
			track.call("character_selected", p)
	characters_chosen.emit()


## Mouse and touch drive P1: hover browses, a click or tap confirms that card.
func _point(i: int) -> void:
	if not _done and _model.point(0, i):
		_refresh()


func _click(i: int) -> void:
	if _done:
		return
	_model.point(0, i)
	confirm(0, SeatDevices.pointer_device())


func _refresh() -> void:
	_view.refresh(_model, _devices.prompts)
	var touch := _devices.device_of(0) == SelectPrompts.DEVICE_TOUCH
	_hint.text = TOUCH_HINT if touch else (TWO_PLAYER_HINT if _model.seat_count() > 1 else "")


## Hidden: the match will assign pads itself. Shown again after a pick: a fresh visit.
func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_devices.detach()
		return
	_devices.attach()
	if _done:
		_done = false
		_model.reopen()
		_router.reset_sticks()
		_shown_ms = int(clock_ms.call())
	_refresh()


## Safe area on every resize; a phone turning (or a window crossing the compact height) switches
## the portraits, captions and gaps.
func _on_resized() -> void:
	CharacterSelectLayout.apply_safe_area(_parts, get_viewport())
	var compact := CharacterSelectLayout.is_compact(get_viewport())
	if compact != _compact:
		_compact = compact
		_view.set_compact(compact)
		CharacterSelectLayout.set_compact(_parts, compact)
