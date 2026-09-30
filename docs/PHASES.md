# TheBrawlGuys — 개발 Phase

> 버전 1.1 · 2026-09-30 (1.1: Phase 4.0 플랫폼 추가, 트래킹 태스크, Vercel)
> 상위: [`PRD.md`](./PRD.md) (무엇·왜) · 병행: [`design.md`](./design.md) (디자인 시스템) · 문서 규칙: [`README.md`](./README.md)
>
> 이 문서는 **언제·어떤 순서로·무엇이 끝나야 하는지**를 소유한다.
> 모든 태스크는 대괄호로 근거 ID를 단다: `[PRD-xxx]` = 요구사항, `[DS-xxx]`/`[GD-xxx]` = 디자인 시스템 항목.
>
> 규칙
> - 한 번에 한 Phase만 진행한다. 끝나면 **완료 기준**을 스스로 검증하고 보고한다.
> - 각 Phase는 실행 가능한 상태로 끝난다. 반쯤 만든 기능을 남기지 않는다.
> - sim 로직은 테스트 먼저 작성한다 (RED → GREEN → 리팩터).
> - 조작감 수치는 확정하지 말고 `GameConfig`로 노출한다.
> - 각 Phase는 **⚙️ 개발 트랙**과 **🎨 디자인 시스템(DS) 트랙**으로 나뉜다. DS 트랙은 그 Phase의 기능이 쓸 UI·비주얼만 만든다 (미리 만들지 않는다).
> - 🖼 표시가 붙은 태스크는 **시각 비교 게이트**다. 시안 2~3개를 나란히 보여주고 승인받은 뒤 확정한다.
> - 각 Phase 시작 시 `dev/active/phase-N/`에 plan·context·tasks 문서를 만든다.

---

## 전체 흐름

```
Phase 0  뼈대 + 멀티플랫폼 검증        🎨 토큰 v0 · 테마 · DS 갤러리
   │
Phase 1  핵심 전투 + 기본 터치          🎨 HUD 코어 · 터치 v1 · 타격감 v1
   │
Phase 2  전투 확장 + 아이템 + 4버튼      🎨 터치 v2 · 전투 인디케이터
   │
Phase 3  캐릭터와 연출                  🎨 비주얼 시스템 확정 · VFX · SFX
   │
Phase 4.0 플랫폼 (로그인·트래킹·배포)   🎨 로그인 패널 · 메뉴 디오라마 · 메뉴 버튼/패널
   │      (Phase 4 sim 작업과 병렬 가능)
   ├── Phase 4  경기장                  🎨 선택 카드 · 경기장 테마 변형
   ├── Phase 5  스타일 + 필살기 + 로컬 2인 🎨 캐릭터 선택 · P1~P4 식별 체계
   │                                     (4·5는 순서 교체 가능, 둘 다 트래킹 포함)
Phase 6  온라인 대전                    🎨 로비 컴포넌트 · 설정/접근성
```

| Phase | 핵심 재미 연결 | 신규 플랫폼 검증 | DS 성숙도 |
|---|---|---|---|
| 0 | — | 데스크톱·Android·Web export | 토큰·테마·갤러리 |
| 1 | 과장된 넉백 | Android 실기기 터치 | HUD 코어 컴포넌트 |
| 2 | 아이템 쟁탈 | — | 인게임 컴포넌트 완비 |
| 3 | 넉백 연출 강화 | 모바일 60fps, iOS | 3D 비주얼·VFX·SFX 확정 |
| 4.0 | — (측정 기반 마련) | Vercel 웹 배포, Google 로그인 | 로그인·메뉴 컴포넌트 시작 |
| 4 | 넉백 × 지형 | — | 선택 카드·경기장 테마 |
| 5 | 스타일 차이 | 게임패드, 로컬 2인 | 선택 화면 완비 |
| 6 | 전부 (사람 대 사람) | 헤드리스 서버, 크로스플레이 | DS v1.0 |

---

## Phase 0 — 뼈대 + 멀티플랫폼 검증

**목표**: 코드를 쌓기 전에 "모든 타겟에서 뜬다", "수치를 실시간으로 만진다", "UI는 토큰으로만 그린다"를 먼저 확보한다.

### ⚙️ 개발 트랙

- [x] 환경: Godot 4.5+ 설치, Android SDK/JDK·export 템플릿 설치, `git init`
- [x] 프로젝트 생성, 폴더 구조, GDScript 정적 타입 경고를 에러로 승격 `[PRD-ARCH-01]`
- [x] GUT 설치, `godot --headless` 테스트 실행 스크립트 (`scripts/test.sh`) `[PRD-NFR-06]`
- [x] `InputFrame` `[PRD-CTL-01]`, `GameConfig` Resource + `default_config.tres` `[PRD-CFG-01]`
- [x] 고정 60Hz 틱 누산기 + 렌더 보간 (`main.gd`), `max_ticks_per_frame` `[PRD-ARCH-02]`
- [x] 빈 `World.tick()` / `snapshot()` / `restore()` 골격 `[PRD-ARCH-04]`
- [x] 원형 바닥(반경 = `arena_radius`), 조명, 3/4 시점 카메라 리그 `[GD-CAM-01]`
- [x] 디버그 패널: `GameConfig`의 `@export` 속성 순회 → 슬라이더 자동 생성, F1 / 세 손가락 탭 토글 `[PRD-CFG-01]` `[DS-CMP-12]`
- [x] Export 프리셋: macOS/Windows, Android(APK), Web(스레드 없음), Linux 헤드리스 `[PRD-PLT-01~04]`
- [x] `ASSETS.md` 생성 `[PRD-NFR-07]`

