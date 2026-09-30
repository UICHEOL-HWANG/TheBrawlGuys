# TheBrawlGuys — PRD

> 버전 1.0 · 2026-09-28
> 원본: [`PLAN.md`](../PLAN.md) (Three.js 웹 기준) → **Godot 4 멀티플랫폼**으로 전환한 제품 요구사항 문서.
> 게임 디자인(재미 구조, 규칙, 수치)은 PLAN.md를 계승하고, 플랫폼·기술·단계 구성만 재정의한다.
> 관련 문서: [`PHASES.md`](./PHASES.md) (개발 단계) · [`design.md`](./design.md) (디자인 시스템) · [`README.md`](./README.md) (문서 관계·추적 규칙)
>
> 이 문서는 **무엇을·왜 만드는지**(요구사항)를 소유한다. 요구사항은 §12의 `PRD-xxx` ID로 참조된다.

---

## 1. 제품 개요

| 항목 | 내용 |
|---|---|
| 장르 | 3D 아레나 브롤러 (최대 4인, 초기 1:1) |
| 콘셉트 | 머리 큰 치비 캐릭터들이 숲속 경기장에서 치고받고, 아이템을 주워 싸우고, 상대를 경기장 밖으로 날려버린다 |
| 분위기 | 호숫가·캠프파이어·소나무·버섯이 있는 따뜻한 숲. 외곽선 없는 부드러운 툰 셰이딩의 햇살 드는 숲 디오라마 ([`design.md`](./design.md) §0 레퍼런스 A) |
| 플랫폼 | 모바일(iOS/Android) · 데스크톱(Windows/macOS) · 웹 |
| 엔진 | Godot 4 (최신 stable, 4.5 이상) |
| 참고 | 겟앰프드의 "재미 구조"만 참고. 기존 게임의 이름·캐릭터·에셋·UI는 절대 사용하지 않는다 |

### 1.1 핵심 재미 (모든 판단의 기준)

| 요소 | 설명 |
|---|---|
| 과장된 넉백 | 맞을수록 더 멀리 날아간다. 역전의 긴장감 |
| 아이템 쟁탈 | 맵에 떨어지는 무기를 먼저 줍는 싸움 |
| 스타일 차이 | 캐릭터마다 공격 방식이 달라 선택하는 재미 |

**새 기능이 이 셋 중 하나를 강화하지 않으면 뒤로 미룬다.**

### 1.2 타겟 사용자

- 짧은 세션(한 판 2~4분)으로 친구와 가볍게 겨루고 싶은 캐주얼 플레이어
- 모바일에서는 양손 엄지(좌 스틱 / 우 버튼)로 즐길 수 있어야 하고, 데스크톱에선 키보드·패드로 더 정밀하게 즐긴다

### 1.3 성공 지표

| 지표 | 목표 |
|---|---|
| 첫 판 완주율 | 봇전 첫 판을 끝까지 하는 비율 ≥ 80% (플레이테스트 기준) |
| "날아가는 맛" | 플레이테스터 5명 중 4명 이상이 "강하게 맞으면 확실히 날아간다"에 동의 |
| 아이템 눈치 싸움 | 아이템 상자 낙하 후 5초 안에 두 플레이어 모두 상자 쪽으로 이동하는 비율 ≥ 60% |
| 모바일 조작 | 터치만으로 봇전 승리 가능 (데스크톱 대비 승률 차이 ≤ 20%p) |

---

## 2. 플랫폼 요구사항

| 플랫폼 | 역할 | 렌더러 | 비고 |
|---|---|---|---|
| Android / iOS | **주력** | Mobile | 가로 화면 고정, 터치 조작 |
| Windows / macOS | 주력 · 개발 기준 | Mobile (Forward+ 선택 가능) | 키보드·게임패드, 로컬 2인 |
| Web | 데모·공유 링크 | Compatibility | 스레드 없는 export (SharedArrayBuffer 불필요), Cloudflare Pages 배포 |
| Linux 헤드리스 | 온라인 전용 서버 | 없음 | `--headless` dedicated server export |

