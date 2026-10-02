# Finisher replay — context
Last Updated: 2026-10-02 (implemented, review fixes in)

- src/main/main.gd (≤200 lines rule) — match loop; World stops ticking once match_over.
- src/main/match_presentation.gd — camera/feel/cut-in; cut-in director sets camera focus each frame.
- src/render/camera_rig.gd set_focus(point, weight) + SpecialCutIn.shot close shot (7 m, 38°).
- Sim events: "hit" {attacker,target,pos,...}, "ringout" {id,pos,stocks_left,zone}.
- Reduce motion: SpecialCutInDirector.reduce_motion_setting → no zoom (slow-mo kept).
- Decisions: Engine.time_scale for uniform slow-mo (restored on stop/restart/exit); tracking
  finish stays at the real match end; only the banner waits.
