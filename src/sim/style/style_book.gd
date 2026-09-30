class_name StyleBook
extends RefCounted
## Every fighter's kit for one tick, indexed by fighter id: its style's movement numbers now, and
## on first use this tick its attack table (the style's reshaped classic table whose SPECIAL entry
## is the character's special). Built every tick by WorldStep, so debug-panel tuning applies at
## once; attack tables are built lazily and shared by fighters with the same style / character,
## so a tick where nobody attacks builds none (keeps the 4-bot tick cost low).


class Kit:
	extends RefCounted
	var character: String = CharacterData.DEFAULT
	## Movement numbers (StyleData.attacks is null here; use StyleBook.attacks).
	var style: StyleData
	## SpecialCatalog id, or "" when the character has none.
	var special: String = ""


var _config: GameConfig
var _kits: Array[Kit] = []
var _base: AttackSet = null
var _style_sets := {}
var _character_sets := {}


static func build(fighters: Array[Fighter], config: GameConfig) -> StyleBook:
	var book := StyleBook.new()
	book._config = config
	var by_character := {}
	for f: Fighter in fighters:
		if not by_character.has(f.character):
			var k := Kit.new()
			k.character = f.character
			k.style = StyleCatalog.moves(CharacterData.style_of(f.character), config)
			k.special = CharacterData.special_of(f.character)
			by_character[f.character] = k
		book._kits.append(by_character[f.character])
	return book


func kit(fighter_id: int) -> Kit:
	return _kits[fighter_id]


## This tick's classic table (AttackSet.from_config); items use its BAT, ROCK and BOMB entries.
func base_attacks() -> AttackSet:
	if _base == null:
		_base = AttackSet.from_config(_config)
	return _base


func attacks(fighter_id: int) -> AttackSet:
	var k := _kits[fighter_id]
	if not _character_sets.has(k.character):
		_character_sets[k.character] = _character_set(k)
	return _character_sets[k.character]


func _character_set(k: Kit) -> AttackSet:
	var style_id := k.style.id
	if not _style_sets.has(style_id):
		_style_sets[style_id] = StyleCatalog.attacks(style_id, _config, base_attacks())
	var s: AttackSet = _style_sets[style_id]
	if k.special.is_empty():
		return s
	return s.with_attacks({AttackSet.Kind.SPECIAL: SpecialCatalog.attack(k.special, _config)})