- 툰 셰이더와 이펙트는 **Mobile과 Compatibility 렌더러 둘 다에서 동작**해야 한다.
- 모든 플랫폼이 **같은 `sim/` 코드**를 사용한다.

---

## 3. 조작

### 3.1 입력 추상화

모든 입력원(키보드, 패드, 터치, 봇, 네트워크)은 틱마다 동일한 `InputFrame`을 만든다. 터치의 제스처 해석(탭/홀드, 컨텍스트 버튼)은 **입력 레이어에서 끝내고**, sim은 `InputFrame`만 본다.

```gdscript
class_name InputFrame extends RefCounted
var move_x: float   # -1 ~ 1
var move_z: float   # -1 ~ 1
var jump: bool
var light: bool
var heavy: bool     # 누르고 있는 동안 true (차지)
var guard: bool
var grab: bool
```

### 3.2 키보드 / 게임패드 (6액션)

| 동작 | 키보드 (P1) | 키보드 (P2, 로컬) | 게임패드 |
|---|---|---|---|
| 이동 | 방향키 | WASD | 좌 스틱 |
| 점프 (2단 점프 1회) | Space | Phase 5에서 확정 | A / × |
| 약공격 (3타 콤보) | Z | Phase 5에서 확정 | X / □ |
| 강공격 (홀드 차지) | X | Phase 5에서 확정 | Y / △ |
| 가드 (홀드) | C | Phase 5에서 확정 | RB / R1 |
| 잡기 / 줍기·던지기 | V | Phase 5에서 확정 | B / ○ |

P1 키는 2026-09-30 사용자 요청으로 WASD·JKLU에서 방향키·ZXCV로 바뀌었다. P2 키는 로컬 2인(Phase 5)에서 정한다.

키 매핑은 Godot InputMap 액션으로 정의하고 하드코딩하지 않는다.

### 3.3 터치 (가상 스틱 + 4버튼)

| 터치 입력 | InputFrame 매핑 |
|---|---|
| 좌측 가상 스틱 (플로팅: 터치한 위치가 중심) | `move_x`, `move_z` |
| 점프 버튼 | `jump` |
| 공격 버튼 **탭** (< `touch_hold_threshold`) | 뗄 때 `light` 1틱 |
| 공격 버튼 **홀드** (≥ `touch_hold_threshold`) | 홀드 동안 `heavy` (차지), 뗄 때 발동 |
| 가드 버튼 (홀드) | `guard` |
| 잡기 버튼 | `grab` — 근처에 잡을 상대·아이템이 있거나 아이템을 들고 있으면 강조 표시 |

- `touch_hold_threshold`(기본 0.15초), 스틱 데드존·반경, 버튼 크기·위치는 모두 config 값이다.
- 버튼 최소 터치 영역 48dp, 엄지가 닿는 우하단 호(arc) 배치. 레이아웃 상세는 [`design.md`](./design.md) §5.
- 멀티터치: 스틱과 버튼을 동시에 누를 수 있어야 한다.

---

## 4. 게임 규칙

### 4.1 기본 규칙

- **대미지 방식**: 누적 대미지(%). 체력이 없고, %가 쌓일수록 넉백이 커진다
- **승패**: 스톡 3개. 경기장 밖으로 떨어지면(Y < `kill_y` 또는 경계 밖) 스톡 1개 소모
- **리스폰**: 경기장 위 공중에서 등장, 2초 무적 (깜빡임 표시)

### 4.2 넉백 공식

```
knockback = (attack.base_knockback + target.damage_percent * attack.knockback_scaling) * config.global_knockback_mul
velocity  = normalize(attack.direction + Vector3(0, attack.launch_angle_y, 0)) * knockback
hitstun   = knockback * config.hitstun_factor   (초)
```

