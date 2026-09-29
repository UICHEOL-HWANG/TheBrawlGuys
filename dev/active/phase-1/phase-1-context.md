# Phase 1 — Context

**Last Updated:** 2026-09-29
**상태:** 계획 작성 완료, 구현 전 (사용자 확인 대기 결정 있음)
**계획:** [`phase-1-plan.md`](./phase-1-plan.md) · **체크리스트:** [`phase-1-tasks.md`](./phase-1-tasks.md)
**이전 Phase:** [`dev/done/phase-0/phase-0-context.md`](../../done/phase-0/phase-0-context.md)

---

## 목표

캡슐 두 개로 "강하게 맞으면 확실히 날아간다"를 완성한다. 키보드와 Android 터치로 봇과 한 판을 끝까지 할 수 있어야 한다 (PHASES.md Phase 1).

## 결정 사항

### 사용자 확인 대기 (구조에 영향)

| # | 결정 | 이유 | 대안 |
|---|---|---|---|
| D1 | **config를 추적되는 sim 입력으로**: World는 받은 GameConfig로 돌고, `snapshot()`/`state_hash()`에 **config 지문**(모든 @export 값의 해시)을 포함한다. 로컬 플레이에서는 디버그 패널 라이브 튜닝을 그대로 허용한다 (Phase 1의 핵심 작업이 튜닝이므로). 리플레이 테스트는 config를 명시적으로 만들어 넘긴다. 온라인(Phase 6)에서는 라이브 편집을 끈다 | Phase 0 Ruling 15. 리플레이·재조정이 "같은 config"를 검증할 수 있어야 함 | 경기 시작 시 config를 복사해 고정 (튜닝이 다음 판부터 반영됨 → Phase 1 튜닝이 불편) |
| D2 | **카메라 프레이밍**: x는 가로 FOV(화면비 반영), z는 피치에 따른 원근 축소(`sin(pitch)`)를 반영해 따로 맞춘다. `cam_zoom_max` 기본 40 → 70 (범위 10~150) | Ruling 16. 10 m 경기장 밖 15 m까지 날아간 캐릭터를 담기 | 줌 한계만 올리기 |
| D3 | **리플레이 하네스** `tests/replay/`: 시드 + config + 입력 스크립트 → 600틱 state_hash 시퀀스. 결정성(2회 동일), 복원 후 이어가기 동일, 골든 해시 회귀 | PHASES Phase 1 테스트, PRD-ARCH-05 | — |
| D4 | **state_view는 값 데이터만** + 파이터마다 `spawn_id` (리스폰 시 증가) → 뷰는 spawn_id가 바뀌면 lerp 대신 스냅 | Phase 0 최종 리뷰 #5 | — |
| D5 | **InputFrame 이동값 양자화**: `move_x/z`를 1/127 단위로 (`InputFrame.make()`) | 로컬·봇·네트워크 입력의 비트 동일성 | Phase 6에서 도입 (나중에 바꾸면 리플레이 전부 재생성) |
| D6 | **버튼 입력은 래치**: 키 누름은 프레임에서 기록하고 다음 sim 틱이 소비 (프레임당 틱이 0개·2개여도 누름이 사라지거나 중복되지 않음) | 60Hz 고정 틱과 가변 프레임의 불일치 | `is_action_just_pressed`를 틱마다 호출 (누름 손실 발생) |
| D7 | **넉백은 대미지 적용 후 %로 계산** (`damage += atk.damage` → `knockback = (base + damage × scaling) × mul`) | 스매시류 관례, 첫 타부터 넉백 존재 | 적용 전 % |
| D8 | **공중 관성 유지**: 공중에서는 입력 방향으로 `air_acceleration`만큼 가속하고, 입력이 없으면 `air_drag`로만 감속한다 (지상은 즉시 반영) | 입력 없음 = 속도 0으로 덮어쓰면 hitstun이 끝나는 순간 날아가던 캐릭터가 공중에서 멈춰 "날아가는 맛"이 사라짐 (계획 작성 중 발견) | 공중도 지상처럼 즉시 반영 |

### 확정 (Phase 1 범위)

