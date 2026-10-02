# New weapons — tasks
- [x] Sim: config (ItemExtrasConfig), kinds + pool, hammer/glove attacks, light status, banana trap/slip (TDD)
- [x] Render: models (banana arc fixed after capture), held, light feathers; audio squeak/slip baked
- [x] Bots (banana throwable, traps skipped), telemetry (names, slip → item_hit), docs (PRD-ITEM-05..07,
      PHASES, design DS-VIS-05, tracking-plan, schema 13)
- [x] Golden hashes updated (config_fp + light_ticks); test_classic_compat proves classic bit-identical
- [x] Review fixes: traps excluded from the drop cap, allies never slip, no slip from hitstun/hitstop,
      slip drops the held item, self-slip not an item_hit
- [x] Side fix: 2P key hints clipped at 1280×720 → KeyHintFit shrink-to-fit
- [ ] Playtest balance (hammer angle 6, glove 1.5×/5 s, banana grace 0.75 s)