- 피격 중(hitstun)에는 조작 불가. 공중에서 중력만 받으며 날아간다
- 타격 순간 공격자와 피격자 모두 `hitstop`만큼 정지 → 화면 흔들림 → 넉백 시작

### 4.3 전투 액션

| 액션 | 요구사항 |
|---|---|
| 약공격 | 3타 콤보. 입력 버퍼 내에 다시 누르면 다음 타로 연결 |
| 강공격 | 홀드로 차지 (최대 1초, 배율 1.6), 떼면 발동 |
| 가드 | 홀드 동안 대미지 20%, 넉백 0% |
| 잡기 → 던지기 | 근접 상대를 잡고, 방향 입력 + 잡기 재입력으로 던짐 |
| 아이템 | 잡기 버튼으로 줍기/사용/던지기 |

### 4.4 아이템

10~15초마다 경기장 안 랜덤 위치에 상자가 떨어진다.

| 아이템 | 동작 |
|---|---|
| 방망이 | 휘두르기, 넉백 큼, 5회 사용 |
| 폭탄 | 던지면 2초 후 범위 폭발 |
| 돌멩이 | 던지는 투사체 |

### 4.5 초기 수치 (`GameConfig` 기본값)

| 항목 | 값 |
|---|---|
| move_speed | 6 m/s |
| jump_velocity | 9 m/s |
| gravity | -25 m/s² |
| arena_radius | 10 m |
| kill_y | -8 m |
| 약공격 대미지 / base_knockback / scaling | 4% / 3 / 0.05 |
| 강공격 대미지 / base_knockback / scaling | 12% / 6 / 0.12 |
| 강공격 최대 차지 배율 | 1.6 (1초 차지) |
| hitstop | 0.06초 (강공격 0.1초) |
| hitstun_factor | 0.04 |
| 가드 시 대미지 / 넉백 | 20% / 0% |
| touch_hold_threshold | 0.15초 |
| global_knockback_mul | 1.7 (Phase 1 튜닝, Phase 2에서 3타 콤보 마무리 기준으로 재확인: 중간 거리 100%에서 링아웃하는 범위 1.37~2.75) |
| combo_buffer_ticks / 연결타 대미지·넉백 | 10틱 / 3% · 1.5 (scaling 0) |
| 잡기 유지 / 던지기 대미지·base·scaling | 1.5초 / 8% · 7 · 0.1 |
| 상자 주기 / 필드 최대 | 10~15초 / 2개 |
| 방망이 / 폭탄 / 돌멩이 대미지 | 10% (5회) / 15% (2초, 반경 2.5 m) / 6% |

**모든 수치는 인게임 디버그 패널에서 실시간 조절 가능해야 한다.**

---

## 5. 기술 아키텍처

### 5.1 스택

| 영역 | 선택 |
|---|---|
| 엔진 | Godot 4.5+ |
| 언어 | GDScript (정적 타이핑 필수). 성능 병목 시 핵심만 GDExtension (§5.6) |
| 시뮬레이션 | 자체 구현 순수 로직 sim (Godot 물리 엔진 미사용) |
| 설정/튜닝 | `GameConfig` Resource(`.tres`) + 자동 생성 인게임 디버그 패널 |
| 에셋 | glTF, KayKit / Quaternius CC0 팩 |
| 테스트 | GUT (헤드리스 실행) |
| 온라인 | Godot 헤드리스 전용 서버 + `WebSocketPeer` 커스텀 바이너리 프로토콜 |
| 배포 | 웹: Cloudflare Pages / 서버: Fly.io 또는 VPS (Docker) / 모바일: 스토어 |
| 데이터 저장 | 로컬 설정·기록: 기기 `user://` (ConfigFile) / 서버 데이터(방 코드·로비, 향후 계정·랭킹): **Supabase** (Postgres + Auth) |

### 5.2 아키텍처 원칙