### 🎨 DS 트랙

- [ ] 레퍼런스 이미지를 `docs/references/ref-a-sunny-forest.png`에 보관 — 사용자 제공 대기
- [x] 🖼 레퍼런스 A 기반 팔레트 시안 3개 비교 → 확정 `[DS-TOK-01]` — 2026-09-28 A안(한낮 햇살) 채택
- [x] 토큰 v0: `src/ui/theme/tokens.gd` (색·간격·반경·타이포·모션 상수) `[DS-TOK-01~05]`
- [x] 폰트 도입 (디스플레이·본문, OFL), `ASSETS.md` 기록 `[DS-TOK-02]`
- [x] `forest_theme.tres`: Button·Label·Panel 기본 스타일을 토큰에서 생성 `[DS-THM-01]`
- [x] DS 갤러리 씬 `src/debug/ds_gallery.tscn`: 토큰 스와치, 타이포 스케일, 등록된 컴포넌트 전시 `[DS-GOV-02]`
- [x] 소프트 툰 셰이더 프로토타입 (2단 셰이딩 · 색 그림자 · 외곽선 없음) — 렌더러 호환성 확인용 `[DS-VIS-01]` `[PRD-PLT-05]`
- [x] 구 클러스터 덤불·나무 모듈 1종 + 꽃 점 데칼로 레퍼런스 룩 확인 `[DS-VIS-02]`
- [x] 하드코딩 색 검사 스크립트 (`Color(` / `#hex` grep, `tokens.gd` 제외) `[DS-GOV-01]`

### 테스트

- 단위: 누산기가 가변 delta 입력에서 정확한 틱 수를 만든다
- 단위: `snapshot()` → `restore()` 라운드트립이 동일 상태를 만든다 (빈 World 기준)

### 완료 기준

- [ ] 빈 경기장이 **데스크톱·Android 실기기·웹 브라우저**에서 뜬다 (각 스크린샷) — APK 빌드 완료, 실기기 실행은 사용자 확인 대기
- [x] 디버그 패널에서 `arena_radius`를 바꾸면 바닥 크기가 즉시 바뀐다
- [ ] 툰 셰이더가 세 플랫폼에서 깨지지 않는다 — 데스크톱·웹 확인, Android 실기기 확인 대기
- [x] DS 갤러리 씬이 확정 팔레트·타이포를 보여준다
- [x] `scripts/test.sh`, 하드코딩 색 검사 통과

---

## Phase 1 — 핵심 전투 + 기본 터치 (가장 중요)

**목표**: 캡슐 두 개로 "강하게 맞으면 확실히 날아간다"를 완성한다. 모바일이 주력이므로 기본 터치도 여기서 붙인다.

### ⚙️ 개발 트랙

**sim**
- [x] `collision.gd`: 캡슐–박스, 캡슐–캡슐, 원형 경기장 지면·경계 판정 `[PRD-ARCH-01]`
- [x] `fighter.gd`: 상태 머신 (idle / move / jump / attack / hitstun / launched / respawn)
- [x] 이동, 점프, 2단 점프 1회, 중력 `[PRD-CTL-02]`
- [x] 약공격 1종: 전방 박스 히트박스, 활성 프레임, 대미지 % `[PRD-RULE-01]`
- [x] `combat.gd`: 넉백 공식, hitstun, hitstop(N틱 정지) `[PRD-RULE-04]` `[PRD-RULE-05]`
- [x] `rules.gd`: 링아웃(`kill_y`·경계), 스톡 3, 리스폰(공중 등장 + 2초 무적), 승패 `[PRD-RULE-02]` `[PRD-RULE-03]`
- [x] 틱 비용 계측 훅 (디버그 패널에 ms 표시) `[PRD-NFR-02]`

**input**
- [x] `local_input.gd`: InputMap 기반 키보드 → InputFrame `[PRD-CTL-02]`
- [x] 터치 기본: 플로팅 가상 스틱 + 점프 + 공격(탭만) `[PRD-CTL-03]` `[PRD-CTL-04]`
- [x] `bot.gd` 1단계: 접근 → 사거리 내 공격, 가장자리에서 중앙 복귀 `[PRD-BOT-01]`

**render / ui**
- [x] 캡슐 뷰 + 상태 보간, 승패 화면 + 재시작 `[PRD-UI-01]`

### 🎨 DS 트랙

