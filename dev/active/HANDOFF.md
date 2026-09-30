# 인수인계 — 다음 세션 시작점

**Last Updated:** 2026-09-30 21:00
**main:** `0c7a470` 뒤 인수인계 커밋 (Phase 4 render 병합까지). GitHub push는 이 파일 커밋까지 반영.
**배포:** https://thebrawlguys.cloud (Vercel `cheorish/thebrawlguys`, 네임서버 vercel-dns). 배포된 빌드는 `c88d9a4` 시점(경기장 선택 이전)

새 세션은 이 파일 → `dev/active/{platform,phase-4,phase-5}/*-context.md` → `*-tasks.md` 순으로 읽고 시작한다.
사용자 규칙: 한국어 대화, .gd ≤200줄·함수 <40줄 모듈화(메모리 `modular-short-files`), 커밋 트레일러 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, `--no-verify` 금지(pre-commit 훅이 키 문자열 차단).

---

## 1. 병합 대기 브랜치 — ✅ 2026-09-30 21:00 세 개 모두 main 병합(812 테스트·check-all 통과), 재배포(Ready), push `749b3ec`

| 순서 | 브랜치 | 내용 | 테스트 | 예상 충돌 |
|---|---|---|---|---|
| 1 | `fix/phase4-review` | Phase 4 리뷰 수정 #1~#14 + 경기장 선택 레이아웃(카드 세로 중앙, 뒤로 좌하단·안내 우하단) | 748 | 없음(0c7a470 기반) |
| 2 | `feat/mobile-ui` | 폰/태블릿 UI 배율(DS-LAY-04), 세로 모바일 웹 "가로로 돌려주세요", 터치 감지 | 644 | `project.godot` autoload, `analytics.gd`, `login_layout.gd`, docs 표 |
| 3 | `feat/email-otp` | 이메일 6자리 코드 로그인(Supabase OTP), TextField·CodeInput(DS-CMP-17/18) | 680 | docs 3종, platform dev docs, `ds_gallery.gd`, `event_catalog.gd`, `tokens.gd`, `test_event_catalog.gd` — 대부분 목록 추가라 "양쪽 유지" |

병합 절차: 순서대로 `git merge --no-ff <branch>` → 충돌은 양쪽 유지 → 매번 `scripts/test.sh` + `scripts/check-all.sh` → 전부 끝나면 `scripts/deploy_web.sh` → `git push origin main`.
주의: 테스트 중 다른 Godot 프로세스가 54321 포트를 쓰면 `test_login_gate::test_desktop_with_keys_is_available`가 간헐 실패(재실행 시 통과).

## 2. 중단된 작업

- `feat/phase5-sim` (worktree `.claude/worktrees/agent-af80a4d79377a2705`, WIP 커밋 `19338d6`): Phase 5 sim T1/T2/T3/T5/T6 진행 중 사용량 한도로 중단. **미완성·미검증**. 마지막 작업: 필살기 타격을 2-pass(접촉 수집 → 적용)로 바꾸는 중. 이어서: `scripts/test.sh` 먼저 돌려 상태 확인 → 아래 결정대로 마무리.
  - 캐릭터 4 = 모델+스타일+필살기: Barbarian 권투 "대지 강타" / Rogue 권투 "돌진 연타" / Knight 무기 "회전 베기" / Mage 원거리 "거대 화염구"
  - 게이지: 때리거나 맞으면 참, 가득 차면 X+C 같은 틱 입력으로 1회. sim 결정적, 이벤트 special_start / special_hit / gauge_full / projectile_*
  - 봇 스타일 사거리·필살기 사용, `scripts/balance_sim.gd` 매치업 100판 승률 30~70%, 리플레이 해시 의도적 갱신(커밋 사유)

## 3. 남은 작업 (우선순위)

1. 위 1번 병합 3개 + 재배포 + push
2. Phase 5 sim 마무리(2번) → 병합
3. Phase 5 나머지: 필살기 컷인 연출(렌더 전용, 완전 확대), 캐릭터 선택 화면(`App.SELECT_STEPS`에 추가) + PlayerSlot, P1~P4 식별(색+번호+링 모양), 로컬 2인(P2 = WASD/Q/F/G/H/J + 게임패드), 키 표시 바에 필살기(X+C) 키캡, 🖼 스타일 실루엣 시안, 온보딩 튜토리얼(T11)
4. 트래킹: 필살기·캐릭터 이벤트(special_used 등) 연결, `press_special` 피처
5. 🖼 사용자 확인 대기: Phase 4 경기장·아이템 룩(`dev/active/phase-4/evidence/`)
6. 알려진 부채: `fighter_view.gd` 235줄(setup 78줄), `capture_evidence.gd`는 `-s` 모드에서 Analytics autoload 때문에 main/app 씬을 못 엶, 웹 빌드는 `session_ended` 안 보냄, 30분 백그라운드 세션 분리 미구현

## 4. 사용자가 해야 할 일 (Supabase / 외부)

- [x] 마이그레이션 0002·0003 실행 (2026-10-01 확인: special_hits·match_inputs 존재) — 안 하면 경기 기록 업로드 실패(`match_inputs` 테이블 없음 확인됨)
- [ ] Authentication → URL Configuration: Site URL = `https://thebrawlguys.cloud`, Redirect URLs = `https://thebrawlguys.cloud`, `https://thebrawlguys.cloud/**`, `https://thebrawlguys.vercel.app`, `https://thebrawlguys.vercel.app/**`, `http://127.0.0.1:54321/**`
- [ ] 이메일 로그인: Email provider 켜기 + 가입 허용, OTP 6자리·600초, Magic Link·Confirm signup 템플릿에 `{{ .Token }}`(템플릿 문구는 feat/email-otp의 platform-context.md), 커스텀 SMTP(Resend 등) — 기본 SMTP는 팀원 주소만
- [ ] 웹 Google 로그인 실사용 확인(강력 새로고침 후) — 가짜 코드로는 멈춤 수정 확인됨, 진짜 로그인은 미확인
- [ ] (선택) Amplitude MCP 커넥터 인증 — 이벤트 수신을 Claude가 직접 조회하려면 필요

## 5. 참고

- 키: `config/secrets.local.cfg`(gitignore, `scripts/set_secrets.sh`로 입력). 웹 빌드에 포함되는 공개 키만.
- 배포: `scripts/deploy_web.sh` (Godot 웹 export → `npx vercel deploy --prod`). `build/web/.env.local`은 `.vercelignore`로 업로드 제외.
- 분석: `supabase/queries/analysis.sql`, 전략 `docs/analytics-strategy.md`, 이벤트 명세 `docs/tracking-plan.md`.
