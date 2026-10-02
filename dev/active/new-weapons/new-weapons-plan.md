# New weapons — plan (2026-10-02, user: "나머지도 진행해" → recommended trio)

Squeaky hammer (뿅망치), feather glove (깃털 장갑), banana peel (바나나 껍질).

- Determinism: ItemField draws the kind with the same single randi_range; the range is 3 (classic)
  or 6 (`item_pool_extended`, ItemExtrasConfig). Script default false = classic replays unchanged
  (only config_fp moves); default_config.tres turns it on for the game.
- Hammer: melee like the bat, AttackSet.Kind.HAMMER, steep launch_angle_y (pops straight up), uses.
- Glove: melee, AttackSet.Kind.GLOVE, weak hit that sets target.light_ticks; while light the target
  takes glove_light_knockback_mul knockback (ItemStatus, applied in Combat.apply_hit).
- Banana: thrown like a rock but passes through fighters; lands as a trap (fuse_ticks = owner grace,
  then 0 = live, never pickable); a grounded fighter stepping on it slips into KNOCKDOWN (ItemTraps).
- Render models (procedural, DS colors), held transforms, light status visual, SFX squeak/slip,
  bots (banana throwable, skip traps), telemetry names + tracking plan (schema 13), PRD-ITEM-05..07,
  design DS-VIS-05, golden hashes (config_fp + light_ticks field) updated with reasons.
