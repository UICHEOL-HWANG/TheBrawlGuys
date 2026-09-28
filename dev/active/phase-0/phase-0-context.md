# Phase 0 — Context

**Last Updated:** 2026-09-28 15:10 KST
**상태:** 계획 완료, 구현 전 (Task 1 대기)
**계획:** [`phase-0-plan.md`](./phase-0-plan.md) · **체크리스트:** [`phase-0-tasks.md`](./phase-0-tasks.md)

---

## 사전 조건 (구현 시작 전)

- [ ] 사용자가 레퍼런스 이미지를 `docs/references/ref-a-sunny-forest.png`에 넣는다 (Claude는 채팅 첨부 이미지를 파일로 저장할 수 없음)
- [ ] 다운로드 단계 승인: Godot(brew), GUT, Jua·Pretendard 폰트, export 템플릿, JDK 17, Android SDK
- [ ] Android 실기기 1대 + USB 디버깅

## 확정된 결정

| 결정 | 내용 | 출처 |
|---|---|---|
| 엔진·언어 | Godot 4.5+, GDScript 정적 타입. 병목 시 GDExtension | PRD §5.1, §5.6 |
| sim 구조 | 자체 순수 로직 sim (Godot 물리 미사용), `RefCounted` | brainstorming A안, PRD §5.2 |
| 플랫폼 | 모바일 주력 + 데스크톱 + 웹(데모) + 헤드리스 서버 | PRD §2 |
| 온라인 | Godot 헤드리스 전용 서버, WebSocket | PRD §5.5 |
| 터치 | 가상 스틱 + 4버튼 | PRD §3.3 |
| 비주얼 | 레퍼런스 A: 외곽선 없는 소프트 툰, 구 클러스터 식생 | design.md §0 |
| 팔레트 | A안 "한낮 햇살" 확정 (2026-09-28) | design.md DS-TOK-01 |
| 프로젝트 루트 | `/Users/uicheol_hwang/Games` (project.godot 위치). `docs/`, `dev/`는 `.gdignore`로 임포트 제외 | plan T1 |
| 테마 | `ThemeBuilder` → `forest_theme.tres` 생성 후 `gui/theme/custom`으로 지정. 생성물과 빌더의 동기화는 테스트로 감시 | plan T6 |
| 3D 비주얼 토큰 | 글로벌 셰이더 파라미터(`ds_shadow_tint`, `ds_band_softness`)를 `project.godot`에 둔다. 원천은 design.md DS-VIS-01 | plan T9 |
| 테스트 범위 | 계산 로직(FixedTicker, World, CameraFraming, ConfigSchema, ColorUtils, ThemeBuilder)은 GUT 단위 테스트, 렌더 노드는 스크린샷 증거 | plan 경계 원칙 |

## 계획 작성 중 발견해 design.md에 반영한 수정

- `ui_text_soft` `#4C7F7A` → `#3F7470` (크림 바탕 대비 4.46 → 5.2, WCAG AA 충족)
- `dirt` `#8A6B55` 토큰 추가 (경기장 흙 단면. 시안에는 있었으나 표에서 누락)

## 핵심 파일

| 파일 | 역할 |
|---|---|
| `src/main/main.gd` | 진입점, 60Hz 루프, 보간 계약 |
| `src/main/fixed_ticker.gd` | 누산기 |
| `src/sim/world.gd` | sim 상태, snapshot/restore |
| `src/config/game_config.gd` | 모든 수치 |
| `src/ui/theme/tokens.gd` | DS 토큰 |
| `src/render/shaders/soft_toon.gdshader` | 소프트 툰 |
| `src/debug/config_panel.gd` | 디버그 패널 |
| `src/debug/ds_gallery.tscn` | DS 갤러리 |

## 의존성

| 항목 | 버전·출처 | 용도 |
|---|---|---|
| Godot | 4.5+ (brew cask `godot`) | 엔진·CLI |
| GUT | 9.x (github.com/bitwes/Gut) | 테스트 |
| Jua | Google Fonts, OFL | 디스플레이 폰트 |
| Pretendard | github.com/orioncactus/pretendard, OFL | 본문 폰트 |
| JDK | Temurin 17 | Android export |
| Android SDK | platform 34, build-tools 34.0.0 | Android export |

## 열린 이슈

1. **커버리지 80% 측정**: GDScript용 표준 커버리지 도구가 없다. Phase 0은 "계산 로직은 전부 테스트"로 대신하고, Phase 1 시작 전에 도구를 조사(GUT 플러그인 등)하거나 PRD-NFR-06 문구를 조정할지 결정한다.
2. **Compatibility 렌더러 차이**: 웹에서 블룸·글로벌 셰이더 파라미터가 동작하는지 Task 12에서 확인한다. 차이가 있으면 아래 "알려진 차이"에 기록.
3. **Linux Server 실행 검증**: macOS에서는 x86_64 리눅스 바이너리를 실행할 수 없다. Phase 0은 export 성공까지만 보고, 실행은 Phase 6(또는 Docker를 쓸 수 있으면 선택)에서 한다.

## 알려진 차이 (구현 중 기록)

- **웹(Compatibility/gl_compatibility) 블룸**: Task 12 웹 스모크(`dev/active/phase-0/evidence/web-arena.png`, 2048×1536, 실제 브라우저 렌더)에서 소프트 툰 셰이딩과 색조 그림자(`ds_shadow_tint`)는 데스크톱과 동일하게 보였으나, 눈에 띄는 블룸 글로우는 확인되지 않았다(원래 씬에 강한 블룸 소스가 없어 차이가 미미할 수 있음 — 대조군 스크린샷과의 나란히 비교는 하지 않음). 차단 사유 아님, Phase 1 비주얼 폴리시 단계에서 재확인 권장.
