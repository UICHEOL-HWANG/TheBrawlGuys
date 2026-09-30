# TheBrawlGuys — 디자인 시스템

> 버전 0.6 · 2026-09-30 (0.6+: Phase 4.0 계획 — LoginPanel 초안, 메뉴 디오라마 배경) (0.6: Phase 3 — 캐릭터·애니·VFX·SFX·BGM·품질 단계·모션 토큰) (0.5: Phase 2 — 터치 v2·차지 게이지·가드 버블·아이템 표시) (0.4: Phase 1 HUD·터치·타격감 v1) (0.3: Phase 0 완료 — 토큰·테마·갤러리) (0.2: 팔레트 A안 확정)
> 상위: [`PRD.md`](./PRD.md) (요구사항) · 일정: [`PHASES.md`](./PHASES.md) (🎨 DS 트랙) · 문서 규칙: [`README.md`](./README.md)
>
> 이 문서는 **어떻게 보이고, 들리고, 느껴지는지**를 소유한다.
> 각 항목은 `DS-xxx`(디자인 시스템) 또는 `GD-xxx`(게임 필) ID를 가지며, 근거가 되는 `PRD-xxx`와 만들어지는 Phase를 명시한다 (§12 추적표).
>
> ⚠️ **(초안)** 표시 항목은 PHASES.md의 🖼 시각 비교 게이트에서 확정한다. 확정되면 표시를 지우고 버전을 올린다.

---

## 0. 비주얼 레퍼런스

**레퍼런스 A — "햇살 드는 숲 디오라마"** (사용자 제공, 2026-09-28)
→ 원본 이미지는 `docs/references/ref-a-sunny-forest.png`에 보관한다.

| 관찰 | 우리 게임에서의 규칙 |
|---|---|
| 외곽선이 전혀 없다 | 3D 월드에 잉크 외곽선을 쓰지 않는다. 형태는 **명암 대비와 색 덩어리**로 구분 |
| 나무·덤불이 **구를 여러 개 뭉친 뭉게 형태** | 식생은 모두 "구 클러스터" 문법. 각진 로우폴리 금지 |
| 2단 부드러운 명암, 그림자가 **초록·청록으로 물든** 반투명 | 검은 그림자 금지. 그림자는 바닥색을 어둡고 푸르게 한 색 |
| 라임 잔디 위 **청록 나무**, 선명한 **파랑 물** | 3색 축: 연두(바닥) · 청록(구조물) · 파랑(물·링아웃) |
| 분홍·파랑·노랑 **꽃 점**, 보라 열매가 흩뿌려짐 | 바닥은 작은 색점으로 리듬을 준다 (디테일은 작고 많게) |
| 매끈한 **크림색 달걀 바위**, 옅은 반점 | 큰 소품은 단순한 곡면 + 작은 반점 텍스처 |
| 따뜻한 **햇빛 블룸**, 캠프파이어 주황 발광 | 발광원은 블룸으로 부드럽게 번진다. 전체 톤은 따뜻한 한낮 |
| 높은 부감, 거의 탑다운 | 카메라 피치를 높게(약 60°) → 원형 경기장이 한눈에 |
| 장난감 같은 스케일감 | "손바닥 위 디오라마": 소프트 AO, 살짝 채도 높은 파스텔 |

**한 줄 정의**: *외곽선 없는 부드러운 툰 셰이딩, 뭉게뭉게 둥근 형태, 햇살 드는 연두·청록 숲 디오라마.*

---

## 1. 디자인 원칙

