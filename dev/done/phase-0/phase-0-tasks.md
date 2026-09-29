# Phase 0 — Tasks

**Last Updated:** 2026-09-29
상세 단계와 코드: [`phase-0-plan.md`](./phase-0-plan.md) · 결정·이슈: [`phase-0-context.md`](./phase-0-context.md)

## 사전 조건
- [ ] 레퍼런스 이미지 `docs/references/ref-a-sunny-forest.png` 배치 (사용자 제공 대기)
- [x] 다운로드 승인 (Godot, GUT, 폰트, 템플릿 · JDK/SDK는 기존 설치본)

## 태스크

| # | 태스크 | 근거 ID | 검증 | 상태 |
|---|---|---|---|---|
| T1 | 환경 설치 + 프로젝트 골격 + 테스트 러너 | PRD-ARCH-01, PRD-NFR-06 | `test_smoke` 3/3 | ✅ |
| T2 | InputFrame + GameConfig | PRD-CTL-01, PRD-CFG-01 | `test_input_frame`, `test_game_config` | ✅ |
| T3 | FixedTicker (60Hz 누산기) | PRD-ARCH-02 | `test_fixed_ticker` 6/6 | ✅ |
| T4 | World 골격 + sim 순수성 검사 | PRD-ARCH-04, PRD-ARCH-05 | `test_world` 4/4, `check-sim-purity.sh` | ✅ |
| T5 | DS 토큰 v0 + 폰트 + 색 검사 | DS-TOK-01~05, DS-GOV-01, PRD-NFR-07 | `test_color_utils`, `test_tokens`, `check-colors.sh` | ✅ |
| T6 | ThemeBuilder → forest_theme.tres | DS-THM-01 | `test_theme_builder` 5/5 | ✅ |
| T7 | 디버그 패널 | PRD-CFG-01, DS-CMP-12 | `test_config_schema` 3/3 | ✅ |
| T8 | 카메라 | GD-CAM-01 | `test_camera_framing` 4/4 | ✅ |
| T9 | 소프트 툰 + 경기장·환경·식생 | DS-VIS-01, DS-VIS-02, DS-VIS-04, PRD-PLT-05 | 색 검사 + T10 스크린샷 | ✅ |
| T10 | main 연결 (루프·카메라·패널) | PRD-ARCH-02, PRD-CFG-01 | 데스크톱 수동 검증 + 스크린샷 2장 | ✅ |
| T11 | DS 갤러리 | DS-GOV-02 | 갤러리 스크린샷 | ✅ |
| T12 | Export 프리셋 + 멀티플랫폼 스모크 | PRD-PLT-01~04 | export 로그, Android·웹 스크린샷 | ✅ (Android APK만, 실기기 대기) |
| T13 | 문서 검사 + 완료 점검 + 리뷰 | README R3·R4 | `check-all.sh` ALL PASSED, 코드 리뷰 | ✅ |

상태: ⬜ 예정 · 🟨 진행 · ✅ 완료

## Phase 0 완료 기준 (PHASES.md)
- [ ] 빈 경기장이 데스크톱·Android 실기기·웹에서 뜬다 — 데스크톱·웹 ✅, Android APK 빌드 완료·실기기 대기
- [x] 디버그 패널 `arena_radius` → 바닥 크기 즉시 변경
- [ ] 소프트 툰이 세 플랫폼에서 깨지지 않는다 — 데스크톱·웹 ✅, Android 대기
- [x] DS 갤러리가 확정 팔레트·타이포를 보여준다
- [x] `scripts/check-all.sh` 통과
