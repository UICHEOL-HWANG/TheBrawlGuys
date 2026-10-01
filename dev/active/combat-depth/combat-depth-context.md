# combat-depth — Context
Last Updated: 2026-10-01 (C feat/di-tech)

- sim 입력: `src/sim/input_frame.gd`(move/jump/light/heavy/guard/grab). 새 버튼 없이 guard+방향으로 회피.
- 필살기 = heavy+guard 같은 틱 → 회피보다 우선.
- 가드: `src/sim/actions.gd` step_guard, `guard_damage_mul` 0.2 (무한 가드).
- 타격 이벤트: `src/sim/combat.gd` apply_hit → "hit"/"guard_hit". 연출: `src/render/feel/feel_director.gd`, `hit_spark.gd`.
- 규칙: .gd ≤200줄·함수 <40줄, sim 결정적, 테스트 먼저, `scripts/test.sh` + `scripts/check-all.sh`.
- A 결정: 회피 판정은 guard 누름 틱(`guard_press_age == 0`)만. heavy 동시 입력(필살기 코드)은 회피 제외. 가드 브레이크 = HITSTUN + `guard_break_left`. 저스트 가드 스태거는 공격자가 ATTACK 상태일 때만.
- 봇은 위협 1틱 뒤 반응(`bot_guard_react_ticks`): 0이면 거의 모든 가드가 저스트 가드, 3 이상이면 약공격 1타를 못 막음.
- C 결정 (feat/di-tech): DI = 히트스톱이 끝나는 첫 틱의 스틱(`di_pending`), 수직 성분 비례 최대 15°, 수직 바이어스 없음. 텀블 = 깨끗한 타격 + 위로 뜸 + 넉백 ≥ 8 (`Fighter.tumble`, set_state가 HITSTUN/AIR 외 상태로 가면 해제, 점프도 해제). 텀블 착지 = KNOCKDOWN(누운 시간 = state_ticks) 또는 낙법. 누운 상대 타격 = 넉백 ×0.5 + 다시 텀블 안 함(무한 다운 방지). 텀블 중 가드는 낙법 입력이라 공중 회피 안 됨. 낙법 시계 `tech_clock` 하나로 창(12)+잠금(40). 기상 공격 판정은 SpecialHits.radial 재사용, Combat.resolve 뒤 적용.
- C 봇: 가드 턴의 65%(`bot_perfect_guard_chance` 0.35)는 "예측 턴" — 상대가 다가오는데 아직 자기 사거리 밖이면 미리 가드(일반 가드), 예측 못 하면 약공격엔 늦음(차지는 막음). 결과(봇 20판): 저스트 가드 112 → 34, 막은 타격 중 비율 48% → 38%. 0.25는 밸런스 칸 하나(바바리안→나이트 28%)가 30% 밑이라 0.35 채택(16칸 31~67%, `evidence/balance-c.csv`). 처음엔 hash(id, 턴 수)만 써서 모든 경기에서 슬롯별 패턴이 같아 슬롯 편향(로그 미러 27%) → view tick 추가로 해소. 봇 경기 길이 약 35% 짧아짐(가드 감소) → test_arena_bots 시드 11 → 18, test_bot_coverage 21 → 23. 봇 선택은 sim RNG를 못 읽어서 hash(id, view tick)로 결정적.
- 트랙 B (feat/hit-impact, 렌더 전용): `src/render/feel/` impact_tier(단계·방향·크기) · impact_burst(별+링+스피드 라인, 가드 클랭) · star_shape(메시) · fx_pool(라운드로빈 풀) · damage_popup(+N% 숫자) · hit_reaction(피격 플래시·반동, 공격자 내딛기) · screen_flash. FeelDirector.on_events(events, fighters), MatchStage._react. 튜닝: `impact_medium_threshold` 4, `spark_large_threshold` 8(=강타), `impact_heavy_punch` 0.35, `damage_popups` 1. hitstop(`hitstop_light` 0.06/`hitstop_heavy` 0.1)은 sim 값이라 그대로 둠. 증거: `scripts/capture_hits.gd` → `evidence/hit-*.png`.