| # | 원칙 | 의미 | 판단 예시 |
|---|---|---|---|
| 1 | **전투가 먼저 읽힌다** | 누가 어디 있고, 얼마나 위험한지가 장식보다 우선 | 외곽선 대신 캐릭터는 바닥보다 밝고 채도 높게 + 림 라이트 |
| 2 | **맞으면 과장한다** | 넉백이 클수록 화면·소리·이펙트가 모두 커진다 | 이펙트 강도는 넉백 크기의 함수 |
| 3 | **둥글고 말랑하다** | 모든 형태는 구·캡슐·둥근 모서리. 날카로운 각 없음 | UI도 알약·둥근 카드. 이펙트도 동그란 퍼프 |
| 4 | **빛이 따뜻하다** | 한낮 햇살, 색이 있는 그림자, 부드러운 블룸 | 검정(#000) 사용 금지. 가장 어두운 색은 짙은 청록 |
| 5 | **엄지가 먼저** | 모바일 가로 화면, 양손 엄지 기준 배치 | 조작 UI는 하단, 정보 UI는 상단 |
| 6 | **토큰으로만 그린다** | 색·크기·모션은 토큰에서만 가져온다 | 코드에 `Color(...)` 직접 작성 금지 |

---

## 2. 시스템 구조

```
┌──────────────────────── 디자인 시스템 ────────────────────────┐
│                                                                │
│  ① 토큰 (DS-TOK)        tokens.gd  ─┬─▶ ② 테마 (DS-THM)        │
│     색·타이포·간격·        (단일 원천) │     forest_theme.tres    │
│     반경·모션·아이콘                  │     ArenaData.theme 변형 │
│                                      │          │               │
│                                      │          ▼               │
│                                      │   ③ 컴포넌트 (DS-CMP)    │
│                                      │     src/ui/components/   │
│                                      │          │               │
│                                      │          ▼               │
│                                      │   ④ 레이아웃 (DS-LAY)    │
│                                      │     HUD·터치·화면 흐름   │
│                                      │                          │
│                                      └─▶ ⑤ 비주얼 (DS-VIS)      │
│                                            글로벌 셰이더 유니폼  │
│                                            소프트 툰·식생·식별   │
│                                                 │               │
│  ⑦ 게임 필 (GD) ── 강도 파라미터 ──▶ ⑥ VFX/SFX (DS-VFX/SFX)    │
│     GameConfig 값                                               │
│                                                                │
│  ⑧ 접근성 (DS-A11Y)   ⑨ 거버넌스 (DS-GOV): 갤러리·검사·버전     │
└────────────────────────────────────────────────────────────────┘
```

### 2.1 Godot 구현 매핑

| 층 | 파일 | 규칙 |
|---|---|---|
| 토큰 | `src/ui/theme/tokens.gd` (`class_name DS`, `const`만) | 색·수치의 유일한 원천 |
| 테마 | `src/ui/theme/theme_builder.gd` → `forest_theme.tres` | 토큰에서 Theme을 생성하는 `@tool` 스크립트. `.tres`를 손으로 고치지 않는다 |
| 3D 비주얼 토큰 | Project Settings › Global Shader Parameters (`ds_shadow_tint`, `ds_band_softness` 등) | 모든 월드 셰이더가 글로벌 유니폼을 읽는다 |
| 컴포넌트 | `src/ui/components/<name>/<name>.tscn + .gd` | 자기 크기·색을 하드코딩하지 않고 테마/토큰 참조 |
| 갤러리 | `src/debug/ds_gallery.tscn` | 모든 토큰·컴포넌트·셰이더 샘플·VFX·SFX 전시 (스토리북 역할) |

### 2.2 값의 소유권

| 종류 | 원천 | 예 |
|---|---|---|
| 모양·색·크기·모션 | **design.md → `tokens.gd` / 글로벌 셰이더 파라미터** | 대미지 숫자 크기, 그림자 색 |
| 조작감·타격감 수치 | **PRD → `GameConfig`** (디버그 패널 튜닝) | hitstop 시간, 흔들림 배율 |
| GD 항목 | 동작 규칙은 design.md, 수치는 `GameConfig` | "흔들림 = 넉백 × 배율"의 규칙은 여기, 배율 값은 GameConfig |

---

## 3. 토큰 (DS-TOK)

### DS-TOK-01 색상 ✅ 확정 (2026-09-28)

> 결정: 🖼 3안 비교(A 한낮 햇살 / B 황금빛 오후 / C 파스텔 봄)에서 **A안 채택**. 레퍼런스 A에 가장 가깝고, 연두–청록 대비가 커서 전투 가독성(원칙 1)이 가장 좋다.
> B안 값은 버섯 숲 테마 변형(DS-THM-02)의 후보로 남겨 둔다: grass `#BFD35A` · shade `#6E8A3A` · canopy `#3E8A6A` · fire `#FF8A2A`.

**월드 팔레트**

| 토큰 | 값 | 용도 |
|---|---|---|
| `grass_sun` | `#D6EE7C` | 햇빛 받은 잔디 하이라이트 |
| `grass` | `#A5D65A` | 경기장 바닥 기본 |
| `grass_mid` | `#7CC04B` | 덤불 밝은 면 |
| `grass_shade` | `#4F9A48` | 바닥 위 그림자 (반투명으로 곱해짐) |
| `canopy` | `#2E8C86` | 청록 나무·구조물 |
| `canopy_deep` | `#17525A` | 가장 어두운 색 = UI 글자색 (검정 대신) |
| `water` | `#3A9FE3` | 호수·링아웃 영역 |
| `water_deep` | `#2A72C9` | 물 깊은 곳 |
| `stone_cream` | `#F3EEE7` | 큰 바위·소품 밝은 면 |
| `stone_shade` | `#BDB1AC` | 바위 그림자면 (라벤더 회색) |
| `bark` | `#6C5A66` | 나무 기둥 (보랏빛 회갈색) |
| `dirt` | `#8A6B55` | 경기장 가장자리 흙 단면 (DS-VIS-04) |
| `sky` | `#C4E8F6` | 하늘·원경 |

**포인트 색** (꽃 점·아이템·이펙트)

| 토큰 | 값 | 용도 |
|---|---|---|
| `petal_pink` | `#F27DB6` | 꽃, 긍정 이펙트 |
| `petal_blue` | `#3E6FE3` | 꽃, 정보 |
| `petal_yellow` | `#F5D53D` | 꽃, 하이라이트·컨텍스트 강조 |
| `berry` | `#7B5AD8` | 보라 열매, 특수 |
| `fire` | `#FF9A2E` | 캠프파이어, 주 강조(CTA) |
| `glow` | `#FFF3C4` | 블룸·발광 중심 |
| `danger` | `#F0584A` | 위험·경고 |
| `impact_core` | `#FFFBEA` | 코믹 임팩트 별 심지·충격 링 (DS-VFX-01 v2) |
| `hit_flash` | `#FFFFFF` | 피격자 흰색 플래시 덮개 (DS-VFX-08) |
| `screen_flash` | `glow` 24% | 강타 화면 플래시 (DS-VFX-01 v2) |
| `clang` | `#8FD0FF` | 가드 클랭 링 (DS-VFX-07) |

**UI 팔레트**

| 토큰 | 값 | 용도 |
|---|---|---|
| `ui_surface` | `#FFFDF6` | 패널·카드 바탕 (크림 화이트) |
| `ui_surface_dim` | `#EAF2DC` | 비활성·보조 면 (연두 기운) |
| `ui_surface_50` | `#FFFDF6` 50% | 가상 스틱 바탕 |
| `ui_surface_70` | `#FFFDF6` 70% | 터치 버튼 바탕 |
| `ui_text` | = `canopy_deep` | 본문 글자 |
| `ui_text_soft` | `#3F7470` | 보조 글자 (크림 바탕 대비 5.2:1, WCAG AA) |
| `ui_shadow` | `canopy_deep` 25% | 패널 그림자 |
| `ui_accent` | = `fire` | 주 버튼 |
| `haze` | `#DAD9CB` | 메뉴 배경 안개·헤이즈 (따뜻한 연회색-세이지, DS-LAY-03) |
| `glass_tint` | `#B9C9B0` | 로그인 유리 카드 틴트 (DS-CMP-14) |
| `glass_edge` | `#F4F7EE` 70% | 유리 카드 가는 테두리 |
| `text_shadow` | `canopy_deep` 35% | 장면 위 흰 제목·글자의 부드러운 그림자 |
| `google_blue/red/yellow/green` | `#4285F4` / `#EA4335` / `#FBBC05` / `#34A853` | **Google "G" 마크 전용** (브랜드 규정). 다른 곳에 쓰지 않는다 |

**플레이어 색** — 연두 바닥 위에서 잘 보이는 색으로 선정. 색만으로 구분하지 않는다 (DS-VIS-03 모양과 항상 짝)

| 토큰 | 값 | 모양 |
|---|---|---|
| `p1` | `#3E7BF0` | ● 원 |
| `p2` | `#F25C5C` | ▲ 삼각 |
| `p3` | `#FFC93C` | ■ 사각 |
| `p4` | `#B46CF0` | ◆ 마름모 |

> 초록 계열 플레이어 색은 바닥과 겹치므로 쓰지 않는다 (P4 = 보라).

**대미지 램프** — `DamageCounter`가 %에 따라 보간

| % | 0 | 50 | 100 | 150+ |
|---|---|---|---|---|
| 색 | `ui_surface` | `petal_yellow` | `fire` | `danger` |

### DS-TOK-02 타이포그래피 (초안)

| 토큰 | 폰트 | 크기 (1920×1080 기준) | 용도 |
|---|---|---|---|
| `display_xl` | Jua (OFL) | 96 | 대미지 % |
| `display_l` | Jua | 64 | 승패 배너, 카운트다운 |
| `title` | Jua | 40 | 화면 제목, 카드 이름 |
| `body` | Pretendard SemiBold (OFL) | 28 | 설명, 버튼 라벨 |
| `caption` | Pretendard Medium | 22 | 보조 정보, 핑 |

- 월드 위에 뜨는 글자(대미지 %, 라벨)는 검정 외곽선 대신 **`canopy_deep` 3px 외곽선 + 부드러운 그림자**
- 프로젝트 기준 해상도 1920×1080, Stretch Mode `canvas_items`, Aspect `expand`

### DS-TOK-03 간격

4 기반 스케일: `s1 4` · `s2 8` · `s3 12` · `s4 16` · `s5 24` · `s6 32` · `s7 48` · `s8 64`

메뉴 크기 (1920×1080): `button_min_width 400` · `button_height 80` (MenuButton) · `login_card_width 560` (DS-CMP-14) · `tracking_wide 4` (자간 넓힌 태그라인) · `field_height 72` (TextField, DS-CMP-17) · `code_box 56×72` (CodeInput 한 칸, DS-CMP-18)

유리·헤이즈 강도 (0~1): `glass_tint_strength 0.5` (Compatibility·웹은 블러 대신 `0.82`) · `glass_blur_lod 3.5` · `haze_amount 0.34` · `haze_desaturate 0.4`

### DS-TOK-04 반경·선·그림자

| 토큰 | 값 |
|---|---|
| `radius_s / m / l / pill` | 12 / 20 / 32 / 999 — 레퍼런스의 둥근 형태에 맞춰 크게 |
| `radius_xl` | 40 — 로그인 유리 카드 (DS-CMP-14) |
| `stroke_none` | UI 기본은 선 없음 |
| `stroke_focus` | 4px `petal_yellow` (포커스·선택 표시에만) |
| `shadow_soft` | 오프셋 (0, 8), 블러 16, `ui_shadow` — 떠 있는 말랑한 느낌 |
| `shadow_pressed` | 오프셋 (0, 2), 블러 4 |

### DS-TOK-05 모션

| 토큰 | 시간 | 이징 | 용도 |
|---|---|---|---|
| `motion_fast` | 0.08s | out-quad | 버튼 눌림 |
| `motion_base` | 0.18s | out-quad | 패널 전환 |
| `motion_squish` | 0.28s | out-elastic (약) | 숫자 튀어오름, 배너 등장 — 말랑한 스쿼시 |
| `motion_slow` | 0.40s | in-out-cubic | 화면 전환 |
| `motion_calm` | 0.70s | out-sine | 차분한 메뉴 등장 — 헤이즈 걷힘, 로그인 카드 떠오름 (튀지 않음) |

- 버튼 눌림: 스케일 (1.04, 0.92) 스쿼시 → `shadow_pressed`로 전환 → 뗄 때 탄성 복귀 — 토큰 `PRESS_SQUISH`

### DS-TOK-06 아이콘

- 64×64 그리드, 둥근 끝 선(굵기 6) 또는 평면 채색 덩어리. 날카로운 모서리 금지
- 색은 `ui_text` 단색 기본, 상태에 따라 포인트 색
- 세트: 터치 버튼(점프·공격·가드·잡기), 아이템 3종, 스타일 3종, 입력 장치 프롬프트(키보드·Xbox·PS), 경기장 기믹

---

## 4. 테마 (DS-THM)

### DS-THM-01 기본 테마 `forest_theme.tres`

토큰에서 생성한다. Button, Label, Panel, LineEdit, ProgressBar의 기본 StyleBox는 `ui_surface` 바탕 + `radius_l` + `shadow_soft`, 선 없음. 포커스일 때만 `stroke_focus`.

### DS-THM-02 경기장 테마 변형

`ArenaData.theme`이 **3D 환경만** 덮어쓴다 (UI 색은 공통 → 경기장이 바뀌어도 HUD는 똑같이 읽힘). 기본은 레퍼런스 A의 한낮이고, 경기장마다 시간대·색온도를 바꾼다.

| 경기장 | 조명 | 바닥 | 하늘·대기 |
|---|---|---|---|
| 호숫가 캠프장 | 레퍼런스 A 그대로: 따뜻한 한낮 + 캠프파이어 발광 | `grass` | `sky`, 물 반짝임 |
| 통나무 다리 | 밝은 낮, 그림자 짧게 | `bark` 통나무 + 아래 `water` | 옅은 하늘 |
| 버섯 숲 | 늦은 오후 황금빛, 버섯 자체 발광(`petal_pink`·`berry`) | 채도 낮춘 `grass_mid` | 황금 블룸 |
| 안개 낀 숲 | 이른 아침 차가운 빛 | 회녹색 | `sky` 안개, 주기적으로 짙어짐 |

구현 (Phase 4 T6, 2026-09-30): `ArenaTheme`(src/render/arena/arena_theme.gd, 경기장당 테마 파일 1개)이 `EnvironmentRig.apply_theme()`로 하늘·환경광·태양 색·각도·세기 배율·블룸 배율·기본 안개를 바꾼다. 색은 아래 테마 전용 토큰만 쓴다 (UI에는 쓰지 않는다). 안개 기믹 중에는 `EnvironmentRig.set_fog_boost()`가 거리 안개를 더 짙게 하고, 메뉴 배경은 `hold_fog()`로 헤이즈 안개를 테마 위에 고정한다. Compatibility(웹)은 반투명·안개가 더 진하게 섞여 측정한 배율로 낮춘다.

| 토큰 | 값 | 용도 |
|---|---|---|
| `sky_pale` | `#DDF1F8` | 통나무 다리 옅은 하늘 |
| `grass_dusk` / `grass_gold` / `canopy_gold` | `#98B25C` / `#BFD35A` / `#3E8A6A` | 버섯 숲 바닥·덤불·나무 (DS-TOK-01 B안 값) |
| `sun_gold` / `sky_gold` | `#FFD89A` / `#F4E3B5` | 버섯 숲 늦은 오후 햇빛·하늘 |
| `grass_mist` / `grass_mist_deep` / `canopy_mist` | `#9CB79A` / `#7E9C80` / `#4E7F78` | 안개 낀 숲 회녹색 바닥·바깥·침엽수 |
| `sun_cool` / `fog_mist` | `#E6F2F7` / `#DCEBEF` | 안개 낀 숲 아침 햇빛·안개 색 |
| `fog_veil` | `fog_mist` 55% | 안개가 낄 때 경기장 위 안개 층 |

---

## 5. 레이아웃 (DS-LAY)

### DS-LAY-01 터치 레이아웃 (초안 — Phase 2 🖼 게이트에서 3안 비교)

```
┌─────────────────────────────────────────────────────────────┐
│ safe area                                                    │
│                                                              │
│                                                  (잡기)      │
│   ┌ ─ ─ ─ ─ ┐                            (가드)   ◯          │
│     ( ● )     ← 좌측 40% 어디든 터치하면       ◯   (공격)     │
│   └ ─ ─ ─ ─ ┘    그 자리가 스틱 중심                ⬤        │
│                                            (점프)            │
│                                              ◯               │
└─────────────────────────────────────────────────────────────┘
```

| 요소 | 규칙 |
|---|---|
| 스틱 영역 | 화면 좌측 40% × 하단 70%. 플로팅, 반경 `touch_stick_radius` |
| 공격 | 가장 큰 버튼 (지름 = 기준 × 1.3), 엄지 휴식 위치 |
| 점프·가드·잡기 | 공격 주위 호(arc) 배치, 지름 ≥ 48dp |
| 버튼 모양 | `ui_surface` 70% 반투명 원 + `shadow_soft`, 아이콘 `ui_text` |
| 잡기 | 기본 60% 투명 → 대상이 있으면 `petal_yellow` 링 + 말랑한 펄스 (DS-CMP-04 highlight) |
| 비교 시안 | A 호 배치 / B 다이아몬드 / C 2×2 격자 |

### DS-LAY-02 HUD 레이아웃

- 정보는 **상단**, 조작은 **하단** (원칙 5)
- `DamageCounter`는 상단 가장자리에 플레이어 수만큼 균등 배치 (1:1은 좌우 끝, 4인은 4등분)
- 일시정지 버튼: 우상단, 터치 영역 48dp
- 모든 HUD는 safe area 안쪽 `s5` 여백

### DS-LAY-03 화면 흐름

```
로그인 ─▶ 타이틀/모드 선택 ─┬─ 봇전 ─────────────────┐
  (세션 있으면 건너뜀)       ├─ 로컬 2인 ──────────────┼─▶ 캐릭터 선택 ─▶ 경기장 선택 ─▶ 대전 ─▶ 결과
                           └─ 온라인 ─▶ 로비(방 코드) ┘                                ▲        │
                                                                                     └─ 다시 ─┘
설정 (어디서든 진입): 접근성 · 조작 편집 · 사운드
```

**메뉴 배경 — 궤도 디오라마** (`MenuBackdrop`, Phase 4.0, 근거 PRD-AUTH-01 · PRD-UI-02)

로그인부터 경기장 선택까지 모든 메뉴 화면 뒤에 같은 배경이 깔린다. 첫인상에서 "치고받고 날아가는 게임"이 바로 보이게 하는 것이 목적이다.

| 요소 | 규칙 |
|---|---|
| 장면 | 실제 경기장(`ArenaView`·장식·`EnvironmentRig`) 위에서 봇 4명이 `BotController`로 난투한다. 링아웃·리스폰까지 실제 규칙 그대로 (sim 재사용) |
| 카메라 | 대전 카메라보다 **낮은 3/4 시점**(pitch 24°)으로 장면 안에서 바라보며 천천히 yaw 회전한다. 거리는 `CameraFraming`으로 경기장 중심부(반경의 50%)를 맞추고, 회전축은 난투 중심을 천천히 따라간다. 화면마다 비워 둔 영역(NDC focus)으로 난투를 옮긴다 (로그인: 카드 오른쪽 아래). 값은 GameConfig Camera 그룹 `menu_orbit_*` |
| 전경 가독성 | 배경은 전경 UI보다 한 단계 가라앉힌다: `haze` 색 거리 안개 + 전체 화면 헤이즈(채도 40% 낮춤, `haze` 34% 덮기). 첫 화면은 헤이즈에서 서서히 드러난다 (`motion_calm`) |
| 식별 | 메뉴 배경에는 P1~P4 라벨·발밑 링을 숨긴다 (HUD 정체성 없음) |
| 사운드 | 메뉴 BGM 변주(`DS-SFX-02`)만. 배경 난투의 타격 SFX는 줄이거나 끈다 |
| 성능 | 현재 품질 설정을 그대로 따르고, 품질 LOW에서도 60fps |
| 전환 | 메뉴 화면이 바뀌어도 배경은 끊기지 않는다. 대전 진입 시 배경을 멈추고 대전 씬으로 교체 |

### DS-LAY-04 모바일 반응형 스케일 · 세로 안내 (2026-09-30)

기준 해상도 1920×1080 + `canvas_items`/`expand`만으로는 폰 가로(812×375 CSS px)에서 2D UI 전체가 약 0.35배로 줄어 캡션이 7 CSS px가 된다. 그래서 **2D 캔버스만** 창 크기에 맞춰 키운다 (`Window.content_scale_factor`, 3D 뷰는 그대로 창을 채운다). 글자를 다시 줄여 맞추지 않는다.

| 요소 | 규칙 |
|---|---|
| 뷰포트 분류 | CSS px(웹 = 창 픽셀 ÷ devicePixelRatio, 네이티브 = 포인트) 기준 짧은 변 < `PHONE_MAX_SHORT_CSS` 500 → phone, 터치 + 짧은 변 < `TABLET_MAX_SHORT_CSS` 1100 → tablet, 나머지 desktop |
| 배율 | desktop은 항상 **1.0** (기존 모습 그대로). phone은 가장 작은 캡션(`caption` 22)이 `CAPTION_MIN_PHONE_CSS` 12 CSS px, tablet은 `CAPTION_MIN_TABLET_CSS` 13이 되도록, 터치 기기는 가장 작은 버튼(`TOUCH_TARGET_BASE_MIN` 96)이 `TOUCH_TARGET_MIN_CSS` 44 이상이 되도록 한다. 0.05 단위 올림, 상한 `UI_SCALE_MAX` 3.0 |
| 확정 값 | 812×375 · 667×375 → **1.6** · 740×360 → **1.65** · 1024×768 터치 → **1.15** · 1280×720 · 1920×1080 · 1024×768(터치 없음) → **1.0** · 375×812 세로 → 2.8 (안내만 보임) |
| 다시 계산 | 시작할 때와 창 크기·방향이 바뀔 때마다 (`UiScaler` 오토로드) |
| 넘칠 때 | 화면 가운데 블록(로그인 카드 등)은 `FitCenter`로 감싼다: 들어가면 가운데, 안 들어가면 세로 스크롤 |
| 세로 안내 | 터치 기기가 세로면 전체 화면 `haze` 위 `Panel`에 코드로 그린 회전 아이콘(`ui_text` 폰 윤곽 + `fire` 곡선 화살표, `motion_slow`로 기울기) · "가로로 돌려주세요"(`display_l`) · 안내(`body`, `ui_text_soft`). 떠 있는 동안 아래 입력을 모두 막고, 첫 탭에 전체 화면 + `screen.orientation.lock("landscape")`를 시도한다(실패는 무시, iOS Safari 미지원). 네이티브는 가로 고정이라 뜨지 않는다 |
| 터치 감지 | `DisplayServer.is_touchscreen_available()`, 웹은 `ontouchstart`·`maxTouchPoints` JS 폴백. 터치면 터치 컨트롤이 보이고 `KeyHintBar`는 숨는다 |
| 트래킹 | 전역 속성 `viewport_class`·`orientation`·`ui_scale` (tracking-plan.md §2) |

---

## 6. 컴포넌트 (DS-CMP)

| ID | 컴포넌트 | 목적 | 상태 | 주요 토큰 | Phase | 근거 |
|---|---|---|---|---|---|---|
| DS-CMP-01 | `DamageCounter` | 플레이어 대미지 % 표시 | 기본 · 피격(흔들림+스쿼시) · KO(흐림) · 리스폰 | `display_xl`, 대미지 램프, `motion_squish` | 1 | PRD-UI-01, PRD-RULE-01 |
| DS-CMP-02 | `StockIcons` | 남은 스톡 | 채움 · 소모(톡 터지는 애니) | 플레이어 색+모양 | 1 | PRD-UI-01, PRD-RULE-02 |
| DS-CMP-03 | `TouchStick` | 이동 입력 | 숨김 · 활성(중심·노브) · 데드존 | `ui_surface` 50%, `shadow_soft` | 1 | PRD-CTL-03 |
| DS-CMP-04 | `TouchButton` | 액션 입력 | idle · pressed · highlight · disabled · charging | 아이콘, `petal_yellow`, `motion_fast` | 1 (v1), 2 (v2) | PRD-CTL-03, PRD-CTL-04 |
| DS-CMP-05 | `ChargeGauge` | 강공격 차지량 (월드 공간) | 차지 중 · 최대(반짝) | `petal_yellow` → `fire`, `glow` | 2 | PRD-CMB-02 |
| DS-CMP-06 | `MenuButton` (`UiMenuButton`) | 메뉴 조작 | idle · focus(호버 포함) · pressed · disabled | `ui_accent`(primary) / `ui_surface`(secondary) / 투명 + `ui_surface` 70% 테두리 + 흰 글자(ghost, 유리 카드 위 보조 동작), `radius_pill`, `stroke_focus`, `PRESS_SQUISH` | 4.0 | PRD-UI-02 |
| DS-CMP-07 | `Panel` (`UiPanel`) | 메뉴·설정 컨테이너 | 기본 | `ui_surface`, `radius_l`, `shadow_soft` | 4.0 | PRD-UI-02 |
| DS-CMP-08 | `SelectCard` | 경기장·캐릭터 선택 | idle · focus · selected · locked | `title`, 디오라마 썸네일, 플레이어 색 링 | 4, 5 | PRD-UI-02 |
| DS-CMP-09 | `ResultBanner` | 승패·재시작 | 승리 · 패배 · 무승부 | `display_l`, `motion_squish`, 꽃잎 파티클 | 1 | PRD-UI-01 |
| DS-CMP-10 | `PlayerSlot` | 참가자 표시 | 비어있음 · 선택 중 · 준비 · 연결 끊김 | 플레이어 색+모양 | 5, 6 | PRD-LOCAL-01, PRD-NET-03 |
| DS-CMP-11 | `RoomCodeInput` | 방 코드 입력 | 입력 · 오류 · 확인 중 | `display_l`, 글자별 둥근 칸 | 6 | PRD-NET-03 |
| DS-CMP-12 | `DebugPanel` | GameConfig 튜닝 | — (개발용, DS 예외: 기본 Godot 스타일 허용) | — | 0 | PRD-CFG-01 |
| DS-CMP-13 | `Toast` / `ConnectionIndicator` | 알림, 핑 | 정보 · 경고 · 오류 / 좋음 · 보통 · 나쁨 | `caption`, `grass_mid`/`petal_yellow`/`danger` | 6 | PRD-NET-02 |
| DS-CMP-14 | `LoginPanel` | 첫 화면 로그인 (Google · 이메일 코드) | idle · loading(브라우저 대기) · error(재시도) / 모드: methods · email(이메일 단계 → 코드 단계) | 유리 카드(`glass_tint`, `glass_edge`, `radius_xl`), `CrestLogo`, `display_l` 흰 제목 + `text_shadow`, `MenuButton`(Google, secondary) + "G"(`google_*`), `MenuButton`(이메일, ghost), `TextField`·`CodeInput`, `motion_calm` 등장, 모드 전환 `motion_base` 페이드 | 4.0 | PRD-AUTH-01 |
| DS-CMP-15 | `CrestLogo` | 게임 크레스트 (로고 콘셉트 C) — **엠블럼만, 글자 없음** | idle · animated(불꽃 깜빡임, `motion_base`) | 방패 `canopy_deep`/안쪽 `canopy`, 방망이 `bark` 손잡이·`dirt` 몸통(-40°), 돌 막대 `stone_shade`(+40°), 폭탄 `canopy_deep`·하이라이트 `ui_text_soft`·심지 `dirt`·불꽃 별 `fire`. 코드로 그려 크기 자유, 기본 `s8`×2 | 4.0 | PRD-AUTH-01, PRD-UI-02 |
| DS-CMP-16 | `KeyHintBar` | 대전 중 키보드 조작 안내 (하단 반투명 키 바) — 누른 키가 색으로 켜진다 | 바: shown · hidden(칩만 남음) / 키캡: idle · pressed | 키캡 `ui_surface` 70% + `ui_shadow` 아랫단, 바 `ui_surface` 50% `radius_l`, 누름 = 플레이어 색(P1 `p1`) 채움 + `PRESS_SQUISH`(`motion_fast`) → 뗄 때 `motion_base` 페이드·`motion_squish` 복귀, 캡션 `caption`, 칩 👁 코드 아이콘 + "키 숨기기/키 보기" | 4 | PRD-CTL-02, PRD-UI-01 |
| DS-CMP-17 | `TextField` (`UiTextField`) | 짧은 텍스트 입력 (로그인 이메일) | idle · focus(호버 포함) · error(다시 입력하면 해제) · disabled | `ui_surface` 바탕, `radius_m`, `body` `ui_text`, placeholder `ui_text_soft`, 포커스 `stroke_focus` `petal_yellow`, 오류 `stroke_focus` `danger`, `shadow_pressed`, 높이 `field_height`. 모바일 키보드 힌트는 호출자가 지정(이메일) | 4.0 | PRD-AUTH-01 |
| DS-CMP-18 | `CodeInput` | 6자리 인증코드 입력 | idle · focus(다음 칸 링) · error(모든 칸 `danger` 링) · disabled | 숫자 칸 6개 `code_box`(`ui_surface`, `radius_s`, 간격 `s3`), 숫자 `title` 크기 `ui_text`. 숨은 LineEdit가 입력·붙여넣기·숫자 키보드(모바일)를 받고 숫자만 최대 6자리 남긴다 | 4.0 | PRD-AUTH-01 |

`SelectCard` 구현 (Phase 4 T7, 2026-09-30): `ui_surface` 카드(`radius_l`, `shadow_soft`, 너비 `card_width` 320) 안에 코드로 그린 위에서 본 디오라마 썸네일(`ArenaThumb`, 높이 `card_thumb_height` 200: 바깥 초원·링아웃 물·흙 띠 위 바닥·나무 고리·기믹 표시, 경기장 테마 색) · `title` 이름 · `caption` 한 줄 설명(`ui_text_soft`) · 기믹 아이콘(`GimmickIcon` `card_icon` 48: 물·불·균열·튕김·안개). focus = `petal_yellow` 링 + ×1.04, selected = `ring_color` 링(경기장은 `ui_accent`, Phase 5 캐릭터는 플레이어 색) + ×1.07, locked = `ui_surface_dim` + "준비 중". 경기장 선택 화면: 제목 위, 카드 4장 아래 한 줄, "뒤로" + 조작 안내(←/→ · Z/Enter · X/Esc), 호버 = 포커스, 클릭·탭 = 확정

`LoginPanel` 확정 (2026-09-30, 레퍼런스 [`references/ref-login-calmforest.webp`](./references/ref-login-calmforest.webp) — 사용자의 이전 프로젝트 calm forest):
- 헤이즈 낀 궤도 디오라마(`DS-LAY-03`) 위, 화면 **정중앙에 반투명 유리 카드** 하나. 카드는 뒤 장면을 흐리게 비추고(스크린 텍스처 밉맵 블러) 세이지 틴트를 덮는다. Compatibility 렌더러(웹)에서는 블러 대신 틴트를 진하게 한다
- 카드 내용(위→아래, 가운데 정렬): 크레스트 로고(`CrestLogo` DS-CMP-15, 불꽃 깜빡임) · 흰 제목 "The Brawl Guys" · 자간 넓은 태그라인 · 흰 알약 버튼 "G + Google로 시작하기" · 상태 한 줄(loading/error) · 안내 "로그인하면 어느 기기에서든 기록이 이어집니다." · 🌐 언어 링크(한국어↔English 전환 스텁, `settings_changed` 트래킹) · debug 빌드만 "건너뛰기 (디버그)" 링크. 게스트 버튼은 없다 (계정 로그인 전용)
- 이메일 로그인 (2026-09-30 추가, 비밀번호 없는 6자리 코드): Google 버튼 바로 아래 ghost 알약 "이메일로 계속하기". 누르면 **같은 유리 카드**의 크레스트·제목·태그라인은 그대로 두고 아래 내용만 바뀐다(`motion_base` 페이드). 이메일 단계: 제목 "이메일로 로그인" · 안내 한 줄 · `TextField`(이메일 키보드) · 흰 알약 "인증코드 받기" · 상태 한 줄 · "← 다른 방법으로". 코드 단계: 안내(보낸 주소 + "메일로 받은 6자리 코드를 입력해 주세요") · `CodeInput`(숫자 키보드, 붙여넣기) · "로그인" · 상태 한 줄 · "코드 다시 받기 (N초)"(60초 쿨다운 동안 흐림) · "← 다른 방법으로"
- 키보드: Enter = 현재 단계 제출, Esc = 한 단계 뒤로(코드 → 이메일 → 방법 선택). 요청 중에는 알약이 "보내는 중…/확인 중…"으로 꺼진다. 오류는 한 줄 문구 + 입력칸 `danger` 링(잘못된 이메일 · 코드가 틀렸거나 만료됐어요 · 잠시 후 다시 시도해 주세요). 이메일 로그인은 모바일에서도 된다 — 모바일 안내 문구는 Google에만 해당. 요청 중에는 Esc가 듣지 않는다. 코드를 받은 주소로 쿨다운 안에 다시 요청하면 새 메일 없이 코드 단계로 돌아간다("이미 보낸 코드를 입력해 주세요"). 실패 뒤 포커스는 해당 입력칸으로
- 등장: 배경이 헤이즈에서 드러나고, 카드가 살짝 아래에서 떠오르며 부드럽게 커지고(`motion_calm`), 내용이 순서대로 페이드·리프트된다(`motion_slow`, `motion_fast` 간격). 튀는 효과 없음
- error 상태는 원인을 한 줄로 보여주고 버튼이 "다시 시도"가 된다. 로그인할 수 없는 환경(모바일·키 없음)은 버튼을 끄고 이유를 보여 준다

`KeyHintBar` 규칙 (DS-CMP-16, 2026-09-30):
- 위치: 대전 HUD 하단 가운데, safe area 안쪽 `s5` 여백 (DS-LAY-02 "조작은 하단"). 칩은 바 오른쪽 끝
- 키캡: 방향키는 역T자 묶음 + 캡션 "이동", 그다음 Space "점프" · Z "약공격" · X "강공격" · C "가드" · V "잡기" · X+C "필살기". 필살기는 동시 입력 키캡(여러 액션, 모두 눌렸을 때만 켜짐, 2026-09-30 Phase 5 T7)
- 필살기 준비: 그 플레이어의 게이지가 가득 차면(view `gauge` ≥ 100, 필살기 있는 캐릭터만) 필살기 키캡 둘레에 `fire` 링(굵기 `s1`, 캡에서 `s1` 띄움). 누름 색과 함께 보일 수 있다
- 로컬 2인(PRD-LOCAL-01): 플레이어마다 바 하나 — P1 왼쪽 아래, P2 오른쪽 아래(상단 대미지 카운터와 같은 순서), 바 앞에 플레이어 색 "P1"/"P2" 태그(`body` Jua + `ui_surface` 외곽선), 키캡 누름 색도 각자 플레이어 색. P2 키캡은 W/A S D 역T자 · Q · F · G · H · J · G+H. 칩은 마지막(P2) 바에 하나만, 숨기기/보이기는 두 바 함께. 이동 묶음 키캡은 글자여도 화살표 크기(`s6`+`s1`)라 두 바 높이가 같다
- 좁을 때(compact): 두 바가 한 줄에 안 들어가면(DS-LAY-04 폰 배율 1.6 = 논리 폭 약 1458) 묶음 간격 `s4`→`s2`, 바 좌우 여백 `s5`→`s3`. 글자 크기는 줄이지 않는다. 증거 `phase-5/evidence/key-hint-{lit,ready,special,hidden}-1080.png`, `key-hint-2p{,-hidden}-{1080,phone}.png`
- 키 글자와 눌림은 그 플레이어의 InputMap 액션(`p1_*` / `p2_*`)에서 읽는다 — 재지정하면 키캡 글자도 바뀐다
- 키보드 플레이어에게만: 터치 컨트롤이 보이면 바 전체가 숨는다 (터치와 겹치지 않음). 게임패드 글리프는 Phase 5 T9(버튼 프롬프트). 메뉴 배경 난투에는 없다 (HUD 없음)
- 숨기기/보이기: 칩 클릭 또는 F2 (F1은 디버그 패널, H는 P2 가드). 숨기면 칩만 남는다. 선택은 `user://settings.cfg` `[hud] key_hints`에 저장하고 `settings_changed {key: "hud.key_hints", old, new}` 트래킹

**컴포넌트 공통 규약**
- 루트는 `Control`, 크기는 `custom_minimum_size`를 토큰 간격으로 지정
- 상태는 `enum State` + `set_state()` 하나로만 바꾼다
- 게임 상태를 직접 읽지 않는다. 표시할 값을 외부(HUD 컨트롤러)가 넣어준다 → 갤러리에서 가짜 값으로 전시 가능

---

## 7. 비주얼 시스템 (DS-VIS)

### DS-VIS-01 소프트 툰 셰이딩 (초안)

외곽선 없는 2단 셰이딩 + 색 그림자 + 소프트 AO + 블룸. Mobile·Compatibility 렌더러 모두에서 동작해야 한다 (PRD-PLT-05).

| 파라미터 (글로벌 유니폼) | 초안 값 | 비고 |
|---|---|---|
| `ds_band_count` | 2 | 밝음 · 그림자 (레퍼런스처럼 단순하게). 셰이더에 고정, 글로벌 유니폼은 아님 |
| `ds_band_softness` | 0.12 | 경계가 부드럽게 번짐 |
| `ds_shadow_tint` | `grass_shade` 쪽 청록 이동 (project.godot 값 `Color(0.42, 0.6, 0.58)`) | 그림자는 절대 회색·검정이 아님 |
| `ds_shadow_strength` | 0.45 | 바닥에 드리운 그림자의 반투명도. 초안 값, 유니폼으로 구현되지 않음 (발밑 블롭은 `GROUND_SHADOW` 40%, 실시간 그림자는 라이트 설정) |
| `ds_rim_strength` | 0.35 | 캐릭터·아이템만. 외곽선 대신 형태를 떼어냄. Phase 3: 글로벌 유니폼(룩 프리셋이 설정) |
| `ds_char_saturation` | 1.0 | Phase 3 글로벌 유니폼. 캐릭터 채도 배율 (룩 프리셋 B는 +15%) |
| `ds_outline_width` | 0.0 | Phase 3 글로벌 유니폼. 캐릭터 전용 외곽선(inverted hull) 두께, 0이면 없음 |
| `ds_outline_color` | `canopy_deep` | Phase 3 글로벌 유니폼. 외곽선 색 (룩 프리셋 C에서 사용) |
| `ds_ao_strength` | 0.3 | 구 클러스터 사이 접촉부만 살짝 어둡게 (버텍스 AO로 베이크). 초안 값, 미구현 |
| `ds_bloom` | 약하게 | 캠프파이어·햇빛 반사·차지 광만 번짐. 구현: `EnvironmentRig` glow 강도 0.35 (웹 0.20), 품질 LOW·MEDIUM에서는 끔 |

- **외곽선 정책**: 월드·소품에는 쓰지 않는다. 캐릭터 가독성이 부족하면 Phase 3 🖼 게이트에서 "캐릭터 전용 얇은 `canopy_deep` 외곽선" 옵션을 비교한다.
- 그림자: 실시간 그림자 1개(태양) + 블롭 그림자(캐릭터 발밑, 저사양 대체)

### DS-VIS-02 형태 언어 · 캐릭터 룩

**형태 언어 (레퍼런스 A)**
- 식생 = **구 클러스터**: 크기가 다른 구 5~12개를 뭉쳐 덤불·나무 수관을 만든다. 모듈 3~4종을 회전·스케일해 재사용
- 나무 = 가늘고 짧은 `bark` 기둥 + 큰 `canopy` 구 클러스터
- 바위 = 달걀·조약돌 곡면 + 옅은 반점 텍스처
- 바닥 = 평면 `grass` + 부드러운 원형 밝기 얼룩(`grass_sun`) + 꽃 점 데칼(분홍·파랑·노랑, 작은 원 3~7개 묶음)

**캐릭터**
- 머리 : 몸 = 1 : 1 치비, 둥근 실루엣. 정면·측면 실루엣만으로 스타일이 구분되어야 한다
- 채도·명도를 바닥보다 한 단계 높게 + 림 라이트 → 연두 배경에서 떠 보임
- 스타일 악센트: 권투형 = 큰 둥근 장갑, 무기형 = 등에 멘 통나무 방망이, 원거리형 = 가방·새총 (Phase 5 🖼 게이트)
- 에셋: KayKit / Quaternius CC0 모델을 쓰되, 머티리얼은 전부 우리 소프트 툰 셰이더로 교체

### DS-VIS-03 플레이어 식별

- 발밑 링: 플레이어 색 + 모양 마커(●▲■◆), 부드러운 발광으로 바닥 위에 항상 그려짐 (안개·그림자 무시)
- 안개 낀 숲 (Phase 4 T6): 안개가 끼면 각 전투원의 몸 실루엣(플레이어 색 50%)과 발밑 링(90%)이 깊이 검사·안개 없이 안개 층 위에 그려지고 안개 양에 맞춰 나타난다 (`FogSilhouette`). 메뉴 배경에서는 숨긴다
- 머리 위 `P1`~`P4` 라벨: 로컬 다인 / 온라인에서만 표시
- 흑백으로도 구분 가능해야 한다 (Phase 5 완료 기준)

### DS-VIS-04 경기장 가독성

- 경기장 가장자리: 잔디가 둥글게 말려 끝나는 **두툼한 흙 단면** + 바깥은 `water` 또는 낭떠러지 → 링아웃 경계가 한눈에
- 위험 요소 규칙: 지속 대미지 = `fire` 발광 + 불티 / 부서질 발판 = 균열이 단계적으로 커짐 / 튕김 버섯 = 말랑하게 숨 쉬는 모션
- 장식(큰 나무, 바위)은 경기장 바깥에만. 카메라와 전투원 사이를 가리면 자동 디더 페이드

구현 (Phase 4 T6, 2026-09-30):
- 화상 영역(캠프파이어): 돌 테두리·장작·3겹 불꽃(`fire`·`petal_yellow`·`glow`) 깜빡임 + 불티 + 따뜻한 점광원, 화상 반경을 바닥에 `fire_ring`(`fire` 40%) 고리·원판으로 표시. 불붙은 전투원은 몸 주위 불꽃 혀 + 불티 (`BurnFlames`)
- 부서질 발판: 맞은 적이 있으면 균열 1단계, 경고 시간 동안 1→3단계로 커지며 떨림도 커짐, 부서지면 물로 떨어져 사라지고 복구되면 아래에서 튀어 올라옴 (`PlankView`, 균열 `canopy_deep`)
- 튕김 버섯: 스스로 빛나는 갓(`petal_pink`/`berry` + `glow` 점)이 숨 쉬듯 부풀고, 튕길 때 납작하게 눌렸다 출렁이며 복귀. 반발 표시 = 바닥의 `bounce_ring`(`petal_yellow` 50%) 고리 + 갓 위로 올라가는 작은 화살표 (`MushroomPadView`)
- 장식은 경기장 파일마다 1개(`ArenaDressing`)가 바깥에만 두고, **디더 페이드 대신 배치 단계에서 가림을 없앤다**: `DecorOcclusion`이 대전 카메라 자세(기본 프레이밍 + `cam_zoom_max`)에서 경기장 중심부(바닥~전투원 키)로 가는 시선을 자르는 장식을 빼고, 테스트가 경기장 5종 모두 가리는 장식이 없음을 확인한다

### DS-VIS-05 아이템·소품

- 아이템은 포인트 색(`berry`, `petal_*`) 단순 실루엣 + 은은한 `glow` 림 → 연두 바닥에서 바로 보임 (레퍼런스의 보라 열매처럼)
- 상자 낙하 1초 전 바닥에 부드러운 원형 그림자 예고 (쟁탈 시작 신호)
- 아이템을 든 캐릭터는 손 위치에 아이템 표시, 남은 사용 횟수는 작은 점
- 정식 모델 (Phase 4 T8, 🖼 캡처 제출 — 사용자 확인 대기): 코드로 만드는 저폴리 소프트 툰 모델, 아이템당 1파일(`src/render/props/items/`), 모든 파트에 `glow` 림. 상자 = `bark` 속 + `dirt` 판자 + `stone_shade` 금속 띠 / 방망이 = `dirt` 몸통 + `petal_pink` 그립 테이프·`berry` 감개, 남은 횟수에 따라 균열 3단계 / 폭탄 = `berry` 몸통 + `petal_pink` 하이라이트 + `stone_shade` 뚜껑 + `dirt` 심지, 불붙으면 `fire`·`glow` 불꽃이 심지를 타고 내려가며 폭발 직전 점점 빠르게 깜빡임 / 돌멩이 = `stone_cream` 깎은 정이십면체 + `stone_shade` 조각, 던지면 회전. 든 아이템은 KayKit `handslot.r` 뼈에 붙고 종류별 손 오프셋(`HOLD`)을 쓴다

---

## 8. 이펙트와 사운드 (DS-VFX / DS-SFX)

**모든 이펙트 강도는 넉백 크기 `k`의 함수다** (원칙 2). 강도 계수는 `GameConfig`에 있다.
이펙트 형태도 형태 언어를 따른다: **동그란 퍼프, 꽃잎, 빛 점**. 예외 — **타격 순간(DS-VFX-01·07)만은 뾰족한 코믹 별·스피드 라인·금속성 스파크를 쓴다** (2026-09-30 사용자 요청 "겟앰프드처럼 때리는 게 더 구체적으로 보이게": 누가 누구를 얼마나 세게 때렸는지 한눈에). 나머지 이펙트는 계속 둥근 형태.

| ID | 이펙트 | 트리거 | 강도 규칙 | Phase |
|---|---|---|---|---|
| DS-VFX-01 | 코믹 임팩트 버스트 (v2, 2026-09-30 개정 — v1 둥근 퍼프는 폭탄 폭발에만 남음) | 타격 성공 | 카메라를 향한 평면 뾰족 별(`canopy_deep` 외곽 + **공격자 플레이어 색** + `impact_core` 심지, 가시 수·크기는 k 단계별) + 타격 방향을 향한 충격 링. 단계: 약(k < `impact_medium_threshold`) / 중 / 강(k ≥ `spark_large_threshold`). 강타는 방사형 스피드 라인 + 화면 플래시(`screen_flash`, 0.12초) + 카메라 펀치(`impact_heavy_punch`). hitstop 동안 크게 유지 후 0.14초에 줄며 사라짐. 풀링(품질 LOW는 절반) | 1 (v1), 3, 5 (v2) |
| DS-VFX-02 | 가드 버블·잡기 표시 | 가드 중 / 잡기 가능 | 가드 피격 시 비눗방울처럼 출렁임 | 2 |
| DS-VFX-03 | 착지 먼지 | 착지, 급정지 | 연두빛 흙먼지 구름, 낙하 속도 비례 | 3 |
| DS-VFX-04 | 넉백 궤적 | 속도 > `trail_speed_threshold` | 플레이어 색 리본 + 떨어지는 잎사귀, 속도에 비례한 길이 | 3 |
| DS-VFX-05 | 링아웃 | 스톡 소모 | 물이면 큰 물보라, 낭떠러지면 플레이어 색 별 폭발 + 카메라 펀치 | 3 |
| DS-VFX-06 | 리스폰·차지 광 | 리스폰 / 강공격 차지 | 햇살 기둥에서 내려옴 / 차지량 비례 `glow` 블룸 | 3 |
| DS-VFX-07 | 가드 클랭 | 가드 피격 | 별 없이 작은 평면 `petal_blue` 바늘 8개 + `clang` 링 (가드 버블 출렁임과 함께) | 5 |
| DS-VFX-08 | 피격 플래시·반동 | 타격 성공 | 피격자 모델 `hit_flash` 흰색 덮개(hitstop 동안 유지 후 0.1초 페이드) + 타격 방향으로 밀렸다 떨리며 복귀 + 단계별 스쿼시. 근접 공격자는 hitstop 동안 앞으로 살짝 내딛은 자세. 렌더 전용(sim 위치 불변) | 5 |
| DS-VFX-09 | 대미지 숫자 | 타격 성공 (가드 제외) | 피격자 머리 위 "+12%" (`display_l` × 단계 배율, `canopy_deep` 외곽선), 색 = 피격 후 누적 % 의 DamageCounter 램프 색. 튀어나와 떠오르며 0.75초에 사라짐. `damage_popups` = 0 이면 끔 | 5 |
| DS-VFX-10 | 회피 잔상 | 구르기·공중 회피 무적 구간 (`is_dodging`) | 캐릭터 반투명 + 플레이어 색 캡슐 잔상이 `MOTION_BASE` 동안 사라짐 (`DodgeGhosts`, 메시 1개 공유·풀링) | combat-depth A |
| DS-VFX-11 | 가드 내구도 버블 | 가드 중 | 버블 반지름 = 내구도 비율(최소 45%), 30% 미만이면 `GUARD_BUBBLE_LOW`와 번갈아 깜빡임 | combat-depth A |
| DS-VFX-12 | 가드 브레이크 | `guard_break` (내구도 0) | 머리 위 높이 `petal_yellow` 평면 별 3개(`canopy_deep` 잉크 외곽선, 카메라를 향함)가 도는 기절 표시, 기절 동안 유지 (`DizzyStars`) | combat-depth A |
| DS-VFX-13 | 저스트 가드 | `perfect_guard` | 가드 클랭 대신 흰 별 플래시(`canopy_deep` 잉크 외곽선, 클랭보다 크고 길게) + 몸통에서 흰 링(잉크 테두리)이 퍼지며 `MOTION_SLOW` 동안 사라짐 (`PerfectRing`) | combat-depth A |

| ID | 사운드 세트 | 내용 |
|---|---|---|
| DS-SFX-01 | 기본 SFX | 톤: 말랑하고 통통 튀는 소리(나무·풀·물). 타격 약·강(k에 따라 피치·볼륨), 점프, 착지, 링아웃(물보라/멀어지는 휘파람), 아이템 줍기·던지기·폭발, UI 클릭·확인·취소. 배경음: 새소리·바람·물 앰비언스 |
| DS-SFX-02 | BGM | 신나는 아케이드 배틀 루프. 에너지 레퍼런스: 겟앰프드 OST "시티" — **에너지·템포감만 참고하고 멜로디·코드 진행·편곡·샘플은 쓰지 않는 100% 오리지널**. 통통 튀는 베이스·드럼 위에 마림바·어쿠스틱 기타·휘슬·목관 같은 숲 음색. 구성: 대전 루프(이음새 없는 반복), 마지막 스톡 인텐스 레이어, 메뉴용 차분한 변주. 제작 출처·라이선스는 `ASSETS.md`에 기록 (템포·주 악기는 사용자 힌트 대기) |

- 사운드 버스: Master › SFX / UI / Music / Ambience. 모든 에셋 라이선스는 `ASSETS.md`

---

## 9. 게임 필 (GD)

규칙은 여기서 정하고, 수치는 `GameConfig`에 둔다 (§2.2).

| ID | 항목 | 규칙 | GameConfig 키 (예) |
|---|---|---|---|
| GD-FEEL-01 | hitstop | 공격자·피격자 동시 정지. 강공격일수록 길게. 정지 중 피격자는 흰색 플래시 + 스쿼시·반동, 공격자는 내딛은 자세(DS-VFX-08) | `hitstop_light`, `hitstop_heavy` |
| GD-FEEL-02 | 화면 흔들림 | 진폭 = min(k × `shake_per_knockback`, `shake_max`), 지수 감쇠. hitstop이 끝날 때 시작 | `shake_per_knockback`, `shake_max`, `shake_decay` |
| GD-FEEL-03 | 무적 깜빡임 | 리스폰 무적 동안 반투명 펄스 10Hz, 마지막 0.5초는 20Hz | `blink_hz`, `blink_hz_end` |
| GD-FEEL-04 | 넉백 궤적 강도 | DS-VFX-04 강도 = 속도 / `trail_speed_full` | `trail_speed_threshold`, `trail_speed_full` |
| GD-CAM-01 | 카메라 | 레퍼런스 A의 높은 부감(피치 약 60°), 경기장 중심부(반지름 × `cam_arena_share`, 기본 60%)와 모든 생존 전투원을 여백과 함께 프레이밍(전투원이 가장자리로 가거나 밖으로 날아가면 시야가 넓어진다. 2026-09-30 사용자 요청으로 경기장 전체 → 60%로 확대), 줌 최소·최대 제한, 스무딩. KO된 전투원은 추적 제외. **필살기 컷인 (Phase 5, 렌더 전용)**: sim `special_start`가 오면 시전자 가슴 높이로 완전 확대(거리 7 m, 피치 38°로 낮춤) — 들어가기 `motion_base`(out-quad) → 유지(필살기 sim 길이 − 들어가기, `motion_slow`~`motion_calm`×2 사이) → 복귀 `motion_slow`(in-out-cubic). 그동안 시전자는 캐릭터별 필살기 모션(GD-ANIM-01), 확대된 시전자(화면 중앙) 발밑 아래 — 화면 84% 높이 — 에 시전자 플레이어 색 띠(88%, `s8`+`s5` 높이) + `glow` 줄 2개 + "P1 · 대지 강타"(`display_l`, `ui_surface` 글자·`canopy_deep` 외곽선)가 옆에서 밀려 들어온다(시전자·P 라벨·상단 HUD를 가리지 않고, 터치 버튼은 위 레이어). 확대 중 화면 밖·카메라 뒤 전투원의 충전 게이지는 숨긴다. 슬로우모션 없음(sim 틱·리플레이 해시 불변). 두 번째 필살기는 현재 확대에서 이어서 새 시전자로 초점을 부드럽게 옮기고(`FOCUS_FOLLOW`, 튀지 않음), 시전자가 KO면 마지막 위치에서 바로 복귀. `[accessibility] reduce_motion`(SettingsStore, 경기 시작마다 다시 읽음)이면 카메라는 그대로, 띠는 페이드만 | `cam_pitch`, `cam_margin`, `cam_arena_share`, `cam_zoom_min/max`, `cam_smooth` · 컷인 `SpecialCutIn` 상수 |
| GD-ANIM-01 | 애니메이션 매핑 | sim 상태 → 애니 상태 1:1. 애니가 sim 타이밍을 바꾸지 않는다 (히트박스 활성 프레임은 sim이 결정, 애니는 맞춰 재생). SPECIAL은 필살기 id별 모션: 대지 강타 = 양손 내려찍기, 돌진 연타 = 쌍검 찌르기(반복), 회전 베기 = 회전(반복), 거대 화염구 = 주문 발사 | — |

---

## 10. 접근성 (DS-A11Y)

| ID | 항목 | 내용 |
|---|---|---|
| DS-A11Y-01 | 색각 대응 | 플레이어는 색 + 모양 + 번호로 구분. 색각 모드에서 팔레트 대체 (p2/p3 명도 차 확대) |
| DS-A11Y-02 | 흔들림·진동 | 화면 흔들림 강도 0~100%, 햅틱 on/off, 블룸 끄기 |
| DS-A11Y-03 | 터치 커스터마이즈 | 버튼 크기 80~130%, 위치 드래그 편집, 저장 |

- 모든 터치 영역 ≥ 48dp, UI 글자 대비는 WCAG AA 이상 (`canopy_deep` on `ui_surface`)

---

## 11. 거버넌스 (DS-GOV)

| ID | 규칙 | 검증 |
|---|---|---|
| DS-GOV-01 | 토큰 외 색·크기 하드코딩 금지 (`tokens.gd`, `DebugPanel` 제외), `#000` 사용 금지 | 하드코딩 색 검사 스크립트, Phase 공통 체크 |
| DS-GOV-02 | 모든 컴포넌트·셰이더 샘플·VFX·SFX는 DS 갤러리에 등록 | 갤러리 씬 목록 = §6 표 |
| DS-GOV-03 | 버전: Phase마다 `0.N`, Phase 6 완료 시 `1.0` 동결 | 이 문서 상단 버전 |

**새 디자인 항목을 추가하는 절차**
1. 이 문서에 ID와 함께 항목 추가 (근거 PRD ID 필수)
2. PHASES.md 해당 Phase의 🎨 DS 트랙에 태스크 추가
3. 구현 → 갤러리 등록 → §12 추적표 상태 갱신
4. 시각적 결정이면 🖼 시안 비교 후 확정. 레퍼런스 A와 나란히 놓고 비교한다
5. 2D UI 화면(HUD·메뉴·로비)의 🖼 시안은 Google Stitch로 생성한다 (aside CLI, 프롬프트: [`stitch-prompts.md`](./stitch-prompts.md)). 시안은 참고용이며 색은 토큰으로 되돌리고, HTML 코드는 쓰지 않고 Godot DS 컴포넌트로 다시 구현한다

---

## 12. 추적표 (DS/GD → PRD → Phase)

상태: ⬜ 예정 · 🟨 진행 · ✅ 완료 · 🖼 시안 비교 대기

| ID | 항목 | 근거 PRD | Phase | 상태 |
|---|---|---|---|---|
| DS-TOK-01 | 색상 | PRD-UI-01, PRD-CORE-01 | 0 🖼 | ✅ A안 |
| DS-TOK-02 | 타이포그래피 | PRD-UI-01 | 0 | ✅ |
| DS-TOK-03 | 간격 | PRD-UI-01 | 0 | ✅ |
| DS-TOK-04 | 반경·선·그림자 | PRD-UI-01 | 0 | ✅ |
| DS-TOK-05 | 모션 | PRD-UI-01, PRD-UI-02 | 0 (정의), 3 (적용) | ✅ |
| DS-TOK-06 | 아이콘 | PRD-CTL-03, PRD-STYLE-01~03 | 2, 5 | 🟨 (Phase 2: 터치 버튼 4종 아이콘, Phase 5에서 계속) |
| DS-THM-01 | 기본 테마 | PRD-UI-01 | 0 | ✅ |
| DS-THM-02 | 경기장 테마 변형 | PRD-ARENA-01~04 | 4 | ✅ (Phase 4 T6) |
| DS-LAY-01 | 터치 레이아웃 | PRD-CTL-03 | 1 (기본), 2 🖼 | 🟨 (3안 구현, 기본값 0 호 배치, Stitch 시안 게이트 T13 대기) |
| DS-LAY-02 | HUD 레이아웃 | PRD-UI-01 | 1 | 🟨 (기본 배치 구현, 🖼 시안 게이트 대기) |
| DS-LAY-03 | 화면 흐름 · 메뉴 궤도 디오라마 배경 | PRD-UI-02, PRD-AUTH-01 | 4.0 (로그인·배경), 4, 5, 6 | 🔨 (4.0 로그인·타이틀·배경 완료, 캐릭터·경기장 선택은 4·5) |
| DS-LAY-04 | 모바일 반응형 스케일 · 세로 안내 | PRD-UI-01, PRD-PLT-01, PRD-PLT-03 | 4 | ✅ (2026-09-30, `platform/evidence/mobile-*.png`) |
| DS-CMP-12 | 컴포넌트 — `DebugPanel` | §6 표 참조 | 0 | ✅ |
| DS-CMP-01~03, 09 | 컴포넌트 — `DamageCounter`·`StockIcons`·`TouchStick`·`ResultBanner` | §6 표 참조 | 1 | ✅ |
| DS-CMP-04 | 컴포넌트 — `TouchButton` | PRD-CTL-03, PRD-CTL-04 | 1 (v1), 2 (v2) | ✅ (v2) |
| DS-CMP-05 | 컴포넌트 — `ChargeGauge` | PRD-CMB-02 | 2 | ✅ |
| DS-CMP-06~07 | 컴포넌트 — `MenuButton`·`Panel` | PRD-UI-02 | 4.0 | ✅ |
| DS-CMP-08 | SelectCard | PRD-UI-02 | 4, 5 | 🟨 (경기장 선택 Phase 4 T7 완료, 캐릭터 선택은 Phase 5) |
| DS-CMP-10, 11, 13 | 컴포넌트 (나머지) | §6 표 참조 | §6 표 참조 | ⬜ |
| DS-CMP-14 | 컴포넌트 — `LoginPanel` | PRD-AUTH-01 | 4.0 | ✅ (2026-09-30 확정, calm forest 레퍼런스 · 이메일 모드 추가 `evidence/login-email-*.png`) |
| DS-CMP-15 | 컴포넌트 — `CrestLogo` (브랜드 PNG `assets/branding/crest-1024.png`) | PRD-AUTH-01, PRD-UI-02 | 4.0 | ✅ (2026-09-30 확정, 콘셉트 C) |
| DS-CMP-16 | 컴포넌트 — `KeyHintBar` (키보드 조작 안내 바) | PRD-CTL-02, PRD-UI-01 | 4 | ✅ (2026-09-30, `evidence/key-hint-*.png`) |
| DS-CMP-17 | 컴포넌트 — `TextField` (로그인 이메일 입력) | PRD-AUTH-01 | 4.0 | ✅ (2026-09-30, 갤러리 + `evidence/login-email-step.png`) |
| DS-CMP-18 | 컴포넌트 — `CodeInput` (6자리 인증코드) | PRD-AUTH-01 | 4.0 | ✅ (2026-09-30, 갤러리 + `evidence/login-email-code.png`·`-error.png`) |
| DS-VIS-01 | 소프트 툰 셰이딩 | PRD-FX-03, PRD-PLT-05 | 0 (프로토), 3 🖼 | 🟨 (툰 v2·글로벌 유니폼 구현, 🖼 룩 게이트 T7 대기) |
| DS-VIS-02 | 형태 언어·캐릭터 룩 | PRD-FX-01, PRD-STYLE-01~03 | 0 (식생 모듈), 3 🖼, 5 🖼 | 🟨 (KayKit 4종 적용, 🖼 T7 대기, Phase 5에서 계속) |
| DS-VIS-03 | 플레이어 식별 | PRD-UI-01, PRD-LOCAL-01 | 1, 4, 5 | 🟨 (안개 실루엣 Phase 4 완료, P3·P4 모양은 Phase 5) |
| DS-VIS-04 | 경기장 가독성 | PRD-RULE-02, PRD-ARENA-01~04 | 1, 4 | ✅ (Phase 4 T6 위험 표시·장식 가림) |
| DS-VIS-05 | 아이템·소품 | PRD-ITEM-01~04 | 2, 4 | ✅ (Phase 4 T8 정식 모델, 🖼 확인 대기) |
| DS-VFX-01 | 코믹 임팩트 버스트 (v2) | PRD-FX-02, PRD-RULE-05 | 1 (v1), 3, 5 (v2) | ✅ (v2 2026-09-30, `dev/active/combat-depth/evidence/hit-*.png`) |
| DS-VFX-02 | 가드 버블·잡기 표시 | PRD-CMB-03, PRD-CMB-04 | 2 | ✅ |
| DS-VFX-03~06 | 이펙트 (나머지) | PRD-FX-02, PRD-RULE-05 | 3 | ✅ |
| DS-VFX-07~09 | 가드 클랭·피격 플래시·대미지 숫자 | PRD-FX-02, PRD-RULE-05 | 5 | ✅ (2026-09-30, `dev/active/combat-depth/evidence/hit-*.png`) |
| DS-VFX-10~13 | 방어 연출 (회피 잔상·내구도 버블·브레이크 별·저스트 가드 링) | PRD-CMB-03 | combat-depth A | ✅ (2026-09-30, 증거 스크린샷 미촬영) |
| DS-SFX-01 | 사운드 | PRD-FX-02 | 3 | 🟨 (타격·점프·착지·링아웃·아이템·UI 합성 SFX 구현. 새소리·바람·물 앰비언스 미구현, `ui_cancel` 정의만 있고 사용처 없음) |
| DS-SFX-02 | BGM | PRD-FX-02, PRD-CORE-01 | 3 | 🟨 (임시곡, 본곡 대기) |
| GD-FEEL-01~03 | 타격감 (hitstop·흔들림·깜빡임) | PRD-RULE-05, PRD-CORE-01 | 1 | ✅ |
| GD-FEEL-04 | 넉백 궤적 강도 | PRD-RULE-05, PRD-CORE-01 | 3 | ✅ |
| GD-CAM-01 | 카메라 | PRD-UI-01, PRD-ARENA-01~04, PRD-STYLE-04 | 0, 4.0 (메뉴 궤도), 4, 5 (필살기 컷인) | ✅ (5: 필살기 컷인 `SpecialCutInDirector`, 캡처 `dev/active/phase-5/evidence/cutin-*.png`) |
| GD-ANIM-01 | 애니메이션 매핑 | PRD-FX-01, PRD-ARCH-01 | 3 | ✅ |
| DS-A11Y-01 | 색각 대응 | PRD-UI-01 | 5, 6 | ⬜ |
| DS-A11Y-02~03 | 흔들림·진동, 터치 커스텀 | PRD-CTL-03 | 6 | ⬜ |
| DS-GOV-01~02 | 거버넌스 | PRD-CFG-01 (하드코딩 금지 원칙) | 0 ~ 6 | 🟨 (Phase 3·4에서 계속) |
| DS-GOV-03 | 거버넌스 — 버전 동결 | PRD-CFG-01 | 0 ~ 6 | ⬜ |
