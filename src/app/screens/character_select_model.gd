class_name CharacterSelectModel
extends RefCounted
## Character select rules (Phase 5 T9, PRD-LOCAL-01) for one or two humans at this machine: each
## seat (a human, in slot order) moves its own cursor over the cards, confirms to lock it (ready)
## and cancels to unlock it; P1's cancel while still choosing leaves the screen. The flow goes on
## once every seat is ready. Two seats may pick the same card (mirror match). Pure data.

## Results of confirm / cancel.
const NONE := ""
const READY := "ready"
const ALL_READY := "all_ready"
const UNREADY := "unready"
const BACK := "back"
## Seat states.
const CHOOSING := "choosing"

var _slots: Array[int] = []
var _cards: int = 0
## Per seat: {focus: int, state: String, browse: int}
var _seats: Array[Dictionary] = []


## slots: the humans' MatchSetup slots in order (P1 first). Seat i starts on card i so two
## players never begin on the same card.
func _init(human_slots: Array[int], card_count: int) -> void:
	_slots = human_slots.duplicate()
	_cards = maxi(card_count, 1)
	for i: int in _slots.size():
		_seats.append({"focus": i % _cards, "state": CHOOSING, "browse": 0})


func seat_count() -> int:
	return _seats.size()


func slot_of(seat: int) -> int:
	return _slots[seat] if _valid(seat) else -1


func seat_of_slot(slot: int) -> int:
	return _slots.find(slot)


func focus(seat: int) -> int:
	return int(_seats[seat]["focus"]) if _valid(seat) else -1


func state(seat: int) -> String:
	return String(_seats[seat]["state"]) if _valid(seat) else NONE


func browse(seat: int) -> int:
	return int(_seats[seat]["browse"]) if _valid(seat) else 0


func all_ready() -> bool:
	for s: Dictionary in _seats:
		if s["state"] != READY:
			return false
	return not _seats.is_empty()


## Moves a choosing seat's cursor one card left (-1) or right (+1), wrapping. False if it cannot.
func move(seat: int, step: int) -> bool:
	if not _choosing(seat) or step == 0:
		return false
	return point(seat, wrapi(focus(seat) + step, 0, _cards))


## Puts a choosing seat's cursor on card `index` (hover, tap). False when nothing changed.
func point(seat: int, index: int) -> bool:
	if not _choosing(seat) or index < 0 or index >= _cards or index == focus(seat):
		return false
	_seats[seat] = _seats[seat].merged({"focus": index, "browse": browse(seat) + 1}, true)
	return true


func confirm(seat: int) -> String:
	if not _choosing(seat):
		return NONE
	_seats[seat] = _seats[seat].merged({"state": READY}, true)
	return ALL_READY if all_ready() else READY


## Ready: unlock. Choosing: P1 (seat 0) leaves the screen; other seats' cancel does nothing, so
## a stray P2 key never throws away P1's pick (P2 leaves with 뒤로 like everyone).
func cancel(seat: int) -> String:
	if not _valid(seat):
		return NONE
	if state(seat) == READY:
		_seats[seat] = _seats[seat].merged({"state": CHOOSING}, true)
		return UNREADY
	return BACK if seat == 0 else NONE


## Seats whose cursor is on card `index`, in seat order.
func seats_on(index: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in _seats.size():
		if focus(i) == index:
			out.append(i)
	return out


## slot -> card index of every seat (read once all are ready).
func picks() -> Dictionary:
	var out := {}
	for i: int in _seats.size():
		out[_slots[i]] = focus(i)
	return out


## The screen is shown again (a later step backed out): everyone chooses again from where they were.
func reopen() -> void:
	for i: int in _seats.size():
		_seats[i] = _seats[i].merged({"state": CHOOSING, "browse": 0}, true)


func _valid(seat: int) -> bool:
	return seat >= 0 and seat < _seats.size()


func _choosing(seat: int) -> bool:
	return _valid(seat) and state(seat) == CHOOSING
