# 문서 지도 — TheBrawlGuys

> 2026-09-28 · 이 폴더의 문서들이 **서로 어떻게 연결되고, 무엇을 소유하며, 변경이 어떻게 전파되는지** 정의한다.

---

## 1. 문서 계층

```
                 PLAN.md  (원본 아이디어, 동결 — 더 이상 수정하지 않음)
                    │ 계승
                    ▼
┌──────────────────────────────────────────┐
│  PRD.md   — 무엇을 · 왜                   │   요구사항 ID: PRD-xxx
│  (제품 요구사항, 규칙, 수치 초기값,        │
│   기술 원칙, 비기능 요구)                  │
└───────────┬───────────────────┬──────────┘
            │ 요구사항 배정       │ 비주얼·UX 요구 위임
            ▼                   ▼
┌──────────────────────┐  ┌──────────────────────────────┐
│  PHASES.md — 언제·순서 │◀─│  design.md — 어떻게 보이고 느껴지나 │
│  (단계, 태스크,        │  │  (디자인 시스템: 토큰·테마·      │
│   완료 기준)           │  │   컴포넌트·비주얼·VFX·게임 필)    │
│  ⚙️ 개발 트랙          │  │  ID: DS-xxx / GD-xxx          │
│  🎨 DS 트랙 ───────────┼─▶│                              │
└──────────┬───────────┘  └──────────────────────────────┘
           │ Phase 시작
           ▼
   dev/active/phase-N/   (실행 중 작업 문서: plan · context · tasks)
           │ 구현
           ▼
   코드 (src/, tests/)  ·  GameConfig  ·  tokens.gd  ·  DS 갤러리
```