- [ ] HUD 레이아웃: 정보 상단 · 조작 하단, safe area 여백 `[DS-LAY-02]` — Stitch 시안 대기 (T12), 기본 배치로 구현
- [x] `DamageCounter`: 큰 숫자 %, 대미지 색 램프, 피격 시 흔들림 `[DS-CMP-01]` `[DS-TOK-01]`
- [x] `StockIcons` `[DS-CMP-02]`
- [x] `TouchStick` v1 (플로팅, 데드존 시각화) `[DS-CMP-03]`
- [x] `TouchButton` v1 (idle / pressed 상태) `[DS-CMP-04]`
- [x] `ResultBanner` (승·패, 재시작 버튼) `[DS-CMP-09]`
- [x] 플레이어 식별: 발밑 색 링 + P1/P2 라벨 (P1 파랑, P2 빨강) `[DS-VIS-03]`
- [x] 타격감 v1: 히트 퍼프(소·대), 넉백 비례 화면 흔들림, 무적 깜빡임 `[GD-FEEL-01~03]` `[DS-VFX-01]`
- [x] 경기장 가장자리 가독성: 바닥 테두리 대비선 `[DS-VIS-04]`
- [x] 모든 신규 컴포넌트를 DS 갤러리에 등록 `[DS-GOV-02]`

### 테스트

- 단위: 넉백 공식 — 대미지 0% / 50% / 150%에서 기대 속도·hitstun
- 단위: hitstun 동안 이동 입력 무시, hitstop N틱 동안 양측 위치 불변
- 단위: `kill_y` 아래로 떨어지면 스톡 1 감소 → 리스폰 → 2초 무적 동안 피격 무시
- 단위: 스톡 0 → 승패 확정
- 리플레이: 고정 입력 시퀀스 600틱 → 최종 상태 해시 고정 (회귀 감시)

### 완료 기준

- [ ] 봇과 한 판을 끝까지 할 수 있다 — **키보드와 Android 터치 둘 다** — 사용자 플레이 확인 대기 (키보드) · 실기기 확인 대기 (Android 터치). 자동 증거: `test_main_smoke`, `test_rules` 경기 종료, 링아웃 데모
- [x] 대미지 100% 이상에서 약공격 한 방에 경기장 밖으로 날아가는 게 눈에 보인다 (녹화 영상) — `test_ringout_feel` + `evidence/ringout-58/70/100/145.png` + 로컬 `ringout.avi`
- [ ] HUD가 휴대폰 화면에서 한눈에 읽힌다 (실기기 스크린샷) — 실기기 확인 대기 (데스크톱 증거: `dev/done/phase-1/evidence/match-hud.png`)
- [x] 4인 World(봇 4) 1틱 비용이 측정·기록되어 있다 `[PRD-NFR-02]` — `evidence/measurements.md` (22.2 us/tick 평균)
- [x] 입력 → 화면 반영 ≤ 3프레임 (고속 촬영 또는 프레임 로그) `[PRD-NFR-03]` — `evidence/measurements.md` (2프레임)
- [x] 모든 전투·타격감 수치가 디버그 패널에 있다 — `evidence/match-panel.png` + `test_config_schema`

---

## Phase 2 — 전투 확장 + 아이템 + 4버튼 터치

**목표**: 아이템을 먼저 줍기 위한 눈치 싸움을 만든다. 터치 조작을 완성형(스틱 + 4버튼)으로 올린다.

**결정**: E1~E11(`dev/done/phase-2/phase-2-context.md`) 사용자 승인 2026-09-29.

### ⚙️ 개발 트랙

**sim**
- [x] 약공격 3타 콤보 + 입력 버퍼 (`combo_buffer_ticks`) `[PRD-CMB-01]`
- [x] 강공격 + 차지 (최대 1초, 배율 1.6) `[PRD-CMB-02]`
- [x] 가드 (대미지 20%, 넉백 0%), 가드 중 이동 불가 `[PRD-CMB-03]`
- [x] 잡기 → 던지기 (방향 입력 반영) `[PRD-CMB-04]`
- [x] `items.gd`: 상자 낙하 스포너 (10~15초, 시드 RNG), 줍기·들기·던지기 `[PRD-ITEM-01]` `[PRD-ARCH-05]`
- [x] 아이템 3종 — 방망이(5회), 폭탄(2초 후 범위 폭발), 돌멩이(투사체) `[PRD-ITEM-02~04]`

**input**
- [x] 터치 4버튼: 공격 탭/홀드 해석(`touch_hold_threshold`), 가드, 잡기 `[PRD-CTL-03]`
- [x] 키보드 6액션 전부 연결 `[PRD-CTL-02]`
- [x] 봇 2단계: 가드, 아이템 줍기 `[PRD-BOT-02]`

### 🎨 DS 트랙

