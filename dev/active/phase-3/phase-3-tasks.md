# Phase 3 — Tasks

**Last Updated:** 2026-09-30
**상태:** 구현 완료, 최종 리뷰 대기
상세 단계와 코드: [`phase-3-plan.md`](./phase-3-plan.md) · 결정·이슈: [`phase-3-context.md`](./phase-3-context.md)

## 사전 조건
- [x] context의 사용자 확인 대기 결정 F1~F11 승인
- [x] KayKit Adventurers glb 4개 다운로드 승인 (T2 직전)
- [ ] 🖼 캐릭터 룩 게이트 (T7, 사용자 수행 — 지연 시 A안으로 진행) — 🖼 대기, A안 유지
- [ ] 실기기 (Android·iOS) — 없어서 60fps 기준은 대기 표시

## 태스크

| # | 태스크 | 근거 ID | 검증 | 상태 |
|---|---|---|---|---|
| T1 | config 지문 sim 그룹 한정 + BEHAVIOR_HASH 고정 | PRD-ARCH-05, F1 | `test_game_config`, `test_replay` | ✅ |
| T2 | KayKit 가져오기 + 클립 조사 + CharacterCatalog | PRD-FX-01, PRD-NFR-07, F3 | `test_character_catalog` | ✅ |
| T3 | AnimMap + AnimClips | GD-ANIM-01, F4 | `test_anim_map`, `test_anim_clips` | ✅ |
| T4 | 소프트 툰 v2 + 외곽선 + 룩 프리셋 | DS-VIS-01, PRD-FX-03, F6 | `test_look_preset` | ✅ |
| T5 | CharacterModel + FighterView 교체 | PRD-FX-01, PRD-ARCH-01 | `test_character_model`, `test_fighter_view` + 스크린샷 | ✅ |
| T6 | CharacterAnimator (AnimationTree, 늘이기, 히트스톱) | GD-ANIM-01, F5 | `test_character_animator` + 룩 3안 캡처 | ✅ |
| T7 | 🖼 캐릭터 룩 게이트 | DS-VIS-01, DS-VIS-02 | 결정 기록 | 🖼 대기 |
| T8 | 품질 3단계 + 블롭 그림자 | PRD-NFR-01, F7 | `test_quality` + 캡처 | ✅ |
| T9 | ViewEvents + 착지 먼지 + 넉백 궤적 | DS-VFX-03, DS-VFX-04, GD-FEEL-04, F8 | `test_view_events`, `test_vfx` | ✅ |
| T10 | 링아웃·리스폰·차지 광·카메라 펀치·떨어뜨린 아이템 | DS-VFX-05, DS-VFX-06 | `test_vfx`, `test_item_view` + 영상 | ✅ |
| T11 | SfxSynth + 레시피 + 굽기 | DS-SFX-01, F9 | `test_sfx_synth` | ✅ |
| T12 | 오디오 버스 + SfxDirector + UI 소리 | DS-SFX-01 | `test_audio`, `test_view_events` | ✅ |
| T13 | MusicDirector + 임시 BGM | DS-SFX-02, F10 | `test_music` | ✅ |
| T14 | UiMotion 모션 토큰 적용 | DS-TOK-05 | `test_ui_motion` | ✅ |
| T15 | 갤러리 VFX·SFX·캐릭터 프리뷰 | DS-GOV-02 | `test_gallery` + 캡처 | ✅ |
| T16 | iOS export + 빌드 크기 검사 | PRD-PLT-01, PRD-NFR-05, F11 | `build_all.sh`, `check_build_size.sh` | ✅ |
| T17 | 4인 봇전 성능 측정 + 웹 툰 캡처 | PRD-NFR-01, PRD-PLT-05 | `test_main_smoke` + performance.md + 캡처 | ✅ |
| T18 | Phase 3 마감 | README R3·R4 | `check-all.sh` | ✅ |

상태: ⬜ 예정 · 🟨 진행 · ✅ 완료 · 🖼 대기

## Phase 3 완료 기준 (PHASES.md)
- [x] 캡슐 버전과 같은 리플레이 해시 → 조작감 동일 (BEHAVIOR_HASH 1822125224, 61bd3ba)
- [ ] 중급 모바일 기기 4인 봇전 60fps 유지 (프로파일러 캡처) — 실기기 확인 대기
- [x] 모바일 빌드 ≤ 150MB, 웹 초기 로딩 ≤ 40MB
- [ ] 웹(Compatibility)에서도 툰 룩이 유지된다 (스크린샷 비교) — 최종 수정 단계에서 조정 중