1. **시뮬레이션과 렌더링 분리**: `sim/`은 `RefCounted` 기반 순수 로직이다. `Node`, `SceneTree`, `RenderingServer`, `PhysicsServer3D`, `Input`을 참조하지 않는다. `Vector3`, `Basis` 등 내장 수학 타입은 허용한다.
2. **고정 틱**: sim은 60Hz 고정 타임스텝으로 직접 진행한다(누산기 방식). 렌더러는 직전·현재 상태를 보간해 그린다.
3. **입력 추상화**: 모든 입력원이 같은 `InputFrame`을 틱마다 넘긴다 (§3.1).
4. **수치는 전부 `GameConfig`**: 하드코딩 금지. 디버그 패널이 `@export` 속성을 순회해 자동으로 슬라이더를 만든다.
5. **데이터 주도**: 공격·스타일·경기장·아이템은 Resource 데이터로 정의한다.
6. **sim 상태는 직렬화 가능**: `World.snapshot() -> PackedByteArray` / `World.restore()`를 제공한다. 온라인 재조정, 리플레이, 회귀 테스트에 쓴다.
7. **결정성 지향**: sim 내 난수는 `World`가 가진 시드 RNG만 쓴다. 입력 시퀀스가 같으면 같은 결과가 나와야 한다(동일 바이너리 기준).
8. **매 Phase 끝에는 실행 가능한 상태**: 반쯤 만든 기능을 남기지 않는다.

### 5.3 폴더 구조

```
project.godot
src/
  main/
    main.tscn / main.gd      # 진입점, 고정 틱 누산기, 모드 전환
  config/
    game_config.gd           # class_name GameConfig extends Resource
    default_config.tres
  sim/                       # 순수 게임 로직 (노드·렌더링·물리 엔진 무관)
    world.gd                 # 게임 상태, tick(inputs), snapshot/restore
    fighter.gd               # 캐릭터 상태 머신·이동·피격
    combat.gd                # 히트박스 판정, 대미지, 넉백
    collision.gd             # 캡슐/박스/구/원기둥 판정, 경기장 지면·경계
    items.gd
    rules.gd                 # 스톡, 링아웃, 승패
    input_frame.gd
    data/                    # AttackData, StyleData, ArenaData, ItemData (Resource 스크립트)
  input/
    local_input.gd           # 키보드/패드 → InputFrame
    touch/                   # 가상 스틱, 터치 버튼, 제스처 해석
    bot.gd                   # sim 상태 → InputFrame
  render/
    arena_view.gd
    fighter_view.gd          # 보간, 애니메이션 상태 머신
    camera_rig.gd            # 3/4 시점, 전원 추적 줌
    effects.gd               # 히트스톱 연출, 화면 흔들림, 파티클
  ui/
    hud.gd                   # 대미지 %, 스톡
    menus/                   # 타이틀, 캐릭터·경기장 선택, 결과
  debug/
    config_panel.gd          # GameConfig 자동 슬라이더
  net/                       # Phase 6
    protocol.gd
    client_session.gd        # 예측·재조정·보간
    server_main.gd           # 헤드리스 서버 진입점
data/
  attacks/ styles/ arenas/ items/   # *.tres
assets/                      # glTF, 텍스처, 사운드 (출처는 ASSETS.md)
tests/
  unit/                      # sim 단위 테스트
  replay/                    # 입력 시퀀스 리플레이 회귀 테스트
```

### 5.4 게임 루프

```
_process(delta):
  accumulator += delta
  ticks = 0
  while accumulator >= TICK (1/60) and ticks < max_ticks_per_frame:
    inputs = [source.sample(world) for source in input_sources]
    prev_state = world.state_view()
    world.tick(inputs)
    accumulator -= TICK
    ticks += 1
  alpha = accumulator / TICK
  render.draw(prev_state, world.state_view(), alpha)
```

- `max_ticks_per_frame`으로 저사양에서 죽음의 나선을 막는다.
- hitstop은 sim 안에서 "해당 파이터의 진행을 N틱 멈춤"으로 처리한다. 렌더 레이어의 시간 정지가 아니다.