- [ ] 🖼 4버튼 터치 레이아웃 시안 3개 비교 (호 배치 / 다이아몬드 / 2×2, Stitch 프롬프트 1번) → 확정 `[DS-LAY-01]` — Stitch 시안 대기 (T13). 3안은 구현·캡처됨 (`evidence/touch-layout-{0,1,2}.png`), 기본값 0(호 배치)
- [x] `TouchButton` v2: highlight(컨텍스트) · disabled · charging 상태, 아이콘 세트 `[DS-CMP-04]`
- [x] `ChargeGauge` (캐릭터 머리 위 월드 공간 게이지) `[DS-CMP-05]`
- [x] 가드 표시(버블), 잡기 가능 표시 `[DS-VFX-02]`
- [x] 아이템 상자 낙하 예고 그림자, 아이템 들고 있음 표시 `[DS-VIS-05]`
- [x] 아이템 임시 모델 (단순 도형 + 토큰 색) `[DS-VIS-05]`

### 테스트

- 단위: 콤보 버퍼 안/밖 입력 시 2타 연결 여부
- 단위: 차지 0 / 0.5 / 1.0 / 1.5초 → 배율 1.0 / 1.3 / 1.6 / 1.6
- 단위: 가드 중 피격 → 대미지 20%, 넉백 0
- 단위: 방망이 5회 사용 후 소멸, 폭탄 120틱 후 폭발 범위 내만 피격
- 단위: 같은 시드 → 같은 상자 낙하 위치·시간
- 터치 해석 단위: 탭 < threshold → light 1틱, 홀드 → heavy 지속

### 완료 기준

- [x] 상자가 떨어지면 서로 먼저 가려고 한다 (녹화 영상) — 증거는 봇 대 봇 데모 씬(`src/debug/item_race_demo.tscn`, 두 봇 모두 2단계, 떨어지는 상자에 반응)이며 사람 플레이어는 없다: `evidence/item-race-030-falling.png`·`item-race-058-nearly-landed.png`·`item-race-066-contest.png`·`item-race-096-picked-up.png` + 로컬 `item-race.avi`
- [ ] 터치만으로 6액션 전부를 쓸 수 있다 (Android 실기기) — 실기기 확인 대기 (데스크톱 증거: `test_touch_input` + `evidence/match-hud-touch.png`)
- [x] 인게임 UI가 전부 DS 컴포넌트로 구성되어 있다 (갤러리 등록 확인) — `evidence/gallery-touch-button-v2.png`·`gallery-charge-gauge.png`·`gallery-items.png`
- [x] 리플레이 회귀 테스트 갱신·통과 — `tests/replay/*` (1200틱, 골든 2973674052)

---

## Phase 3 — 캐릭터와 연출

**목표**: 캡슐 버전과 조작감이 같으면서 보기에 재밌게. 3D 비주얼 시스템과 모바일 성능 예산을 여기서 확정한다.

### ⚙️ 개발 트랙

- [x] glTF 치비 캐릭터 교체 (KayKit Adventurers 등 CC0), `ASSETS.md` 기록 `[PRD-FX-01]` `[PRD-NFR-07]`
- [x] AnimationTree 상태 머신: idle, run, jump, attack, heavy, hit, launched, guard, grab — sim 상태를 읽기만 함 `[PRD-FX-01]` `[GD-ANIM-01]`
- [x] 판정 캡슐은 그대로 유지 (모델 교체가 sim에 영향 없음) `[PRD-ARCH-01]`
- [x] 품질 설정: 저사양 30fps 모드, 파티클·블룸·그림자 단계 `[PRD-NFR-01]`
- [x] iOS export 추가 `[PRD-PLT-01]` — 서명 없는 Xcode 프로젝트 export까지 (팀 ID·아이콘은 자리표시)

### 🎨 DS 트랙

- [ ] 🖼 캐릭터 룩 시안 비교 (림 강도 · 채도 · 캐릭터 전용 외곽선 유무) — 레퍼런스 A와 나란히 비교 → 확정 `[DS-VIS-01]` `[DS-VIS-02]` — 🖼 대기 (T7): 룩 프리셋 A 유지, 근접 캡처 `evidence/look-closeup-{0,1,2}.png`
- [x] 소프트 툰 셰이딩 최종화, 셰이더 파라미터를 글로벌 유니폼 토큰화 `[DS-VIS-01]` `[PRD-FX-03]`
- [x] VFX 라이브러리: 히트 퍼프, 착지 먼지, 넉백 궤적, 링아웃(물보라·별 폭발), 리스폰, 차지 광 `[DS-VFX-01~06]` `[PRD-FX-02]` — 히트 퍼프(DS-VFX-01)는 Phase 3에서 바뀌지 않은 v1 그대로
- [x] 넉백 궤적 강도 = 넉백 크기 연동 `[GD-FEEL-04]`
- [x] SFX 세트: 타격(약·강), 점프, 착지, 링아웃, 아이템, UI 클릭 `[DS-SFX-01]` `[PRD-FX-02]`
- [x] BGM: 대전 루프 + 마지막 스톡 인텐스 레이어 + 메뉴 변주 (오리지널, 라이선스 `ASSETS.md`) `[DS-SFX-02]` `[PRD-FX-02]`
- [x] 모션 토큰을 모든 UI 전환에 적용 `[DS-TOK-05]`
- [x] VFX·SFX 프리뷰를 DS 갤러리에 추가 `[DS-GOV-02]`

### 테스트

- 리플레이 해시가 Phase 2와 동일 (연출 변경이 sim을 건드리지 않았음을 증명)

