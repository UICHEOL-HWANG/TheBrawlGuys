class_name TutorialStaging
extends RefCounted
## Sets the practice arena up for each tutorial goal (Phase 5 T11) by editing the tutorial's own
## World between ticks, the way a test would: nobody runs out of stocks, no random item boxes,
## the dummy's damage resets every step, a bat drops in the middle while the item goals need one
## and the player's special gauge stays full for the special goal. No sim code changes (the sim
## stays pure and every replay hash stays as it is); tutorial matches are never recorded.

## Stocks far beyond any tutorial: ring-outs just respawn.
const STOCKS := 99
## Refill below this, so the HUD icons never run out either.
const STOCKS_LOW := 50
## Keeps the box spawner's next drop out of reach (ItemField waits for this tick).
const NO_SPAWN_TICK := 1 << 30
const ITEM_GOALS: Array[String] = [TutorialSteps.G_PICKUP, TutorialSteps.G_ITEM_USE]


static func begin(world: World) -> void:
	for f: Fighter in world.fighters:
		f.stocks = STOCKS
	world.items.next_spawn_tick = NO_SPAWN_TICK


## A new step: the dummy starts fresh (its knockback grows with damage).
static func enter(world: World, dummy_slot: int) -> void:
	var dummy := _fighter(world, dummy_slot)
	if dummy != null:
		dummy.damage = 0.0


## Every tick while a goal is on.
static func maintain(world: World, goal: String, slot: int, config: GameConfig) -> void:
	world.items.next_spawn_tick = NO_SPAWN_TICK
	for f: Fighter in world.fighters:
		if f.stocks < STOCKS_LOW:
			f.stocks = STOCKS
	var me := _fighter(world, slot)
	if me == null:
		return
	if ITEM_GOALS.has(goal) and world.items.items.is_empty() and me.item_kind == Fighter.NONE:
		drop_bat(world, config)
	if goal == TutorialSteps.G_SPECIAL and me.state != Fighter.State.SPECIAL:
		me.gauge = SpecialGauge.MAX


## A bat falling into the middle of the arena.
static func drop_bat(world: World, config: GameConfig) -> Item:
	var area := world.arena.item_area
	var at := area.sample_point(0.5, 0.0, 0.0, config.item_drop_height) if area != null \
			else Vector3.UP * config.item_drop_height
	return world.items.add(Item.Kind.BAT, at, Item.State.FALLING, config)


static func _fighter(world: World, slot: int) -> Fighter:
	for f: Fighter in world.fighters:
		if f.id == slot:
			return f
	return null