### 5.5 온라인 구조 (Phase 6)

```
[클라이언트]──InputFrame(+최근 N개 중복)──▶[Godot 헤드리스 서버: 방별 World]
     ▲                                              │
     └──────────── 스냅샷 (20~30Hz, 델타) ◀─────────┘
```

- **서버 권위**: 클라이언트는 `InputFrame`만 보낸다. 서버가 `sim/`을 돌려 상태를 브로드캐스트한다.
- **자기 캐릭터 예측 + 재조정**: 서버 스냅샷 수신 시 해당 틱으로 `restore()` → 미확인 입력 재적용.
- **타 캐릭터 보간**: 약 100ms 지연 보간.
- **전송**: 웹 클라이언트와 공통으로 쓰기 위해 WebSocket을 쓴다 (ENet은 웹 미지원).
- **방**: 방 코드로 입장, 최대 4인. 서버 프로세스 하나가 여러 방을 호스팅한다.
- **로비/매칭**: Supabase `rooms` 테이블(방 코드 · 게임 서버 주소 · 인원 · 만료 시각)로 방 코드를 서버 주소에 매핑한다. 만료된 방은 주기적으로 정리한다. 게임 서버 자체는 DB가 아니므로 Fly.io/VPS에서 실행한다.
- **향후 계정·랭킹**: 같은 Supabase 프로젝트에 추가하고 로그인은 Supabase Auth를 쓴다 (현재 범위 밖, §8).
- 롤백 넷코드는 하지 않는다.

### 5.6 GDExtension 도입 기준

기본은 GDScript. 아래 중 하나라도 **프로파일링으로 확인되면** 해당 모듈만 네이티브로 옮긴다.

- 목표 모바일 기기에서 sim 1틱 > 2ms
- 서버에서 코어당 동시 방 수 < 20
- 재조정(최대 15틱 재시뮬레이션)이 한 프레임 안에 끝나지 않음

후보 모듈은 `collision.gd`, `combat.gd`, `world.snapshot/restore`다. C++(godot-cpp)와 Rust(gdext) 중 선택은 도입 시점에 결정한다 (§9 열린 질문). 인터페이스를 유지하기 위해 sim 외부에서는 `World`의 공개 API만 사용한다.

---

## 6. 콘텐츠 요구사항

### 6.1 경기장

경기장은 `ArenaData` Resource로 정의한다. 판정용 구조는 단순 도형, 장식은 에셋이다.

| 경기장 | 기믹 |
|---|---|
| 호숫가 캠프장 | 한쪽이 호수(링아웃). 캠프파이어에 닿으면 불붙어 지속 대미지 |
| 통나무 다리 | 좁은 다리, 시간이 지나면 일부가 부서져 좁아짐 |
| 버섯 숲 | 큰 버섯을 밟으면 높이 튀어 오름 |
| 안개 낀 숲 | 주기적으로 안개가 껴서 시야 제한 |

- 장식(큰 나무, 바위)은 경기장 바깥에 두어 카메라 시야를 가리지 않는다.

### 6.2 스타일

스타일은 `StyleData`(공격 목록, 수치)로 정의한다.

| 스타일 | 특징 |
|---|---|
| 권투형 | 빠른 연타, 짧은 사거리, 콤보 강함 |
| 무기형 | 느리지만 넓은 범위, 넉백 큼 |
| 원거리형 | 투사체 공격, 근접 약함 |

### 6.3 연출

- 애니메이션 상태: idle, run, jump, attack, heavy, hit, launched, guard, grab
- 타격 파티클, 먼지, 링아웃 연출, 효과음(타격·점프·링아웃)
- 소프트 툰 셰이딩 — 외곽선 없음, 색 그림자, 구 클러스터 식생 (Mobile/Compatibility 렌더러 호환, `DS-VIS-01`)

### 6.4 봇

