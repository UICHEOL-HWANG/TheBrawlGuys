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
