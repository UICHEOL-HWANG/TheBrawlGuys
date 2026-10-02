# Finisher replay (GD-CAM-02) — plan

Approved 2026-10-02: "막타 슬로 리플레이" option.

When a match ends on a ring-out, hold the result banner and replay the last moments from a
render-side buffer of tick views: start just before the last hit on the knocked-out fighter, slow
(Engine.time_scale) around the hit, faster through the flight, close camera shot on the victim,
short tail, then the banner. Render only — the sim is already over (match_over), so tick rate and
replay hashes never change; online-safe.

1. FinisherReplay (src/render/feel, RefCounted, pure): ring buffer, start/advance/speed/weight. TDD.
2. MatchFinale (src/main, Node): drives FinisherReplay, time_scale, stage + presentation draw.
3. main.gd: record each tick, start finale on match end (telemetry unchanged), banner after it,
   accept skips to the banner.
4. MatchPresentation: finisher focus overrides the cut-in focus.
5. docs/design.md GD-CAM-02, capture evidence, code review.