- 1단계: 접근 → 사거리 안이면 공격, 가장자리에서는 중앙 복귀
- 2단계: 가드, 아이템 줍기 사용
- 봇은 `InputFrame`만 생산한다 (sim 직접 조작 금지)

### 6.5 화면

- 인게임 HUD: 전원의 대미지 %, 스톡. 휴대폰 가로 화면에서 한눈에 읽혀야 한다
- 메뉴 화면 흐름: 타이틀 → 모드(봇 / 로컬 2인 / 온라인) → 캐릭터(스타일) 선택 → 경기장 선택 → 대전 → 결과
- 모든 UI는 디자인 시스템(토큰·컴포넌트)으로만 구성한다 — 상세는 [`design.md`](./design.md)

---

## 7. 비기능 요구사항

| 항목 | 요구사항 |
|---|---|
| 프레임레이트 | 모바일 중급기(iPhone 12 / Galaxy A54급) 60fps 유지, 저사양 30fps 모드 |
| sim 비용 | 4인 + 아이템 10개 기준 1틱 ≤ 2ms (목표 모바일 기기) |
| 입력 지연 | 로컬: 입력 → 화면 반영 ≤ 3프레임 |
| 온라인 | RTT 150ms 이하에서 자기 캐릭터 조작감이 로컬과 체감 차이 없음 |
| 빌드 크기 | 모바일 ≤ 150MB, 웹 초기 로딩 ≤ 40MB |
| (측정 비고, Phase 3) | 웹 예산은 압축 전송 크기(gzip -9 pck+wasm)로 측정: 18MB (원본 47MB). Android APK 36MB. 모바일 60fps는 실기기 확인 대기 (데스크톱만 측정) |
| 테스트 | sim 단위 테스트 커버리지 80%+, 헤드리스로 CI 실행 |
| 라이선스 | 모든 에셋 출처와 라이선스(CC0 여부)를 `ASSETS.md`에 기록 |

---

## 8. 범위 밖 (당분간 하지 않음)

- 계정, 상점, 커스터마이징, 랭크
- 롤백 넷코드
- 세로 화면 모드
- 기존 게임의 이름·캐릭터·에셋·UI 사용

---

## 9. 리스크와 열린 질문

### 리스크

| 리스크 | 영향 | 대응 |
|---|---|---|
| 자체 충돌 구현 공수 | Phase 1·4 지연 | 도형을 캡슐·박스·구·원기둥으로 제한, 경기장 기믹도 이 도형으로만 표현 |
| GDScript sim 성능 (모바일·서버) | 프레임 드롭, 서버 비용 | Phase 1부터 틱 비용 계측, §5.6 기준으로 GDExtension 전환 |
| 터치 조작감 | 모바일 재미 저하 | Phase 1부터 실기기 테스트, 모든 터치 수치 config 노출 |
| 툰 셰이더 렌더러 호환성 | 웹·모바일 화질 차이 | Phase 0에서 렌더러별 export 스모크 테스트 |
| float32 결정성 | 예측 재조정 오차 | 서버 권위로 보정. 동일 바이너리 기준 리플레이 테스트로 회귀 감시 |
| 서버 운영 비용 | 온라인 지속성 | 한 프로세스 다중 방, 빈 방 자동 종료 |
| Supabase 무료 프로젝트 한도 소진 | Phase 6 로비 배포 지연 | Phase 6 시작 전 안 쓰는 프로젝트를 일시정지·삭제해 자리 확보. 불가하면 유료 플랜 또는 대안 재검토 |

### 열린 질문

1. GDExtension 언어: C++(godot-cpp) vs Rust(gdext) — 도입 시점에 결정
2. 터치 강공격: 홀드 방식 외에 스와이프 방식도 A/B 테스트할지
3. 서버 호스팅: Fly.io vs 자체 VPS — Phase 6 시작 시 비용 비교
4. 모바일 스토어 출시 시점과 수익 모델 (현재 범위 밖)

---

