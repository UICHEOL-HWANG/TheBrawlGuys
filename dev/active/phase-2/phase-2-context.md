# Phase 2 — Context

**Last Updated:** 2026-09-29
**상태:** 계획 작성 완료, 구현 전 (사용자 확인 대기 결정 있음)
**계획:** [`phase-2-plan.md`](./phase-2-plan.md) · **체크리스트:** [`phase-2-tasks.md`](./phase-2-tasks.md)
**이전 Phase:** [`dev/done/phase-1/phase-1-context.md`](../../done/phase-1/phase-1-context.md)

---

## 목표

아이템을 먼저 줍기 위한 눈치 싸움을 만들고, 터치 조작을 스틱 + 4버튼 완성형으로 올린다 (PHASES.md Phase 2).
전투 액션 6종(이동·점프·약공격 3타·강공격 차지·가드·잡기/던지기)과 아이템 3종(방망이·폭탄·돌멩이)이 sim 안에서 결정적으로 동작한다.

## 결정 사항

### 사용자 확인 대기 (게임 감각·구조에 영향)

| # | 결정 | 이유 | 대안 |
|---|---|---|---|
| E1 | **약공격 3타 = 연결타 2 + 마무리 1**: 1·2타는 넉백이 작고(`light_link_*`, 발사각 0) 최소 hitstun을 보장해 다음 타가 이어지고, 3타가 Phase 1의 약공격 수치(`light_*`) 그대로다. Phase 1 기준 "100%에서 약공격 한 방 링아웃"은 "100%에서 3타 콤보 마무리 링아웃"으로 바뀐다 | 1타가 Phase 1처럼 강하면 상대가 날아가서 2타가 절대 안 맞는다. 스매시류 잽 관례 | 1타를 강하게 유지하고 콤보는 헛치기만 가능 (콤보 의미 없음) |
| E2 | **콤보 입력 버퍼**: 현재 타의 남은 틱이 `combo_buffer_ticks`(기본 10) 이하일 때 약공격을 누르면 다음 타가 예약되고, 현재 타가 끝나는 틱에 바로 이어진다. 그보다 이른 입력은 버린다. 헛쳐도 이어진다 | PHASES 테스트 "버퍼 안/밖 입력 시 2타 연결 여부" | 명중했을 때만 연결 |
| E3 | **강공격 입력은 누르고 있는 상태(level)**: `InputFrame.heavy`는 홀드 중 true. sim은 true인 동안 차지(최대 `heavy_charge_max_time`), false가 되는 틱에 발동. 배율 = 1 + (1.6 − 1) × min(차지/최대, 1) → 대미지·넉백 모두에 곱한다. 입력 레이어는 `HoldLatch`로 한 프레임 안의 짧은 탭도 최소 1틱 홀드로 전달 | PRD §3.1 `heavy: 누르고 있는 동안 true`, PHASES 테스트 0/0.5/1.0/1.5초 → 1.0/1.3/1.6/1.6 | 누름/뗌 이벤트 두 개로 전달 |
| E4 | **가드**: 지상에서만, 홀드 동안 유지, 이동·공격 불가. 가드 중 피격 → 대미지 × `guard_damage_mul`, 넉백 × `guard_knockback_mul`(0 → hitstun 없음), 양쪽 hitstop은 그대로, `guard_hit` 이벤트(버블 출렁임용). **잡기는 가드를 무시**한다 (공격 > 잡기 준비, 가드 > 공격, 잡기 > 가드). 가드 게이지·가드 브레이크는 없음 | PRD §4.3, 단순한 상성 | 가드 시간 제한 |
| E5 | **잡기 → 던지기**: 지상에서 잡기 = 짧은 잡기 판정(ATTACK 상태, `GRAB` 종류, 대미지 없음). 성공하면 잡은 쪽 HOLDING / 잡힌 쪽 HELD. 잡은 쪽은 이동 입력으로 방향만 돌리고, 잡기 재입력으로 그 방향에 던진다(`throw_*` 수치). `grab_hold_max_time`(1.5초) 지나면 자동으로 놓는다. 제3자에게 맞으면 풀린다. 연타 탈출은 없음 | PRD §4.3 "방향 입력 + 잡기 재입력으로 던짐" | 잡자마자 자동 던지기 |
| E6 | **아이템 모델**: 떨어지는 상자 = 아이템 자체(종류는 생성 시 시드 RNG로 정하고, 착지 후 모양이 보인다). 필드 최대 `item_max_on_field`(2)개. 주우면 아이템 엔티티는 사라지고 파이터가 `item_kind`·`item_uses`를 가진다. 든 채로 **잡기 = 던지기**(모든 종류), **약공격 = 사용**(방망이는 휘두르기, 폭탄·돌멩이는 던지기). 피격·잡힘 시 떨어뜨리고, 링아웃하면 잃는다 | 파이터에 값 두 개만 두면 스냅샷·뷰가 단순. PRD §4.4 "잡기 버튼으로 줍기/사용/던지기" | 아이템 엔티티가 파이터를 따라다님 |
| E7 | **아이템 판정**: 던진 돌멩이·방망이는 첫 번째로 닿은 상대(던진 사람 제외)에게 `rock_*` 수치로 명중하고 사라진다. 땅에 닿아도 사라진다. 폭탄은 던지는 순간 불이 붙어 `bomb_fuse_time`(2초 = 120틱, 던진 틱 포함) 뒤 반경 `bomb_radius` 안의 **모두(던진 사람 포함)**에게 중심에서 바깥 방향으로 명중한다. 불붙은 폭탄은 주울 수 없다. 방망이는 휘두를 때마다 1회 소모, 5회째 휘두르기 시작과 함께 사라진다 | PHASES 테스트 "방망이 5회 사용 후 소멸, 폭탄 120틱 후 폭발 범위 내만 피격" | 폭탄이 던진 사람은 안 맞음 |
| E8 | **결정성**: 아이템 생성(시각·위치·종류)만 World RNG를 쓴다. 호출 순서는 고정: 다음 생성 틱 → 각도 → 반경 → 종류. snapshot v4에 아이템 목록·다음 생성 틱·다음 id 포함 | PRD-ARCH-05, PHASES 테스트 "같은 시드 → 같은 상자 낙하 위치·시간" | — |
| E9 | **터치 4버튼 레이아웃 3안을 모두 구현**하고 `touch_layout`(0 호 / 1 다이아몬드 / 2 2×2)로 전환한다. 🖼 게이트(Stitch 시안 비교 + 실제 화면 비교)로 기본값을 정한다. 레이아웃은 safe area 안쪽에 배치 | 시안과 실제 조작감을 같이 비교 가능. Phase 1 이월 "safe-area 여백" | 게이트 후 한 안만 구현 |
| E10 | **ChargeGauge는 화면 공간 Control**을 캐릭터 머리 위 3D 좌표에 투영해 배치 (`CameraRig.unproject()`) | DS 갤러리에 다른 컴포넌트와 같은 방식으로 등록 가능 | Sprite3D/SubViewport 월드 오브젝트 |
| E11 | **리플레이**: 기존 스크립트 입력 골든(sim 전용)은 1200틱으로 늘리고 강공격·가드·잡기 입력을 추가한다. 별도로 봇 대 봇 커버리지 테스트(골든 없음, 2회 동일 + 이벤트 종류 단언: hit·guard_hit·grab·item_spawn·item_pickup·ringout)를 둔다 | 스크립트 입력만으로는 아이템 줍기가 보장되지 않음. Phase 1 이월 "리플레이가 링아웃/KO를 단언하지 않음" | 봇 입력으로 골든 (봇 수정마다 골든 깨짐) |

