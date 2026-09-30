# phase-4 — Plan

승인: 2026-09-30 (사용자). Phase 4·5 + 로그인·트래킹·배포 통합 계획 전문. 이 트랙 범위는 context 파일 참조.


## Context
Phase 0~3 완료, GitHub 원격 연결·push 완료. 사용자 요청:
1. Phase 4(경기장)·5(스타일·로컬 2인·필살기) 시작
2. **Amplitude로 게임 전 요소 트래킹** — 목적은 데이터 분석(밸런스·퍼널·리텐션). 핵심 순간+요약은 Amplitude, **원시 행동 로그는 Supabase**
3. Supabase: 경기 기록 테이블 + Auth. **로그인은 Google OAuth**
4. Vercel: 웹 빌드 배포. 첫 화면은 **로그인 창** — 배경에서 카메라가 원형 경기장을 돌며 캐릭터들이 싸우고, 로그인 패널이 다이나믹하게 등장. 디자인은 시안 2~3개 비교 후 확정

현재 코드 사실(탐색 결과):
- sim 이벤트(`hit`, `guard_hit`, `ringout`, `grab`, `item_*`, `explosion`)는 `World.state_view()["events"]`로 매 틱 나오고, 렌더 전용 `ViewEvents`(`respawned`,`jumped`,`landed`,`trail`)가 있다 → **트래킹은 렌더 쪽에서 이벤트를 소비만** 하므로 sim·리플레이 해시에 영향 없음
- 경기 시작/종료 이벤트 없음(상태 flip만), 메뉴·씬 전환 없음, autoload 없음, HTTP/JSON/`user://` 사용 없음
- 경기장은 `Collision`의 하드코딩 원, 공격은 `AttackSet.from_config`, 캐릭터 모델은 슬롯 고정(`CharacterCatalog.for_player`)
- `vercel`·`supabase` CLI 미설치 (node/npm 있음 → `npx vercel`)

## 전체 순서 (트랙 4개)
```
T0 문서·dev docs ─┬─ A 플랫폼(비밀키·Analytics·Supabase·Auth) ─┐
                  └─ P4-sim(ArenaData·기믹, 워크트리 병렬) ─────┤
                                                              B 앱 셸 + 로그인 화면(🖼 시안 게이트)
                                                              ↓
                                                              Phase 4 UI(경기장 선택) → Phase 5 → Vercel 배포
```
트래킹은 별도 마지막 단계가 아니라 **각 기능을 만들 때 같이 단다** (이벤트 카탈로그 테스트로 강제).

---

## T0. 문서 선행 (README §4 전파 규칙)
- PRD: 신규 ID — `PRD-AUTH-01`(Google 로그인, §8 범위 밖에서 이동), `PRD-DATA-03`(Amplitude 이벤트), `PRD-DATA-04`(Supabase 원시 로그·경기 기록), `PRD-PLT-03` 배포 대상 Cloudflare Pages → **Vercel**
- PHASES: Phase 4 앞에 "4.0 플랫폼" 태스크, Phase 5에 트래킹 태스크, 커버리지 표 갱신
- design.md: `DS-CMP-14 LoginPanel`, `DS-LAY-03` 메뉴 배경(궤도 디오라마) 구체화, §12 추적표
- 신규 `docs/tracking-plan.md` — 이벤트 SSOT (아래 표)
- `dev/active/{platform,phase-4,phase-5}/` plan·context·tasks

## A. 플랫폼 레이어 (`src/platform/`, 전부 렌더/앱 쪽, sim 무관)
1. **비밀키**: `config/secrets.example.cfg`(커밋) + `config/secrets.local.cfg`(gitignore) — `amplitude.api_key`, `supabase.url`, `supabase.anon_key`, `auth.redirect_web`. 둘 다 클라이언트 공개용 키라 export에 포함돼도 됨(service_role 키는 절대 넣지 않음 — 체크 스크립트로 `service_role` 문자열 차단). `Secrets.load()`는 없으면 트래킹/로그인 비활성 + 경고(조용히 삼키지 않음)
2. **`Analytics` autoload** (`src/platform/analytics/`)
   - Amplitude HTTP API v2 (`https://api2.amplitude.com/2/httpapi`) 배치 전송: 20건 또는 10초마다, 경기 종료·앱 종료 시 flush
   - `device_id`(`user://` 저장 UUID), `user_id`(Supabase uid), `session_id`, 공통 속성: platform, os, build_version, locale, quality, input_device
   - 실패 시 `user://analytics_queue.json`에 보존 후 재시도(지수 백오프, 상한)
   - `EventCatalog`: 이벤트 이름·필수 속성 스키마. 카탈로그에 없는 이벤트/누락 속성은 debug에서 assert, 테스트에서 실패
   - headless·테스트·`ds_gallery`에서는 자동 비활성