## 10. 개발 단계 요약

상세 태스크와 완료 기준은 [`PHASES.md`](./PHASES.md)에 있다.

| Phase | 목표 | 핵심 완료 기준 |
|---|---|---|
| 0 | 뼈대 + 멀티플랫폼 검증 | 빈 경기장이 데스크톱·안드로이드·웹에서 뜨고, 디버그 패널로 수치 조절 가능 |
| 1 | 핵심 전투 + 기본 터치 | 봇과 한 판을 끝까지 할 수 있고(키보드·터치), 강하게 맞으면 확실히 날아간다 |
| 2 | 전투 확장 + 아이템 + 4버튼 터치 | 아이템을 먼저 줍기 위한 눈치 싸움이 생긴다 |
| 3 | 캐릭터와 연출 | 캡슐 버전과 조작감이 같으면서 보기에 재밌고, 모바일 60fps 유지 |
| 4 | 경기장 | 경기장마다 싸우는 방식이 달라진다 |
| 5 | 스타일 + 로컬 2인 | 스타일마다 이기는 방법이 다르다 |
| 6 | 온라인 대전 | 서로 다른 기기(모바일↔데스크톱↔웹) 4인이 방 코드로 한 판을 끝낸다 |

---

## 11. 작업 규칙 (Claude Code)

- 한 번에 한 Phase만 진행하고, 끝나면 완료 기준을 스스로 점검한 뒤 보고한다
- 새 수치가 생기면 반드시 `GameConfig`에 추가한다 (디버그 패널은 자동 반영)
- `sim/`에 노드·렌더링·물리 엔진·`Input` 의존성을 넣지 않는다
- 조작감 관련 결정은 임의로 확정하지 말고, 수치로 노출해서 사람이 조절하게 한다
- sim 변경은 테스트 먼저 작성한다 (TDD)
- 에셋 라이선스(CC0 여부)를 `ASSETS.md`에 기록한다
- 문서 간 추적 규칙은 [`README.md`](./README.md)를 따른다

---

## 12. 요구사항 ID 색인

PHASES.md 태스크와 design.md 항목은 아래 ID로 이 문서를 참조한다. ID는 한 번 부여하면 바꾸지 않는다 (폐기 시 ~~취소선~~ 처리).

