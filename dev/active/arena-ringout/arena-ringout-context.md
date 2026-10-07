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
