# arena-ringout context
Last Updated: 2026-10-07
- Fall: src/sim/motion.gd (_integrate walk-off), src/sim/rules.gd (ringout), src/sim/arena/arena_floor.gd
  (out_zone), src/config/game_config.gd (kill_y), src/render/character/{anim_map,anim_clips,character_animator}.gd,
  src/render/fighter_view.gd, src/render/feel/{feel_director,ringout_burst}.gd, src/render/decor_view.gd (GROUND_Y -1)
- Arena: src/sim/arena/{arena_catalog,arena_data}.gd + arenas/, gimmicks/; src/render/arena/{arena_theme.gd,
  themes/, arenas/arena_dressings.gd, gimmicks/gimmick_views.gd}; src/app/screens/arena_cards.gd
- main has uncommitted polish-pass work (another session): character_model.gd follow_tumble/set_tumble,
  tumble_spin.gd, fighter_view.gd animate(). Do NOT edit character_model.gd here; expect a small merge in
  fighter_view.gd / character_animator.gd.
- Decision: kill_y -2 (root cause = ring-out happens 7 m under the visible ground)
- Finding: bot-vs-bot matches end ~1/3 sooner with kill_y -2 (same ring-out count, less time). No recovery
  is lost: in 12 baseline bot matches no fighter ever moved upward below y=-2. Cause of the pacing shift not
  pinned down (chaotic bot matches); human matches only lose the 0.4 s of doomed fall.
- FallPose writes CharacterModel.rotation only (HitReaction owns its position/scale; polish-pass tumble
  turns the glb root inside it). The classic decor lake (-0.95) is held at -1 for ~7 frames before the splash.
