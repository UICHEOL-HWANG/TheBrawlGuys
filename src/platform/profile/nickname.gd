class_name Nickname
extends RefCounted
## The name a player goes by (onboarding, design.md DS-LAY-03): trimmed with every kind of inner
## space collapsed to one, MIN_LEN..MAX_LEN characters, no control, invisible or text-direction
## characters (they could hide a name or flip how others see it). error() gives the reason.

const MIN_LEN := 2
const MAX_LEN := 12
const TOO_SHORT := "2자 이상 입력해 주세요"
const TOO_LONG := "12자까지 쓸 수 있어요"
const BAD_CHAR := "쓸 수 없는 문자가 있어요"
## Tab, line feed, carriage return, no-break and ideographic space: spaces to clean(), not refused.
const SPACES: Array[int] = [9, 10, 13, 0x00A0, 0x3000]
## Refused ranges [from, to]: C0/C1 controls, zero-width and direction marks/overrides, line and
## paragraph separators, invisible operators and isolates, the byte-order mark.
const REFUSED: Array[Array] = [[0x00, 0x1F], [0x7F, 0x9F], [0x200B, 0x200F], [0x2028, 0x202E],
	[0x2060, 0x2069], [0xFEFF, 0xFEFF]]


## Trimmed, with every run of whitespace inside turned into one space.
static func clean(text: String) -> String:
	var spaced := text
	for code: int in SPACES:
		spaced = spaced.replace(char(code), " ")
	var words := PackedStringArray()
	for w: String in spaced.strip_edges().split(" ", false):
		var t := w.strip_edges()
		if not t.is_empty():
			words.append(t)
	return " ".join(words)


## "" when text (cleaned) is a usable nickname, else why not.
static func error(text: String) -> String:
	for i: int in text.length():  # before cleaning: trimming would hide a trailing one
		if _refused(text.unicode_at(i)):
			return BAD_CHAR
	var t := clean(text)
	if t.length() < MIN_LEN:
		return TOO_SHORT
	if t.length() > MAX_LEN:
		return TOO_LONG
	return ""


static func is_valid(text: String) -> bool:
	return error(text).is_empty()


## A starting value from an account display name (OAuth full name): cleaned and cut to MAX_LEN;
## "" when it would not be valid.
static func prefill(display_name: String) -> String:
	var t := clean(clean(display_name).left(MAX_LEN))
	return t if is_valid(t) else ""


static func _refused(code: int) -> bool:
	if SPACES.has(code):
		return false
	for r: Array in REFUSED:
		if code >= int(r[0]) and code <= int(r[1]):
			return true
	return false