| ID | 요구사항 | 근거 절 |
|---|---|---|
| PRD-CORE-01 | 새 기능은 핵심 재미 3요소 중 하나를 강화해야 한다 | §1.1 |
| PRD-PLT-01 | Android/iOS 주력 지원, 가로 고정, Mobile 렌더러 | §2 |
| PRD-PLT-02 | Windows/macOS 지원 | §2 |
| PRD-PLT-03 | Web(스레드 없음, Compatibility) 데모 빌드, Cloudflare Pages | §2 |
| PRD-PLT-04 | Linux 헤드리스 dedicated server 빌드 | §2 |
| PRD-PLT-05 | 툰 셰이더·이펙트가 Mobile·Compatibility 렌더러 모두에서 동작 | §2 |
| PRD-CTL-01 | 모든 입력원은 `InputFrame`으로 추상화 | §3.1 |
| PRD-CTL-02 | 키보드·게임패드 6액션, InputMap 정의 | §3.2 |
| PRD-CTL-03 | 터치: 플로팅 가상 스틱 + 4버튼 (탭/홀드, 컨텍스트 잡기) | §3.3 |
| PRD-CTL-04 | 터치 멀티터치 동시 입력 | §3.3 |
| PRD-RULE-01 | 누적 대미지 % 방식 | §4.1 |
| PRD-RULE-02 | 스톡 3, 링아웃(`kill_y`·경계) | §4.1 |
| PRD-RULE-03 | 공중 리스폰 + 2초 무적 | §4.1 |
| PRD-RULE-04 | 넉백 공식 | §4.2 |
| PRD-RULE-05 | hitstun(조작 불가), hitstop(양측 정지) | §4.2 |
| PRD-CMB-01 | 약공격 3타 콤보 + 입력 버퍼 | §4.3 |
| PRD-CMB-02 | 강공격 홀드 차지 | §4.3 |
| PRD-CMB-03 | 가드 | §4.3 |
| PRD-CMB-04 | 잡기 → 던지기 | §4.3 |
| PRD-ITEM-01 | 아이템 상자 주기 낙하 | §4.4 |
| PRD-ITEM-02 | 방망이 | §4.4 |
| PRD-ITEM-03 | 폭탄 | §4.4 |
| PRD-ITEM-04 | 돌멩이 | §4.4 |
| PRD-CFG-01 | 모든 수치 `GameConfig` + 인게임 디버그 패널 실시간 조절 | §4.5, §5.2 |
| PRD-ARCH-01 | sim/렌더 분리 (sim은 순수 로직) | §5.2 |
| PRD-ARCH-02 | 60Hz 고정 틱 + 렌더 보간 | §5.2, §5.4 |
| PRD-ARCH-03 | 공격·스타일·경기장·아이템 데이터 주도 | §5.2 |
| PRD-ARCH-04 | sim 상태 snapshot/restore | §5.2 |
| PRD-ARCH-05 | 시드 RNG 기반 결정성 | §5.2 |
| PRD-NET-01 | 서버 권위 (헤드리스 Godot, 입력만 전송) | §5.5 |
| PRD-NET-02 | 자기 캐릭터 예측·재조정, 타 캐릭터 보간 | §5.5 |
| PRD-NET-03 | 방 코드 입장·최대 4인·로비 API | §5.5 |
| PRD-DATA-01 | 로컬 설정·기록은 기기 `user://`에 저장 | §5.1 |
| PRD-DATA-02 | 서버 데이터(방 코드·로비, 향후 계정·랭킹)는 Supabase | §5.1, §5.5 |
| PRD-ARENA-01 | 호숫가 캠프장 | §6.1 |
| PRD-ARENA-02 | 통나무 다리 | §6.1 |
| PRD-ARENA-03 | 버섯 숲 | §6.1 |
| PRD-ARENA-04 | 안개 낀 숲 | §6.1 |
| PRD-STYLE-01 | 권투형 | §6.2 |
| PRD-STYLE-02 | 무기형 | §6.2 |
| PRD-STYLE-03 | 원거리형 | §6.2 |
| PRD-LOCAL-01 | 데스크톱 로컬 2인 (키보드 분할·패드) | §3.2, §10 |
| PRD-FX-01 | 캐릭터 모델 + 애니메이션 상태 | §6.3 |
| PRD-FX-02 | 타격·먼지·링아웃 이펙트, 효과음 | §6.3 |
| PRD-FX-03 | 소프트 툰 셰이딩 (외곽선 없음) | §6.3 |
| PRD-BOT-01 | 봇 1단계 | §6.4 |
| PRD-BOT-02 | 봇 2단계 (가드·아이템·스타일 사거리) | §6.4 |
| PRD-UI-01 | 인게임 HUD (대미지 %, 스톡), 승패·재시작 | §6.5 |
| PRD-UI-02 | 메뉴 화면 흐름 (모드·캐릭터·경기장 선택) | §6.5 |
| PRD-NFR-01 | 모바일 60fps / 저사양 30fps 모드 | §7 |
| PRD-NFR-02 | sim 1틱 ≤ 2ms | §7 |
| PRD-NFR-03 | 로컬 입력 지연 ≤ 3프레임 | §7 |
| PRD-NFR-04 | RTT 150ms 조작감 | §7 |
| PRD-NFR-05 | 빌드 크기 (모바일 150MB, 웹 40MB) | §7 |
| PRD-NFR-06 | sim 테스트 커버리지 80%+, 헤드리스 CI | §7 |
| PRD-NFR-07 | 에셋 라이선스 `ASSETS.md` 기록 | §7 |