### 확정 (Phase 2 범위)

- 공격 수치는 `AttackSet.from_config(config)`가 틱마다 종류별 `AttackData` 표로 만든다 (Phase 5 스타일이 이 표를 대체)
- Fighter 상태 추가: `CHARGE`, `GUARD`, `HOLDING`, `HELD` (기존 enum 값 뒤에 붙여 기존 값 유지)
- 틱 순서: `ItemActions.pre_step` → `Motion.step`(파이터별) → `Motion.separate` → `Grab.step` → `Grab.resolve` → `Combat.resolve` → `ItemMotion.step` → `ItemField.spawn_step` → `Rules.apply` → `Grab.cleanup` → `ItemActions.drop_from_disabled` → 승패
- 봇 2단계: 위협(상대 공격·차지 시작)에 번갈아 가드, 가까운 아이템 줍기, 방망이 휘두르기, 돌멩이·폭탄 던지기, 잡으면 바깥쪽으로 던지기, 사거리 안에서 3타 콤보. "스타일 사거리"는 Phase 5
- 게임패드 바인딩은 범위 밖 (키보드 6액션만, PHASES 문구 그대로)
- 증거: 상자 쟁탈 영상은 봇 대 봇 데모 씬 `src/debug/item_race_demo.tscn` + Movie Maker

