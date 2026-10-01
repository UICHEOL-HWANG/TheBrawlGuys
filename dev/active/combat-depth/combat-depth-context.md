# combat-depth — Context
Last Updated: 2026-10-01 (D feat/modes)

- sim 입력: `src/sim/input_frame.gd`(move/jump/light/heavy/guard/grab). 새 버튼 없이 guard+방향으로 회피.
- 필살기 = heavy+guard 같은 틱 → 회피보다 우선.
- 가드: `src/sim/actions.gd` step_guard, `guard_damage_mul` 0.2 (무한 가드).
- 타격 이벤트: `src/sim/combat.gd` apply_hit → "hit"/"guard_hit". 연출: `src/render/feel/feel_director.gd`, `hit_spark.gd`.
- 규칙: .gd ≤200줄·함수 <40줄, sim 결정적, 테스트 먼저, `scripts/test.sh` + `scripts/check-all.sh`.
- A 결정: 회피 판정은 guard 누름 틱(`guard_press_age == 0`)만. heavy 동시 입력(필살기 코드)은 회피 제외. 가드 브레이크 = HITSTUN + `guard_break_left`. 저스트 가드 스태거는 공격자가 ATTACK 상태일 때만.
- 봇은 위협 1틱 뒤 반응(`bot_guard_react_ticks`): 0이면 거의 모든 가드가 저스트 가드, 3 이상이면 약공격 1타를 못 막음.
- 트랙 B (feat/hit-impact, 렌더 전용): `src/render/feel/` impact_tier(단계·방향·크기) · impact_burst(별+링+스피드 라인, 가드 클랭) · star_shape(메시) · fx_pool(라운드로빈 풀) · damage_popup(+N% 숫자) · hit_reaction(피격 플래시·반동, 공격자 내딛기) · screen_flash. FeelDirector.on_events(events, fighters), MatchStage._react. 튜닝: `impact_medium_threshold` 4, `spark_large_threshold` 8(=강타), `impact_heavy_punch` 0.35, `damage_popups` 1. hitstop(`hitstop_light` 0.06/`hitstop_heavy` 0.1)은 sim 값이라 그대로 둠. 증거: `scripts/capture_hits.gd` → `evidence/hit-*.png`.
- 트랙 D (feat/modes): 규칙 데이터 `src/sim/modes/` — `MatchRules`(mode stock/team/timed, teams, friendly_fire, duration_ticks; `MatchSetup.rule` → `build_rules` → `World.new(..., rules)`), `ModeState`(점수·마지막 가격자·시계·서든 데스·winner_team, 스냅샷 "mode", v9), `ModeOutcome`(승자). 아군 공격 차단 = `Fighter.ally_mask` + `untouchable_by(source_id)` — 모든 접촉 탐색(근접·잡기·투사체·필살기·아이템·폭발)이 쓰는 한 곳. 시간제 무제한 리스폰 = `Rules.apply(..., infinite_stocks)`. 스톡 경기는 새 키를 빼면 비트 단위로 동일(`test_classic_compat`). 튜닝 `ModeConfig`("Modes" sim 그룹: timed_duration 120, friendly_fire 0, ringout_credit_time 3). 봇 = `BotViewQuery.nearest_foe`가 팀원 제외.
- D UI: `RuleSelectScreen`(App.SELECT_STEPS = rule → character → arena, `SelectScreens`가 화면 생성), HUD v2 = `HudStrip` + `PlayerCard`(초상·대미지 바·게이지 바·스톡/점수·N연타) + `MatchTimer`, 터치 중엔 위쪽. 카메라 = `HudSafeFrame`(오프셋 프러스텀) + `CameraFraming.match_targets`에 라벨 꼭대기 포함, 튜닝 `cam_hud_reserve`. 증거 `scripts/capture_modes.gd`.