### 완료 기준

- [x] 캡슐 버전과 같은 리플레이 해시 → 조작감 동일 — `BEHAVIOR_HASH` 1822125224 (커밋 61bd3ba에서 고정) Phase 3 내내 불변. `GOLDEN_HASH`는 cf80ce7(지문을 sim 그룹으로 한정)에서 한 번만 변경 (2953754395)
- [ ] 중급 모바일 기기 4인 봇전 60fps 유지 (프로파일러 캡처) `[PRD-NFR-01]` — 실기기 확인 대기 (데스크톱 품질별 4인 봇전: `dev/done/phase-3/evidence/performance.md`, 상한 해제 후 LOW·MEDIUM·HIGH 모두 평균 6.9ms/145fps, p95 7.3ms 이하)
- [x] 모바일 빌드 ≤ 150MB, 웹 초기 로딩 ≤ 40MB `[PRD-NFR-05]` — `check_build_size.sh`: android apk 36 MB (≤150), web pck+wasm gzip -9 18 MB (≤40, 원본 47 MB). `build/.gdignore` 추가 후 재빌드: apk 37.9MB, web pck 9.87MB(이전 10.03MB)·wasm 39.5MB, iOS export 로그의 `res://build` 오류 45건 → 0건. 웹 예산은 압축 전송 크기로 측정 (컨트롤러 판정)
- [x] 웹(Compatibility)에서도 툰 룩이 유지된다 (스크린샷 비교) `[PRD-PLT-05]` — 웹 기본 품질 LOW(블룸 끔)에서 어둡던 문제를 `EnvironmentRig`의 (Compat, 블룸 끔) 전용 광량으로 보정. 웹 LOW 캡처의 아레나 윗면 픽셀 (160,215,84) vs `DS.GRASS` (165,214,90), 채널당 ±12 이내. `evidence/web-toon.png` vs `evidence/desktop-toon.png`

---

## Phase 4.0 — 플랫폼 (로그인·트래킹·배포)

**목표**: 첫 화면이 로그인 창이고, Vercel 웹에서 Google 로그인 후 한 판을 하면 Amplitude 이벤트와 Supabase 경기 기록이 남는다. 이후 Phase의 기능은 만들 때 트래킹을 같이 단다 ([`tracking-plan.md`](./tracking-plan.md)).

**결정**: `dev/active/platform/platform-context.md` (2026-09-30 사용자 승인). 트래킹은 sim 이벤트를 소비만 한다 → sim·리플레이 해시 불변.

### ⚙️ 개발 트랙

**플랫폼 레이어 (`src/platform/`)**
- [ ] 문서: PRD·PHASES·design·tracking-plan 갱신 `[PRD-AUTH-01]` `[PRD-DATA-03]` `[PRD-DATA-04]`
- [ ] 비밀키 로더: `config/secrets.example.cfg`(커밋) + `secrets.local.cfg`(gitignore), 없으면 트래킹·로그인 비활성 + 경고, `service_role` 문자열 차단 검사 `[PRD-DATA-03]`
- [ ] `EventCatalog`(이벤트 이름·필수 속성 스키마) + `Analytics` autoload (Amplitude HTTP API v2 배치, 오프라인 큐, 지수 백오프 재시도, 공통 속성) `[PRD-DATA-03]`
- [ ] `SupabaseClient`: Auth·REST insert·토큰 자동 갱신 `[PRD-DATA-04]`
- [ ] Google OAuth PKCE: 웹 리다이렉트 · 데스크톱 루프백, 세션 `user://session.cfg` 저장·자동 갱신 `[PRD-AUTH-01]`
- [x] 이메일 6자리 인증코드 로그인 (Supabase OTP `/auth/v1/otp`·`/auth/v1/verify`, 모든 플랫폼, 60초 재전송 쿨다운, `email_code_*` 트래킹 — 이메일·코드는 보내지 않음). Supabase Email provider·Magic Link 템플릿 `{{ .Token }}`·커스텀 SMTP 설정은 사용자 대기 `[PRD-AUTH-01]` `[PRD-DATA-03]`
- [ ] 마이그레이션 SQL `supabase/migrations/0001_match_telemetry.sql` (`profiles`·`matches`·`match_players`·`match_events`) + RLS 본인 행만 `[PRD-DATA-04]`
- [ ] `MatchTelemetry` + `MatchRecorder`: 매 프레임 sim `events`·view 이벤트를 소비 → Amplitude 경기 요약·핵심 순간, Supabase 원시 로그 청크 insert `[PRD-DATA-03]` `[PRD-DATA-04]`

**앱 셸**
- [ ] `src/app/app.tscn` 메인 씬 + 화면 스택(로그인 → 타이틀/모드 → 캐릭터 → 경기장 → 대전 → 결과) + `MatchSetup` 주입 `[PRD-UI-02]` `[PRD-AUTH-01]`
- [ ] 메뉴 퍼널·로그인·앱 세션 트래킹 (`screen_viewed`, `login_*`, `app_*`) `[PRD-DATA-03]`

