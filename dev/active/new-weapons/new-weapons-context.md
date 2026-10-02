# New weapons — context
Last Updated: 2026-10-02
- game_config.gd is 292 lines: new tunables in src/config/item_extras_config.gd (base of the chain:
  DdaConfig extends ItemExtrasConfig), group "ItemExtras" in SIM_GROUPS + CONFIG_SCRIPTS.
- Replay tests use GameConfig.new() (script defaults); the game loads default_config.tres.
- test_classic_compat strips fighter fields: add light_ticks.
- bot_controller.gd is exactly 200 lines; test_item_use.gd 245 → new tests in new files.
- AttackSet kinds append after SPECIAL; WorldCodec VERSION 10 → 11 (light_ticks).
