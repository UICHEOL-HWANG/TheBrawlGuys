class_name ItemModels
extends RefCounted
## Registry of the procedural item models (Phase 4 T8): maps an Item.Kind to its model file.


static func create(kind: int) -> ItemModel:
	match kind:
		Item.Kind.BAT:
			return BatModel.new()
		Item.Kind.BOMB:
			return BombModel.new()
		Item.Kind.ROCK:
			return RockModel.new()
		Item.Kind.HAMMER:
			return HammerModel.new()
		Item.Kind.GLOVE:
			return GloveModel.new()
		Item.Kind.BANANA:
			return BananaModel.new()
	push_error("ItemModels.create: unknown item kind %d" % kind)
	return RockModel.new()


static func crate() -> CrateModel:
	return CrateModel.new()


## The model's pose relative to a hand slot.
static func hold_transform(kind: int) -> Transform3D:
	match kind:
		Item.Kind.BAT:
			return BatModel.HOLD
		Item.Kind.BOMB:
			return BombModel.HOLD
		Item.Kind.HAMMER:
			return HammerModel.HOLD
		Item.Kind.GLOVE:
			return GloveModel.HOLD
		Item.Kind.BANANA:
			return BananaModel.HOLD
	return RockModel.HOLD