| 문서 | 질문 | 소유하는 것 | 소유하지 않는 것 |
|---|---|---|---|
| **PRD.md** | 무엇을, 왜? | 요구사항, 게임 규칙, 수치 **초기값**, 아키텍처 원칙, 비기능 요구, 범위 밖 | 일정, 시각적 표현 |
| **PHASES.md** | 언제, 어떤 순서로, 무엇이 끝나야? | Phase 구성, 태스크, 테스트, 완료 기준, PRD 커버리지 | 요구사항 정의, 디자인 값 |
| **design.md** | 어떻게 보이고·들리고·느껴지나? | 레퍼런스, 디자인 원칙, 토큰, 컴포넌트, 비주얼·VFX·SFX, 게임 필 규칙, 접근성 | 요구사항, 일정 (Phase 번호는 참조만) |
| **dev/active/** | 지금 무엇을 하고 있나? | Phase 실행 세부 계획·결정·진행 | 장기 요구사항 |

---

## 2. 연결 방식 — ID 참조

문서끼리는 **복사하지 않고 ID로 참조**한다.

| ID 형식 | 정의 위치 | 참조하는 곳 |
|---|---|---|
| `PRD-<영역>-<번호>` (예: `PRD-CTL-03`) | PRD.md §12 | PHASES 태스크, design.md 항목·추적표 |
| `DS-<층>-<번호>` (예: `DS-CMP-04`) | design.md | PHASES 🎨 DS 트랙 태스크 |
| `GD-<영역>-<번호>` (예: `GD-FEEL-02`) | design.md §9 | PHASES 태스크, `GameConfig` 주석 |
| Phase 번호 (`Phase 2`) | PHASES.md | design.md 추적표·컴포넌트 표 |

**예시 — 터치 잡기 버튼 하나가 문서를 관통하는 방식**

```
PRD-CTL-03  "터치: 가상 스틱 + 4버튼, 컨텍스트 잡기"          (PRD §3.3 — 무엇·왜)
   ├─▶ PHASES Phase 1 ⚙️ "터치 기본"        [PRD-CTL-03]      (언제 — 기본)
   ├─▶ PHASES Phase 2 ⚙️ "터치 4버튼"        [PRD-CTL-03]      (언제 — 완성)
   │     └─ 🎨 "TouchButton v2 highlight"    [DS-CMP-04]
   │     └─ 🎨 🖼 "4버튼 레이아웃 3안 비교"     [DS-LAY-01]
   └─▶ design DS-CMP-04 TouchButton (상태: idle·pressed·highlight…, 근거 PRD-CTL-03, Phase 1·2)
       design DS-LAY-01 터치 레이아웃 (호 배치 초안, 근거 PRD-CTL-03, Phase 2 🖼)
          └─▶ 코드: src/ui/components/touch_button/  ·  tokens.gd  ·  DS 갤러리
```

---

## 3. 추적 규칙

| # | 규칙 | 확인 방법 |
|---|---|---|
| R1 | PHASES의 모든 태스크는 근거 ID(`PRD-`, `DS-`, `GD-`)를 최소 1개 단다. 환경 설정 같은 순수 작업만 예외 | 리뷰 시 확인 |
| R2 | design.md의 모든 `DS-`/`GD-` 항목은 근거 `PRD-` ID와 Phase를 명시한다 (design.md §12 추적표) | 추적표에 빈 칸 없음 |
| R3 | PRD의 모든 요구사항 ID는 적어도 한 Phase에 배정된다 (PHASES.md 부록 커버리지 표) | 커버리지 표에 빠진 ID 없음 |
| R4 | PHASES에서 참조하는 `DS-`/`GD-` ID는 반드시 design.md에 정의되어 있다 | 아래 §5 검사 스크립트 |
| R5 | ID는 한 번 부여하면 바꾸지 않는다. 폐기 시 ~~취소선~~ 처리하고 번호를 재사용하지 않는다 | — |
| R6 | 수치는 한 곳에만 둔다: 규칙·초기값은 PRD, 런타임 값은 `GameConfig`, 시각 값은 `tokens.gd`. 문서에 같은 값을 두 번 적지 않는다 | — |
| R7 | design.md의 **(초안)** 항목은 PHASES의 🖼 게이트(시안 비교 + 승인)를 거쳐야 확정된다 | 🖼 태스크 체크 = 초안 표시 제거 |

---

## 4. 변경 전파

변경은 **위에서 아래로** 흐른다. 아래 문서가 위 문서와 충돌하면 위 문서가 이긴다 (PRD > PHASES / design > dev/active > 코드).

| 무엇이 바뀌었나 | 업데이트 순서 |
|---|---|
| 요구사항 추가·변경 | ① PRD 본문 + §12 ID → ② PHASES 커버리지 표·태스크 → ③ (비주얼 영향 시) design.md 항목·추적표 |
| 디자인 결정 (🖼 확정 포함) | ① design.md 값·버전 → ② `tokens.gd` / 글로벌 셰이더 파라미터 → ③ 추적표 상태 → (PRD 영향 없음) |
| 일정·순서 변경 | ① PHASES만 → ② design.md 추적표·컴포넌트 표의 Phase 번호 |
| 구현 중 발견한 문제 | ① `dev/active/phase-N/context.md`에 기록 → ② 요구사항 수준이면 PRD로 올림 (위 순서) |
| Phase 완료 | ① PHASES 체크박스 → ② design.md 추적표 상태 ✅ + 버전 `0.N` → ③ `dev/active/phase-N` → `dev/done/`로 이동 |

---

## 5. 정합성 검사

PHASES에서 참조한 ID가 모두 정의되어 있는지 확인한다 (R3·R4).

```bash
cd docs
# PHASES가 참조하는 DS/GD ID 중 design.md에 없는 것
grep -oE '(DS|GD)-[A-Z0-9]+-[0-9]+' PHASES.md | sort -u | while read id; do grep -q "$id" design.md || echo "undefined: $id"; done
# PRD §12의 ID 중 PHASES에 한 번도 등장하지 않는 것 (범위 표기 PRD-XXX-01~04 포함)
grep -oE '^\| PRD-[A-Z]+-[0-9]+' PRD.md | tr -d '| ' | while read id; do
  area=${id%-*}; grep -qE "$id|$area-[0-9]+~" PHASES.md || echo "uncovered: $id"; done
```

Phase 0에서 이 검사를 `scripts/check-docs.sh`로 옮겨 Phase 공통 완료 체크에 포함한다.
