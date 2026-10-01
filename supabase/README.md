# Supabase — TheBrawlGuys

경기 기록(`matches` · `match_players` · `match_events` · `match_inputs`)과 `profiles` 스키마. 근거: PRD-DATA-04, `dev/active/platform/platform-plan.md` §A.5.

## 적용 방법 (SQL Editor)

Supabase CLI를 쓰지 않으므로 대시보드에서 직접 실행한다.

1. Supabase 대시보드 → 프로젝트 → **SQL Editor** → **New query**
2. `migrations/0001_match_telemetry.sql` 내용을 전부 붙여넣고 **Run**
3. 같은 방법으로 `migrations/0002_replay_and_features.sql`, `migrations/0003_special_hits.sql`을 **Run** (0001 다음에, 순서대로)
   - ⚠️ **0003은 이벤트 스키마 4 빌드(필살기 트래킹)를 배포하기 전에 적용**한다 — 없으면 `special_hits` 열 때문에 `match_players` insert 전체가 실패해 경기 기록이 통째로 빠진다
   - **0005 (`rooms`, Phase 6 온라인)**: 온라인 로비 빌드를 배포하기 전에 적용. 없으면 "방 만들기"가 실패한다. 방장만 자기 방을 쓰고, 로그인한 사용자는 열린 방을 코드로 읽는다. 만료 방 정리는 `select public.cleanup_rooms();`(pg_cron 예시는 SQL 주석). 시그널링은 Realtime 브로드캐스트 채널 `realtime:room:<코드>`(공개 채널, 기본 켜짐)를 쓴다 — 대시보드에서 Realtime을 꺼 두지 않았는지 확인
4. **Table Editor**에서 다섯 테이블(`profiles`·`matches`·`match_players`·`match_events`·`match_inputs`)이 보이고, 각 테이블에 `RLS enabled` 표시가 있는지 확인
5. **Authentication → Policies**에서 테이블마다 정책이 보이는지 확인

스크립트는 다시 실행해도 안전하다(`if not exists`, 정책은 지운 뒤 재생성).

CLI를 쓸 경우: `npx supabase link --project-ref <ref>` 후 `npx supabase db push`.

## 보안 모델

- 게임 클라이언트는 **anon(publishable) 키 + 로그인한 사용자의 JWT**로만 쓴다. 서비스 키는 게임·저장소 어디에도 두지 않는다 (`scripts/check-secrets.sh`가 막는다).
- 모든 테이블에 RLS가 켜져 있고 정책은 `authenticated` 역할에만 있다. 로그인하지 않은 요청은 읽기·쓰기 모두 거부된다.
- `matches`는 `user_id = auth.uid()`인 행만 insert/select. `match_players`·`match_events`·`match_inputs`는 자기 `matches` 행에 딸린 것만 가능.
- 자식 테이블 insert 정책은 `matches`를 조회하므로 `matches_select_own` 정책을 지우면 안 된다.
- 삭제 정책이 없다. 사용자 데이터는 계정 삭제 시 cascade로만 지워진다.
- 텍스트 길이·`payload` 크기(4 KB)·`match_inputs.frames` 크기(1 MB)·슬롯 범위에 check 제약이 있다. 계정당 insert 양 제한(쿼터)은 아직 없다.
- `auth.users`에 사용자가 생기면 `handle_new_user` 트리거(security definer, `search_path = ''`)가 `profiles` 행을 만든다.

## 기존 사용자 프로필 채우기 (선택)

마이그레이션 전에 가입한 사용자가 있으면 한 번 실행:

```sql
insert into public.profiles (id, display_name)
select id, left(coalesce(raw_user_meta_data ->> 'full_name', raw_user_meta_data ->> 'name', ''), 80)
from auth.users
on conflict (id) do nothing;
```

## 데이터가 들어오는 경로

`src/platform/telemetry/match_recorder.gd`가 경기 종료 시 `matches` 1행 → `match_players` 슬롯별 행 → `match_events`(500행 청크) → `match_inputs` 슬롯별 1행 순서로 보낸다. 로그인하지 않았으면 보내지 않는다.

## 리플레이 검증 (0002)

`match_inputs.frames`는 슬롯의 틱별 입력을 런렝스로 묶은 바이너리를 gzip → base64 한 것이다 (`encoding = 'bgil1+gzip+base64'`).
`matches`의 `seed`·`arena`·`player_count`·`config_fingerprint`·`sim_version`과 함께 쓰면 경기를 헤드리스 Godot에서 그대로 다시 돌릴 수 있고, 끝 상태 해시를 `final_state_hash`와 비교해 검증한다.

1. SQL Editor에서 경기 하나를 JSON으로 뽑는다:
   ```sql
   select json_build_object(
     'format', 'tbg-replay', 'version', 1,
     'match',  to_jsonb(m),
     'inputs', (select json_agg(i order by i.slot) from match_inputs i where i.match_id = m.id)
   ) from matches m where m.id = '<match id>';
   ```
2. 결과를 `match.json`으로 저장하고 `godot --headless --path . -s res://scripts/replay_verify.gd -- match.json`
3. `OK` = 재현됨, `MISMATCH` = 해시 불일치(분석 제외), `ERROR <이유>` = 설정·sim 버전이 현재 빌드와 다름 등
