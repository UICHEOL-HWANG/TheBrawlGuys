class_name CharacterSelectView
extends RefCounted
## What the character select draws (Phase 5 T9): one SelectCard per character with its portrait
## (CharacterCards, CharacterPortrait) and one PlayerSlot per match slot, refreshed from the
## CharacterSelectModel. A card shows the markers of the players whose cursor is on it; it is
## focused while someone browses it and selected — ring in that player's color — once someone
## locks it. Human slots show choosing / ready, the browsed character and their prompts; bot
## slots are ready with "자동 선택" (their characters are drawn when the humans are done).

const CARD_SCENE := preload("res://src/ui/components/select_card/select_card.tscn")
const SLOT_SCENE := preload("res://src/ui/components/player_slot/player_slot.tscn")
const BOT_CHARACTER_TEXT := "자동 선택"
## A bot slot's second line while the humans' slots show prompts (no empty band under its header).
const BOT_NOTE := "시작할 때 캐릭터를 골라요"

var cards: Array[SelectCard] = []
var portraits: Array[CharacterPortrait] = []
var slots: Array[PlayerSlot] = []
var ids: Array[String] = []


func build_cards(config: GameConfig, compact: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", DS.S5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for e: Dictionary in CharacterCards.entries():
		var card := CARD_SCENE.instantiate() as SelectCard
		card.follow_focus = false
		row.add_child(card)
		var portrait := CharacterPortrait.new()
		card.set_thumb(portrait)
		portrait.setup(e["model"], config)
		cards.append(card)
		portraits.append(portrait)
		ids.append(String(e["id"]))
	set_compact(compact)
	return row


## Phones (compact): shorter head-and-chest portraits and one-line captions.
func set_compact(compact: bool) -> void:
	for i: int in cards.size():
		var e := CharacterCards.entry(ids[i])
		cards[i].setup(String(e["title"]), CharacterSelectLayout.caption(e, compact), {}, [])
		portraits[i].custom_minimum_size.y = CharacterSelectLayout.thumb_height(compact)
		portraits[i].set_close_up(compact)


func build_slots(setup: MatchSetup) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", DS.S5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s: Dictionary in setup.slots:
		var slot := SLOT_SCENE.instantiate() as PlayerSlot
		row.add_child(slot)
		slot.setup(int(s["slot"]))
		slot.set_bot(s["controller"] == MatchSetup.CONTROLLER_BOT)
		slots.append(slot)
	return row


## prompts_for(seat) -> SelectPrompts rows of that human's current device.
func refresh(model: CharacterSelectModel, prompts_for: Callable) -> void:
	for i: int in cards.size():
		_refresh_card(i, model)
	var bots: Array[PlayerSlot] = []
	var prompted := false
	for i: int in slots.size():
		var seat := model.seat_of_slot(i)
		if seat < 0:
			slots[i].set_character(BOT_CHARACTER_TEXT)
			slots[i].set_state(PlayerSlot.State.READY)
			bots.append(slots[i])
			continue
		var ready := model.state(seat) == CharacterSelectModel.READY
		slots[i].set_state(PlayerSlot.State.READY if ready else PlayerSlot.State.CHOOSING)
		slots[i].set_character(CharacterCards.title_of(ids[model.focus(seat)]))
		slots[i].set_prompts(prompts_for.call(seat))
		prompted = prompted or slots[i].prompt_row().visible
	for b: PlayerSlot in bots:
		b.set_note(BOT_NOTE if prompted else "")  # touch players have no prompt line, nor do bots


func _refresh_card(i: int, model: CharacterSelectModel) -> void:
	var players: Array[int] = []
	var ring := -1
	for seat: int in model.seats_on(i):
		players.append(model.slot_of(seat))
		if ring < 0 and model.state(seat) == CharacterSelectModel.READY:
			ring = model.slot_of(seat)
	cards[i].set_marks(players)
	cards[i].ring_color = PlayerStyle.color(ring) if ring >= 0 else DS.UI_ACCENT
	if ring >= 0:
		cards[i].set_state(SelectCard.State.SELECTED)
	else:
		cards[i].set_state(SelectCard.State.FOCUS if not players.is_empty() else SelectCard.State.IDLE)
	portraits[i].set_live(not players.is_empty())