### Phase 1 이월 항목 처리

| 항목 | Phase 2 처리 |
|---|---|
| 터치 cancel → 약공격 억제, 포커스 상실 시 손가락 초기화 | T12 |
| safe-area 여백 | T12 (터치 레이아웃), T19 (HUD) |
| 재시작 시 화면 흔들림 초기화, main 재시작 경로 테스트 | T19 |
| KO 필드 정리 | T6·T8 (`Rules`가 KO·리스폰 때 잡기·아이템·차지 필드 초기화) |
| 리플레이가 링아웃/KO 미단언 | T10 (봇 커버리지 테스트) |
| 테마 Button 포커스 색 | T14 |
| 같은 틱 상호 타격 순서 편향 | Phase 3로 이월 (공격 종류가 늘어난 뒤 한꺼번에 판단) |
| config 지문을 sim 필드로 제한 | Phase 6 전 (변경 없음) |
| 캐릭터 크기(카메라 여백) | 🖼 게이트(T13) 때 사용자와 함께 결정 |
| HUD 🖼 시안(Phase 1 T12), Android 실기기 | T13 게이트에서 함께 진행 |

## 핵심 파일 (계획 기준)

| 파일 | 역할 |
|---|---|
| `src/sim/attack_set.gd` | 종류별 AttackData 표 |
| `src/sim/actions.gd` | 조작 상태 전이: 약공격 콤보, 차지, 가드, 잡기 시도, 방망이 |
| `src/sim/grab.gd` | 잡기 판정, 들기, 던지기, 풀림 정리 |
| `src/sim/item.gd` · `item_field.gd` · `item_actions.gd` · `item_motion.gd` | 아이템 엔티티, 생성·저장, 줍기·던지기·떨어뜨리기, 낙하·투사체·폭발 |
| `src/input/hold_latch.gd` · `attack_button_model.gd` · `touch_layout.gd` · `grab_context.gd` | 홀드 입력, 탭/홀드 해석, 버튼 배치, 잡기 컨텍스트 |
| `src/render/item_view.gd` · `item_layer.gd` · `grab_hint.gd` | 아이템·그림자·잡기 표시 |
| `src/ui/components/charge_gauge/*` | ChargeGauge (DS-CMP-05) |

## 의존성

- Phase 1 산출물 전부
- Google Stitch (🖼 4버튼 레이아웃 게이트, 사용자 수행) — `docs/stitch-prompts.md` 1번
- Android 실기기 (완료 기준 "터치만으로 6액션")

## 열린 이슈

1. **Android 실기기** (Phase 0부터 대기): 없으면 터치 완료 기준은 데스크톱 마우스 에뮬레이션까지만 확인하고 대기 표시
2. **수치 튜닝**: 강공격·아이템 수치는 PRD §4.5 + 계획 기본값으로 시작. T20에서 체감 확인 후 PRD §4.5 표 갱신 (README R6)
3. **봇이 너무 잘 막는 문제**: 번갈아 가드로 시작, 영상 확인 후 조정

## 리스크

| 리스크 | 대응 |
|---|---|
| 상태 추가로 Motion이 비대해짐 | 조작 전이는 `Actions`, 잡기는 `Grab`, 아이템은 `Item*`으로 분리 |
| 잡기 풀림 누락으로 영원히 HELD | `Grab.cleanup`을 Combat·Rules 뒤에 매 틱 실행 + 단위 테스트 |
| 리플레이 골든이 태스크마다 깨짐 | 골든 갱신은 커밋 메시지에 이유를 적는 기존 절차(Ruling 8) 유지 |
| 터치 버튼이 경기장 가장자리를 가림 | 레이아웃 3안 비교 때 카메라 프레이밍과 함께 확인 |
