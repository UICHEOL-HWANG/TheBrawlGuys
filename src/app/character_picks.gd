class_name CharacterPicks
extends RefCounted
## Bot characters for a match (Phase 5 T9): drawn from the match seed so the same seed and human
## picks always give the same bots, never a character a human took and never two bots alike —
## unless there are more bots than free characters, then the draw starts over.


## `count` CharacterData ids for the bot slots in slot order.
static func for_bots(match_seed: int, taken: Array[String], count: int) -> Array[String]:
	var free: Array[String] = []
	for id: String in CharacterData.IDS:
		if not taken.has(id):
			free.append(id)
	if free.is_empty():
		free = CharacterData.IDS.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed
	var out: Array[String] = []
	var bag: Array[String] = []
	for i: int in count:
		if bag.is_empty():
			bag = free.duplicate()
		out.append(bag.pop_at(rng.randi_range(0, bag.size() - 1)))
	return out
