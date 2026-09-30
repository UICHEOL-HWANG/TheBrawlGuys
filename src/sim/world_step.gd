class_name WorldStep
extends RefCounted
## One World tick's step order (split out of World). StyleBook.build -> PressBuffer.apply ->
## GuardMeter.track_presses -> ItemActions.pre_step -> SpecialRunner.try_start -> Motion.step per
## fighter -> separate -> Dodge.started_events -> ProjectileMotion.fire -> SpecialRunner.advance -> Grab.step -> Grab.resolve ->
## SpecialRunner.contacts -> Combat.resolve -> SpecialRunner.apply -> ProjectileMotion.step -> ItemMotion.step -> GimmickRunner.step ->
## ItemField.spawn_step -> GuardMeter.step -> SpecialGauge.apply -> Rules.apply -> Grab.cleanup ->
## ItemActions.drop_from_disabled. Fire/advance only see fighters that advanced (not frozen).


## Runs every step on w with the per-fighter input copies; returns the tick's events.
static func run(w: World, frame: Array[InputFrame], rng: RandomNumberGenerator) -> Array[Dictionary]:
	var c := w.config
	w.arena.sync(c)
	var book := StyleBook.build(w.fighters, c)
	var events: Array[Dictionary] = []
	PressBuffer.apply(w.fighters, frame)
	GuardMeter.track_presses(w.fighters, frame)
	events.append_array(ItemActions.pre_step(w.fighters, frame, w.items, c))
	events.append_array(SpecialRunner.try_start(w.fighters, frame, book, c))
	var advanced: Array[Fighter] = []
	for f: Fighter in w.fighters:
		if Motion.step(f, frame[f.id], c, book, w.arena):
			advanced.append(f)
	Motion.separate(w.fighters, c)
	events.append_array(Dodge.started_events(advanced))
	events.append_array(ProjectileMotion.fire(advanced, book, w.projectiles, c))
	events.append_array(SpecialRunner.advance(advanced, book, w.projectiles, c))
	events.append_array(Grab.step(w.fighters, frame, book, c))
	events.append_array(Grab.resolve(w.fighters, book, c))
	var special_contacts := SpecialRunner.contacts(w.fighters, book, c)
	events.append_array(Combat.resolve(w.fighters, book, c))
	events.append_array(SpecialRunner.apply(special_contacts, c))
	events.append_array(ProjectileMotion.step(w.projectiles, w.fighters, book, c))
	events.append_array(ItemMotion.step(w.items, w.fighters, book, c, w.arena))
	events.append_array(GimmickRunner.step(w.arena, w.fighters, c, w.tick_count, events))
	events.append_array(w.items.spawn_step(w.tick_count, rng, c, w.arena.item_area))
	events.append_array(GuardMeter.step(w.fighters, c))
	events.append_array(SpecialGauge.apply(w.fighters, events, c))
	events.append_array(Rules.apply(w.fighters, c, w.arena))
	Grab.cleanup(w.fighters)
	events.append_array(ItemActions.drop_from_disabled(w.fighters, w.items, c))
	return events