3. **`SupabaseClient`** (`src/platform/supabase/`): HTTPRequest 래퍼 — Auth(`/auth/v1`), REST(`/rest/v1`) insert, 토큰 자동 갱신
4. **Google OAuth (Supabase Auth, PKCE)**
   - 웹: `/auth/v1/authorize?provider=google&redirect_to=<vercel URL>` 리다이렉트 → 복귀 시 `JavaScriptBridge`로 `?code=` 읽어 토큰 교환 → URL 정리
   - 데스크톱: `TCPServer` 루프백(127.0.0.1 고정 포트) + `OS.shell_open` → 콜백에서 code 받아 교환
   - 세션(refresh token) `user://session.cfg` 저장, 앱 시작 시 자동 갱신 → 로그인 화면 생략
   - Android/iOS: 딥링크 플러그인 필요 → **이번 범위 밖**. 모바일은 debug 빌드 한정 "건너뛰기"(트래킹은 device_id로)
5. **DB 스키마** `supabase/migrations/0001_match_telemetry.sql`
   - `profiles(id=auth.uid, display_name, created_at)`
   - `matches(id uuid, user_id, mode, arena, player_count, seed, started_at, duration_ticks, winner_slot, build_version, platform)`
   - `match_players(match_id, slot, is_bot, character, style, input_device, result, stocks_left, damage_dealt, damage_taken, hits, ringouts_scored, specials, items_used, falls_by_gimmick)`
   - `match_events(match_id, tick, type, actor_slot, target_slot, payload jsonb)` — 원시 sim 이벤트 + 주기 위치 샘플(0.5초), 경기 종료 시 500행 청크 insert
   - RLS: 본인 `user_id` 행만 insert/select, anon 차단. 인덱스(match_id, type)
   - CLI가 없으므로 SQL 파일을 드리면 대시보드 SQL Editor에서 실행(또는 `npx supabase db push`)

### Amplitude 이벤트 카탈로그 (요약, 상세는 tracking-plan.md)
| 영역 | 이벤트 |
|---|---|
| 앱·세션 | `app_opened`, `app_backgrounded`, `app_closed`, `perf_sampled`(경기별 평균/p95 fps·tick ms) |
| 로그인 | `login_viewed`, `login_started`, `login_completed`, `login_failed`(reason), `session_restored`, `logout` |
| 메뉴 퍼널 | `screen_viewed`(screen), `mode_selected`, `character_selected`(slot, character, style), `arena_selected`, `select_cancelled` |
| 경기 | `match_started`(mode, arena, 캐릭터들, 봇 수, 입력장치), `match_ended`(result, duration, 슬롯별 요약), `match_abandoned`, `rematch_clicked` |
| 전투 핵심 | `stock_lost`(victim, 마지막 가격자, 사망 대미지%, 원인: 넉백/기믹/자멸, 경기장 구역·각도), `special_used`, `special_hit`, `gauge_full` |
| 아이템 | `item_picked_up`, `item_used`(bat 휘두름/투척/폭발), `item_hit` |
| 경기장 | `gimmick_triggered`(kind, 피해자), `gimmick_ringout` |
| 설정·입력 | `settings_changed`(key, old, new), `quality_changed`, `input_device_changed`, `touch_layout_changed` |
| 오류 | `net_error`(endpoint, status) |
- 고빈도(타격·가드·잡기·점프·콤보)는 `match_ended` 슬롯 요약 속성 + Supabase `match_events` 원시
- `MatchTelemetry`(RefCounted, 렌더 쪽): 매 프레임 `events`+`view_events`+state view를 받아 누적·발행. 공격 헛스윙은 view의 `attack_kind` 전이로 검출

## B. 앱 셸 + 로그인 화면
- `src/app/app.tscn`(신규 메인 씬): 화면 스택 `login → title/mode → character → arena → match → result`, 전환은 `UiMotion` 토큰
- 기존 `main.tscn`은 `MatchScene`으로 두고 `MatchSetup`(mode, arena, 슬롯별 character/컨트롤러) 주입. `_start_match`가 이 설정을 사용
- **메뉴 배경 디오라마** `src/app/menu_backdrop.gd`: 봇 4명 `World`+`BotController`(재사용) + `ArenaView`/`DecorView`/`EnvironmentRig` + 궤도 카메라(`CameraFraming.arena_anchors` 거리 재사용, yaw 회전), 메뉴 BGM(`MusicDirector.play_menu`)
- 🖼 **로그인 시안 3개** 실제 게임 캡처로 비교: ① 중앙 카드가 아래서 스프링 팝 ② 좌측 세로 패널이 슬라이드 + 우측 타이틀 로고 ③ 로고가 먼저 쾅 떨어진 뒤 버튼이 순차 등장 — 승인 후 `LoginPanel`(DS-CMP-14) 확정, 갤러리 등록
- `MenuButton`·`Panel`(DS-CMP-06/07) 여기서 확정

