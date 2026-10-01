class_name RoomCode
extends RefCounted
## Online room codes (Phase 6, PRD-NET-03): 6 characters from A-Z and 2-9 without the look-alikes
## I, O, 0 and 1, so a code read aloud or off a phone is typed right. The rooms table checks the
## same pattern (migration 0005).

const LENGTH := 6
const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


## A fresh random code; pass an rng to make it reproducible (tests).
static func generate(rng: RandomNumberGenerator = null) -> String:
	var r := rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.randomize()
	var out := ""
	for i: int in LENGTH:
		out += ALPHABET[r.randi_range(0, ALPHABET.length() - 1)]
	return out


## Upper-cased, anything outside the alphabet dropped (look-alikes are not guessed), at most
## LENGTH characters.
static func normalize(text: String) -> String:
	var out := ""
	for ch: String in text.to_upper():
		if out.length() >= LENGTH:
			break
		if ALPHABET.contains(ch):
			out += ch
	return out


static func is_valid(code: String) -> bool:
	return code.length() == LENGTH and normalize(code) == code
