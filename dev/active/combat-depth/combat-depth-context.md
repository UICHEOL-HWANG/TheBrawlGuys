# combat-depth — Context
Last Updated: 2026-09-30 (A 완료)

- sim 입력: `src/sim/input_frame.gd`(move/jump/light/heavy/guard/grab). 새 버튼 없이 guard+방향으로 회피.
- 필살기 = heavy+guard 같은 틱 → 회피보다 우선.
- 가드: `src/sim/actions.gd` step_guard, `guard_damage_mul` 0.2 (무한 가드).
- 타격 이벤트: `src/sim/combat.gd` apply_hit → "hit"/"guard_hit". 연출: `src/render/feel/feel_director.gd`, `hit_spark.gd`.
- 규칙: .gd ≤200줄·함수 <40줄, sim 결정적, 테스트 먼저, `scripts/test.sh` + `scripts/check-all.sh`.
- A 결정: 회피 판정은 guard 누름 틱(`guard_press_age == 0`)만. heavy 동시 입력(필살기 코드)은 회피 제외. 가드 브레이크 = HITSTUN + `guard_break_left`. 저스트 가드 스태거는 공격자가 ATTACK 상태일 때만.
- 봇은 위협 1틱 뒤 반응(`bot_guard_react_ticks`): 0이면 거의 모든 가드가 저스트 가드, 3 이상이면 약공격 1타를 못 막음.
