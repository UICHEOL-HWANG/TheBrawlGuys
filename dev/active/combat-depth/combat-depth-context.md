# combat-depth — Context
Last Updated: 2026-09-30

- sim 입력: `src/sim/input_frame.gd`(move/jump/light/heavy/guard/grab). 새 버튼 없이 guard+방향으로 회피.
- 필살기 = heavy+guard 같은 틱 → 회피보다 우선.
- 가드: `src/sim/actions.gd` step_guard, `guard_damage_mul` 0.2 (무한 가드).
- 타격 이벤트: `src/sim/combat.gd` apply_hit → "hit"/"guard_hit". 연출: `src/render/feel/feel_director.gd`, `hit_spark.gd`.
- 규칙: .gd ≤200줄·함수 <40줄, sim 결정적, 테스트 먼저, `scripts/test.sh` + `scripts/check-all.sh`.
- 트랙 B (feat/hit-impact, 렌더 전용): `src/render/feel/` impact_tier(단계·방향·크기) · impact_burst(별+링+스피드 라인, 가드 클랭) · star_shape(메시) · fx_pool(라운드로빈 풀) · damage_popup(+N% 숫자) · hit_reaction(피격 플래시·반동, 공격자 내딛기) · screen_flash. FeelDirector.on_events(events, fighters), MatchStage._react. 튜닝: `impact_medium_threshold` 4, `spark_large_threshold` 8(=강타), `impact_heavy_punch` 0.35, `damage_popups` 1. hitstop(`hitstop_light` 0.06/`hitstop_heavy` 0.1)은 sim 값이라 그대로 둠. 증거: `scripts/capture_hits.gd` → `evidence/hit-*.png`.