**배포**
- [ ] `vercel.json`(정적, `.wasm`/`.pck` 캐시·MIME 헤더) + `scripts/deploy_web.sh` → Vercel 배포, 도메인을 Supabase redirect 허용 목록에 등록 `[PRD-PLT-03]`

### 🎨 DS 트랙

- [ ] `MenuBackdrop` 궤도 디오라마: 봇 4명 난투 + 경기장 주위를 도는 카메라 + 메뉴 BGM `[DS-LAY-03]` `[GD-CAM-01]`
- [ ] 🖼 로그인 시안 3개 비교 (① 중앙 카드 스프링 팝 ② 좌측 세로 패널 슬라이드 + 우측 로고 ③ 로고가 먼저 떨어진 뒤 버튼 순차 등장) → `LoginPanel` 확정 `[DS-CMP-14]`
- [ ] `MenuButton`, `Panel` 메뉴용 확정 `[DS-CMP-06]` `[DS-CMP-07]`
- [ ] 신규 컴포넌트 DS 갤러리 등록 `[DS-GOV-02]`
- [x] 로그인 카드 이메일 모드 ("이메일로 계속하기" ghost 버튼 → 이메일 단계 → 코드 단계) + `TextField` · `CodeInput` `[DS-CMP-14]` `[DS-CMP-17]` `[DS-CMP-18]`

### 테스트

- 단위: `EventCatalog` 스키마(카탈로그 밖 이벤트·필수 속성 누락 → 실패), `Analytics` 배치·오프라인 큐(HTTP 모킹), PKCE 생성·콜백 파싱, 비밀키 로더
- 단위: 이메일 코드 로그인 — 주소·코드 검사, 쿨다운, 결과 매핑, 세션 저장, 트래킹 속성에 이메일(`@`)·코드 없음 (HTTP 모킹)
- 단위: `MatchTelemetry` — 고정 이벤트 시퀀스 → 기대 이벤트·요약값
- 리플레이: GOLDEN/BEHAVIOR 해시 불변 (트래킹이 sim을 건드리지 않음)

### 완료 기준

- [ ] 데스크톱에서 Google 로그인 → 봇전 한 판 → Amplitude에 `match_started`·`match_ended` 도착, Supabase `matches`·`match_events` 행 확인
- [ ] Vercel URL에서 로그인 리다이렉트 → 한 판 → 이벤트 수신 확인
- [ ] 저장된 세션이 있으면 재시작 시 로그인 화면을 건너뛴다
- [ ] 클라이언트 빌드에 `service_role` 키가 없다 (검사 스크립트) · security-reviewer 통과 (키·RLS)

---

## Phase 4 — 경기장

**목표**: 경기장마다 싸우는 방식이 달라진다.

### ⚙️ 개발 트랙

- [ ] `ArenaData` Resource: 판정 도형 목록, 링아웃 영역, 기믹 목록, 장식 씬 경로 `[PRD-ARCH-03]`
- [ ] 기믹 시스템 (sim): 지속 대미지 영역, 파괴 가능 발판, 튕김 발판, 주기 이벤트
- [ ] 호숫가 캠프장 `[PRD-ARENA-01]` · 통나무 다리 `[PRD-ARENA-02]` · 버섯 숲 `[PRD-ARENA-03]` · 안개 낀 숲 `[PRD-ARENA-04]`
- [ ] 장식은 경기장 바깥 배치, 카메라 가림 검사 `[GD-CAM-01]`
- [ ] 경기장 선택 화면 `[PRD-UI-02]`
- [ ] 트래킹: `arena_selected`, `gimmick_triggered`·`gimmick_ringout`, `stock_lost`의 경기장 구역·원인, 원시 이벤트 `gimmick_damage`·`platform_break`·`bounce`·`fog_start`·`fog_end` → `match_events` `[PRD-DATA-03]` `[PRD-DATA-04]`

### 🎨 DS 트랙

- [ ] `SelectCard` (썸네일 · 이름 · 기믹 아이콘, 선택/포커스 상태) `[DS-CMP-08]`
- [ ] 경기장별 테마 변형: 기본 토큰 위에 조명·안개·바닥 색 오버라이드 (`ArenaData.theme`) `[DS-THM-02]`
- [ ] 기믹 위험 표시 규칙 (화상 영역, 부서질 발판 균열, 버섯 반발 표시) `[DS-VIS-04]`
- [ ] 안개 연출 — 자기 캐릭터·상대 실루엣은 안개 위로 보이게 `[DS-VIS-03]`
- [x] `KeyHintBar` 대전 하단 키 안내 바 — 누른 키가 플레이어 색으로 켜짐, 칩·F2로 숨기기/보이기(설정 저장·`settings_changed`), 터치일 때 자동 숨김, 갤러리 등록 `[DS-CMP-16]` `[PRD-CTL-02]` `[DS-LAY-02]` — `evidence/key-hint-{lit,hidden}-{720,1080}.png`

### 테스트

- 단위: 기믹별 (화상 틱 대미지, 다리 파괴 타이밍, 버섯 반발 속도)
- 리플레이: 경기장별 고정 입력 시퀀스 해시

