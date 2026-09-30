# Platform (로그인 · 트래킹 · 배포) — Context

**Last Updated:** 2026-09-30
**상태:** 시작
**계획:** [`platform-plan.md`](./platform-plan.md) · **체크리스트:** [`platform-tasks.md`](./platform-tasks.md)

## 범위
계획의 A(플랫폼 레이어), B(앱 셸 + 로그인 화면), Vercel 배포. Phase 4·5 기능의 트래킹 이벤트는 각 Phase 태스크에서 단다.

## 사용자 결정 (2026-09-30)
| 질문 | 선택 |
|---|---|
| 이벤트 입자도 | Amplitude = 핵심 순간 + 경기 요약, Supabase = 원시 행동 로그 |
| Supabase 용도 | 경기 기록(matches · match_players · match_events) + Auth |
| 로그인 | Google OAuth만 (Supabase Auth, PKCE) |
| Vercel | 웹 빌드 배포. 첫 화면 = 로그인 창, 배경은 궤도 카메라 + 봇 난투 디오라마 |
| 로그인 디자인 | 🖼 시안 3개 비교 후 확정 |
| 키 전달 | `config/secrets.local.cfg` (gitignore) 에 사용자가 직접 입력 |

## 핵심 파일
- 신규: `src/platform/{secrets,analytics,supabase,auth}/`, `src/app/`, `supabase/migrations/`, `vercel.json`, `scripts/deploy_web.sh`, `docs/tracking-plan.md`
- 수정: `project.godot` (main scene · autoload), `src/main/main.gd` (MatchSetup 주입, 텔레메트리 훅), `export_presets.cfg` (secrets 포함)

## 결정
- P1: 트래킹은 렌더/앱 쪽에서 sim 이벤트를 **소비만** 한다 → sim·리플레이 해시 불변
- P2: 모바일 Google 로그인(딥링크)은 이번 범위 밖. 모바일 debug 빌드만 "건너뛰기"
- P3: 클라이언트에는 공개 키(Amplitude API key, Supabase anon key)만. `service_role`은 체크 스크립트로 차단
- P4: Supabase/Vercel CLI 미설치 → 마이그레이션은 SQL Editor, 배포는 `npx vercel`

## 사용자 대기
- [x] secrets.local.cfg 입력 (Amplitude·Supabase 키 유효 확인)
- [x] Supabase Google provider 활성화 + Redirect URL 등록 (2026-09-30 확인: authorize → accounts.google.com 302)
- [ ] 마이그레이션 SQL 실행
- [x] `npx vercel login` — uicheol-hwang / team cheorish (Hobby), 2026-09-30
- [ ] Amplitude MCP 커넥터 인증 (검증용, 선택)
