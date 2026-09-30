# Phase 4 — Context

**Last Updated:** 2026-09-30
**상태:** 시작
**계획:** [`phase-4-plan.md`](./phase-4-plan.md) (통합 계획의 "Phase 4" 절) · **체크리스트:** [`phase-4-tasks.md`](./phase-4-tasks.md)
**이전 Phase:** [`dev/done/phase-3/phase-3-context.md`](../../done/phase-3/phase-3-context.md)

## 목표
경기장마다 싸우는 방식이 달라진다 (PHASES Phase 4).

## 결정
- G1: `ArenaData`는 sim 쪽 데이터(판정 도형·링아웃·기믹·테마 id). 기본 원형 경기장은 현재와 동일 동작
- G2: 기믹은 전부 sim·결정적, 새 sim 이벤트(`gimmick_damage`, `platform_break`, `bounce`, `fog_start`, `fog_end`)로 렌더·트래킹에 전달
- G3: 리플레이 GOLDEN/BEHAVIOR 해시는 의도적으로 갱신, 커밋 메시지에 사유. 경기장별 해시 추가
- G4: Phase 3 이월 sim 이슈(hitstop 입력 삼킴, 방망이 밸런스, 동틱 상호타격 편향) 이번에 처리
- G5: 트래킹 — `gimmick_triggered`, `gimmick_ringout`, `arena_selected`, `stock_lost.cause/zone`

## 핵심 파일
`src/sim/collision.gd`, `rules.gd`, `world.gd`, 신규 `src/sim/arena/`, `src/render/arena_view.gd`, `decor_view.gd`, `environment_rig.gd`, `tests/replay/test_replay.gd`

## T1–T5 병합 (2026-09-30, merge 6b823a0)
- 테스트 547/547, check-all 통과. 4봇 틱 비용 경기장별 평균 66~80µs (예산 2000µs)
- 경기장 id: classic(기본) · lakeside_camp · log_bridge · mushroom_forest · foggy_forest. `World(config, seed, count, ArenaCatalog.build(id, config))`
- 새 sim 이벤트: gimmick_damage{kind,target,amount,pos} · platform_break/restore{id,pos} · bounce{fighter,pad,pos} · fog_start{id,ticks} · fog_end{id} · ringout.zone(kill_y|blast|lake|water)
- state_view 추가: arena, arena_theme, arena_floors, gimmicks[], fighter.burning
- 해시: GOLDEN 2216053793, BEHAVIOR 11665018 (사유는 각 커밋), ARENA_HASHES는 test_arena_replay.gd
- 봇 미러 교착 방지: `bot_attack_range_spread` (동시 타격 공정화의 부작용)
- 남은 것: T6 렌더(경기장 뷰·테마·위험 표시·안개), T7 선택 화면 — 앱 셸 병합 후

## 사용자 요청 (2026-09-30)
- 아이템 모델을 임시 도형에서 정식 모델로 (T8). 방식: 코드로 만드는 절차적 저폴리 모델(`src/render/props/items/` 아이템당 1파일) — 다운로드·라이선스 없음, 기존 소프트 툰·구 클러스터 룩과 일관. 색은 DS 토큰(BARK·STONE_*·FIRE 등). 🖼 캡처로 확인 후 확정
- 게스트 로그인은 두지 않음 (Google만) — 재확인