### 완료 기준

- [ ] 경기장 4종 각각에서 봇전 한 판 완주
- [ ] 경기장별로 링아웃이 일어나는 주된 위치·방식이 다르다 (플레이 로그 비교 — Supabase `match_events`의 `ringout` 위치 집계)
- [ ] 모든 기믹 위험 요소가 처음 보는 사람에게도 식별된다 (플레이테스트 3명)

---

## Phase 5 — 스타일 + 필살기 + 로컬 2인

**목표**: 스타일마다 이기는 방법이 다르다.

### ⚙️ 개발 트랙

- [ ] `StyleData`: 공격 목록(`AttackData` 참조), 이동 수치 오버라이드 `[PRD-ARCH-03]`
- [ ] 권투형 `[PRD-STYLE-01]` · 무기형 `[PRD-STYLE-02]` · 원거리형 `[PRD-STYLE-03]`
- [ ] 봇이 스타일별 사거리를 인식 `[PRD-BOT-02]`
- [ ] 필살기 (2026-09-30 사용자 결정): 때리거나 맞으면 차는 게이지가 가득 차면 1회, 강공격+가드(X+C) 동시 입력, 캐릭터마다 다른 필살기와 모션 (Barbarian 대지 강타 · Rogue 돌진 연타 · Knight 회전 베기 · Mage 거대 화염구) `[PRD-STYLE-04]`
- [ ] 필살기 컷인: 발동 시 카메라가 그 캐릭터로 완전 확대 (sim은 결정적으로, 컷인은 렌더 전용) `[PRD-STYLE-04]` `[GD-CAM-01]`
- [ ] 로컬 2인 (데스크톱): 키보드 분할(P2 WASD · Q · F · G · H · J) + 게임패드 자동 할당 `[PRD-LOCAL-01]` `[PRD-CTL-02]`
- [ ] 캐릭터(스타일) 선택 화면 `[PRD-UI-02]`
- [ ] 트래킹: `character_selected`, `gauge_full`·`special_used`·`special_hit`, `match_ended` 슬롯 요약에 스타일·필살기 수, 원시 이벤트 `special_start`·`special_hit`·`projectile_spawn` → `match_events` `[PRD-DATA-03]` `[PRD-DATA-04]`

### 🎨 DS 트랙

- [ ] 🖼 스타일별 실루엣·색 악센트 시안 비교 → 확정 `[DS-VIS-02]`
- [ ] 스타일 아이콘 3종 (권투·무기·원거리) `[DS-TOK-06]`
- [ ] 캐릭터 선택: `SelectCard` 확장 + 플레이어 슬롯 `PlayerSlot` `[DS-CMP-08]` `[DS-CMP-10]`
- [ ] P1~P4 식별 체계 완성: 색 + 번호 + 링 모양 (색각 이상 대응) `[DS-VIS-03]` `[DS-A11Y-01]`
- [ ] 게임패드/키보드 버튼 프롬프트 아이콘 (입력 장치 자동 전환) `[DS-TOK-06]`

### 테스트

- 단위: 스타일별 공격 데이터 로딩, 원거리 투사체 판정
- 단위: 필살기 게이지 증가·가득 참·동시 입력 발동·캐릭터별 판정
- 밸런스 시뮬레이션: 봇 대 봇 스타일 매치업 100판 자동 실행 → 승률 표

### 완료 기준

- [ ] 스타일 3종 × 봇전 완주
- [ ] 봇 대 봇 매치업 승률이 모두 30~70% 범위
- [ ] 한 키보드 / 키보드+패드 로컬 2인 한 판 완주
- [ ] 4인 화면에서 흑백 스크린샷으로도 P1~P4가 구분된다

---

## Phase 6 — 온라인 대전

**목표**: 서로 다른 기기(모바일↔데스크톱↔웹) 최대 4인이 방 코드로 한 판을 끝낸다.

### ⚙️ 개발 트랙

**6a — 넷코드**
- [ ] `protocol.gd`: 바이너리 메시지 (입력 + 최근 N개 중복, 스냅샷 델타, 입장/퇴장) `[PRD-NET-01]`
- [ ] `server_main.gd`: 헤드리스 서버, 방별 `World`, 60Hz 틱, 20~30Hz 스냅샷 `[PRD-NET-01]` `[PRD-PLT-04]`
- [ ] `client_session.gd`: 자기 캐릭터 예측, `restore()` + 미확인 입력 재적용, 타 캐릭터 약 100ms 보간 `[PRD-NET-02]`
- [ ] 지연·패킷 손실 시뮬레이터 (디버그 패널) `[PRD-CFG-01]`
- [ ] 재조정 비용 계측 → PRD §5.6 기준 초과 시 GDExtension 판단 `[PRD-NFR-02]`