## Phase 4 — 경기장 (PHASES 그대로 + 트래킹)
- sim: `ArenaData` Resource(`src/sim/arena/`) — 바닥 도형(원/사각 발판 목록), 링아웃 영역, 기믹 목록, 테마. `Collision`이 ArenaData 기반으로 판정, 기본 원형 경기장이 현재와 동일 동작
- 기믹(sim, 결정적): 화상 영역(캠프파이어 DoT), 파괴 발판(다리, 시간/피격 파괴), 튕김 발판(버섯), 주기 이벤트(안개). 이벤트 `gimmick_damage`/`platform_break`/`bounce`/`fog_start|end` 추가
- 경기장 4종 + 테마 변형(DS-THM-02), 위험 표시(DS-VIS-04), 안개 실루엣(DS-VIS-03), 장식 가림 검사
- Phase 3 이월 sim 이슈(hitstop 입력 삼킴, 방망이 밸런스, 동틱 상호타격 편향) 이번에 처리
- UI: `SelectCard`(DS-CMP-08), 경기장 선택 화면
- 리플레이: GOLDEN/BEHAVIOR 해시 **의도적 갱신**(사유 커밋 메시지 기록) + 경기장별 해시 추가
- **P4-sim은 워크트리에서 A와 병렬 진행**

## Phase 5 — 스타일 + 필살기 + 로컬 2인
- `StyleData`(공격 목록·이동 오버라이드), `AttackSet`이 스타일별로 구성. 권투/무기/원거리(투사체)
- **캐릭터 4 = 모델 + 스타일 + 고유 필살기** (제안, 승인 시 확정): Barbarian=권투(대지 강타), Rogue=권투(돌진 연타), Knight=무기(회전 베기), Mage=원거리(거대 화염구)
- 필살기: 때리거나 맞으면 차는 게이지(sim), 가득 차면 X+C 동시 입력으로 1회 발동. sim은 결정적, 발동 시 **렌더 전용 컷인**(카메라 완전 확대 + 캐릭터 모션, 슬로우 연출은 렌더 시간만)
- 봇: 스타일별 사거리 인식, 필살기 사용
- 로컬 2인: P2 = **WASD 이동 + Q 점프, F 약 · G 강 · H 가드 · J 잡기** (제안) + 게임패드 자동 할당. `LocalInput` 액션 접두사 파라미터화
- 캐릭터 선택 + `PlayerSlot`(DS-CMP-10), P1~P4 색+번호+링 모양, 입력장치 프롬프트 아이콘
- 밸런스 시뮬: 봇 대 봇 매치업 100판 → 승률표(30~70%) + CSV 출력

## Vercel 배포
- `vercel.json`(정적, `.wasm`/`.pck` 캐시·MIME 헤더), `scripts/deploy_web.sh`: Godot 웹 export → `npx vercel deploy build/web --prod`
- 웹 도메인을 Supabase Auth redirect 허용 목록에 추가해야 함

## 사용자가 직접 해야 할 일 (제가 대신 못 하는 것)
1. `config/secrets.local.cfg`에 Amplitude API key, Supabase URL·anon key 입력
2. Supabase 대시보드: Authentication → Providers → Google 활성화(Google Cloud OAuth 클라이언트 ID/secret), Redirect URLs에 Vercel 도메인과 `http://127.0.0.1:<포트>/callback` 추가
3. 마이그레이션 SQL 실행(SQL Editor)
4. `npx vercel login` 1회 (계정 로그인은 제가 못 함)

## 검증
- `scripts/test.sh` 전부 통과, sim 커버리지 80%+, `check-sim-purity`·`check-colors`·`check-docs` 통과
- 신규 단위 테스트: EventCatalog 스키마, Analytics 배치·오프라인 큐(HTTP 모킹), MatchTelemetry(고정 이벤트 시퀀스 → 기대 이벤트·요약값), PKCE 생성·콜백 파싱, 기믹별 sim, StyleData 로딩, 필살기 게이지·발동, P2 입력
- 리플레이: 경기장별·스타일별 해시
- 실동작: 데스크톱 실행 → Google 로그인 → 경기 1판 → Amplitude 이벤트 도착 확인(Amplitude 커넥터 인증 시 MCP로 직접 조회) + Supabase `matches`/`match_events` 행 확인
- 웹: Vercel URL에서 로그인 리다이렉트·경기·이벤트 수신 확인
- 각 단계 후 code-reviewer, 플랫폼 단계 후 security-reviewer(키·RLS)