- 파이터는 캡슐 (P1 = `DS.P1` 파랑 플레이어, P2 = `DS.P2` 빨강 봇) + DS-VIS-03 발밑 링 + `P1`/`P2` 라벨
- 공격 수치는 `GameConfig`의 LightAttack 그룹 → sim 안에서 `AttackData` 값 객체로 변환 (Phase 5 스타일에서 데이터 파일로 확장). sim은 `load()` 금지이므로 리소스 로딩은 하지 않는다
- 링아웃: `y < kill_y` 또는 수평 거리 > `arena_radius + blast_margin`
- 가장자리에서 걸어 나가면 떨어진다 (별도 벽 없음)
- 터치 Phase 1: 플로팅 스틱 + 점프 + 공격(탭 → 뗄 때 약공격). 디버그 패널 토글은 4손가락 탭 (Phase 0)
- HUD 🖼 게이트: Stitch 프롬프트 #1(`docs/stitch-prompts.md`)로 시안을 만들어 비교 → 확정 후 HUD 비주얼 구현. 게이트가 지연되면 design.md DS-LAY-02 기본 배치로 진행하고 🖼 상태를 남긴다
- 틱 비용: 매 프레임 sim 소요 시간을 디버그 패널 정보 줄에 표시 + `scripts/bench_sim.gd`로 4인 600틱 측정
- 입력 지연: `scripts/measure_input_latency.gd`로 키 입력 → 상태 반영 프레임 수 측정 (≤ 3)

## 핵심 파일 (구현 후 확정)

| 파일 | 역할 |
|---|---|
| `src/sim/collision.gd` | 지면·경계, 캡슐–캡슐 밀어내기, 캡슐–박스(Y축 회전) 판정 |
| `src/sim/fighter.gd` | 파이터 상태·직렬화·뷰 변환 |
| `src/sim/attack_data.gd` | 공격 수치 값 객체 |
| `src/sim/combat.gd` | 히트 판정, 대미지, 넉백 공식, hitstun/hitstop |
| `src/sim/rules.gd` | 링아웃, 스톡, 리스폰, 승패 |
| `src/sim/world.gd` | 틱 진행, snapshot v2 (파이터 + config 지문) |
| `src/input/*` | 키 바인딩, 래치, 키보드·터치·봇 → InputFrame |
| `src/render/fighter_view.gd` | 보간·스냅, 발밑 링, 무적 깜빡임 |
| `src/render/feel/*` | 화면 흔들림, 히트 퍼프 |
| `src/ui/components/*` | DamageCounter, StockIcons, TouchStick, TouchButton, ResultBanner |
| `tests/replay/*` | 리플레이 회귀 |

## 의존성

- Phase 0 산출물 전부 (World, FixedTicker, GameConfig, DS, ThemeBuilder, CameraRig, capture_evidence.gd, check-all.sh)
- Google Stitch + aside CLI (HUD 🖼 게이트, 사용자 수행)
- Android 실기기 (완료 기준: 터치로 한 판) — Phase 0부터 대기 중

## 열린 이슈

1. **커버리지 80% 측정 도구** (Phase 0 열린 이슈 1): Phase 1 시작 시 GUT 커버리지 플러그인 조사 또는 PRD-NFR-06 문구 조정
2. **Android 실기기**: 없으면 완료 기준 "터치로 한 판"은 데스크톱 마우스 터치 에뮬레이션까지만 확인하고 대기 표시
3. **초기 넉백 수치**: PRD §4.5 값(약공격 base 3, scaling 0.05)으로는 100%에서도 링아웃이 어렵다 (계산상 수평 이동 약 2~3 m). T17 튜닝에서 `global_knockback_mul` 등을 조정하고 PRD §4.5 초기값 표를 갱신한다 (README R6)

## 리스크

| 리스크 | 대응 |
|---|---|
| 캡슐–박스 판정 오류로 맞는데 안 맞음 | 경계값 단위 테스트 (T3), 디버그용 히트박스 표시는 Phase 2 |
| 고정 틱 + 래치 누락으로 입력 씹힘 | 래치 단위 테스트 (T2), 입력 지연 측정 스크립트 (T17) |
| 리플레이 골든 해시가 사소한 변경마다 깨짐 | 골든 갱신 절차를 테스트 주석에 명시, 결정성 테스트는 골든과 분리 |