**6b — 로비·배포**
- [ ] 방 코드 생성·입장, 최대 4인, 빈 방 자동 종료, 로비 HTTP API `[PRD-NET-03]`
- [ ] Supabase `rooms` 테이블(코드·서버 주소·인원·만료) + 만료 방 정리, 서버·클라이언트 연동 (프로젝트 자리 확보 선행) `[PRD-DATA-02]`
- [ ] 서버 Docker 이미지, Fly.io/VPS 배포 `[PRD-PLT-04]` (웹 빌드 Vercel 배포는 Phase 4.0으로 이동)
- [ ] 연결 끊김 처리 (재접속 유예, 봇 대체) `[PRD-NET-03]`

### 🎨 DS 트랙

- [ ] `RoomCodeInput` (대문자 6자리, 붙여넣기, 모바일 키패드) `[DS-CMP-11]`
- [ ] `PlayerSlot` 온라인 상태 (대기 · 준비 · 연결 끊김) `[DS-CMP-10]`
- [ ] `Toast` / 연결 상태 인디케이터 (핑 표시) `[DS-CMP-13]`
- [ ] 설정 화면: 화면 흔들림 강도, 진동, 터치 버튼 크기·위치 편집, 색각 모드 — `user://settings.cfg`에 저장 `[DS-A11Y-01~03]` `[PRD-DATA-01]`
- [ ] DS v1.0 동결: 토큰·컴포넌트 목록 확정, design.md 추적표 갱신 `[DS-GOV-03]`

### 테스트

- 단위: 프로토콜 인코드/디코드 라운드트립
- 통합: 헤드리스 서버 + 헤드리스 클라이언트 2개, 스크립트 입력 → 서버와 클라이언트 최종 상태 일치
- 네트워크: RTT 150ms / 손실 5% 시뮬레이션에서 재조정 오차 측정

### 완료 기준

- [ ] 모바일 + 데스크톱 + 웹 클라이언트가 한 방에서 한 판 완주
- [ ] RTT 150ms에서 자기 캐릭터 조작이 로컬과 체감 차이 없음 (플레이테스트) `[PRD-NFR-04]`
- [ ] 서버 코어당 동시 방 수 측정·기록

---

## Phase 공통 완료 체크

모든 Phase 종료 시 아래를 확인한다.

- [ ] `scripts/test.sh` 헤드리스 통과, sim 커버리지 80%+
- [ ] `sim/`에 Node·렌더링·물리·Input 참조 없음 (grep 검사)
- [ ] 새 수치가 모두 `GameConfig`에 있음
- [ ] 하드코딩 색 검사 통과, 신규 UI는 모두 DS 컴포넌트 + 갤러리 등록
- [ ] 데스크톱 + Android 빌드 실행 확인
- [ ] 이 문서의 체크박스와 [`design.md`](./design.md) §12 추적표의 상태 갱신
- [ ] 새 기능의 트래킹 이벤트가 [`tracking-plan.md`](./tracking-plan.md)와 `EventCatalog`에 있다 (Phase 4.0 이후)
- [ ] 코드 리뷰 에이전트 통과, `ASSETS.md` 최신

---

## 부록 — PRD 요구사항 커버리지

PRD의 모든 요구사항 ID는 적어도 한 Phase에 배정되어야 한다. ([`README.md`](./README.md) 규칙 R3)

| PRD ID | Phase | PRD ID | Phase |
|---|---|---|---|
| PRD-CORE-01 | 전 Phase (판단 기준) | PRD-ITEM-01~04 | 2 |
| PRD-PLT-01 | 0 (Android), 3 (iOS) | PRD-CFG-01 | 0, 1, 6 |
| PRD-PLT-02 | 0 | PRD-ARCH-01~02 | 0, 1 |
| PRD-PLT-03 | 0, 4.0 (Vercel) | PRD-ARCH-03 | 4, 5 |
| PRD-PLT-04 | 0, 6 | PRD-ARCH-04 | 0, 6 |
| PRD-PLT-05 | 0, 3 | PRD-ARCH-05 | 1, 2 |
| PRD-CTL-01 | 0 | PRD-NET-01~03 | 6 |
| PRD-CTL-02 | 1, 2, 5 | PRD-ARENA-01~04 | 4 |
| PRD-CTL-03 | 1 (기본), 2 (4버튼) | PRD-STYLE-01~04 | 5 |
| PRD-CTL-04 | 1 | PRD-LOCAL-01 | 5 |
| PRD-RULE-01~05 | 1 | PRD-FX-01~03 | 3 |
| PRD-CMB-01~04 | 2 | PRD-BOT-01 / 02 | 1 / 2, 5 |
| PRD-UI-01 | 1 | PRD-UI-02 | 4.0, 4, 5 |
| PRD-NFR-01 | 3 | PRD-NFR-02 | 1, 6 |
| PRD-NFR-03 | 1 | PRD-NFR-04 | 6 |
| PRD-NFR-05 | 3 | PRD-NFR-06~07 | 0 (이후 상시) |
| PRD-DATA-01 | 6 (설정 화면 로컬 저장) | PRD-DATA-02 | 6 |
| PRD-DATA-03 | 4.0 (기반), 4, 5 (기능별 이벤트) | PRD-DATA-04 | 4.0 (기반), 4, 5 (원시 이벤트) |
| PRD-AUTH-01 | 4.0 | | |
