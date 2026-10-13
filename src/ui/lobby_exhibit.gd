class_name LobbyExhibit
extends Control
## One occupied podium; rebuilds only when its character changes.

var _portrait: CharacterPortrait
var _id := ""
var _empty: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = DS.S8 + DS.S6 if WaitingRoomLayout.is_short(get_viewport()) else DS.CARD_THUMB_HEIGHT
	_empty = MenuShowcase.label("친구를 기다리는 중", DS.SIZE_CAPTION)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_empty)
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_slot(slot: Dictionary, config: GameConfig, live: bool) -> void:
	var occupied := int(slot["peer"]) != LobbyModel.EMPTY
	_empty.visible = not occupied
	var id := String(slot["character"]) if occupied else ""
	if id != _id:
		_id = id
		if _portrait != null:
			remove_child(_portrait)
			_portrait.queue_free()
			_portrait = null
		if occupied:
			_portrait = CharacterPortrait.new()
			_portrait.custom_minimum_size = Vector2.ZERO
			add_child(_portrait)
			_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_portrait.setup(CharacterCards.entry(id)["model"], config)
	if _portrait != null:
		_portrait.set_live(live)


func set_preview() -> void:
	if not is_node_ready():
		await ready
	show_slot({"peer": 1, "character": "knight"}, GameConfig.new(), true)
