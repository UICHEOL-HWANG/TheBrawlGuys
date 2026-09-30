# Supabase — TheBrawlGuys

경기 기록(`matches` · `match_players` · `match_events`)과 `profiles` 스키마. 근거: PRD-DATA-04, `dev/active/platform/platform-plan.md` §A.5.

## 적용 방법 (SQL Editor)

Supabase CLI를 쓰지 않으므로 대시보드에서 직접 실행한다.

1. Supabase 대시보드 → 프로젝트 → **SQL Editor** → **New query**
2. `migrations/0001_match_telemetry.sql` 내용을 전부 붙여넣고 **Run**
3. **Table Editor**에서 네 테이블이 보이고, 각 테이블에 `RLS enabled` 표시가 있는지 확인
4. **Authentication → Policies**에서 테이블마다 정책이 보이는지 확인

스크립트는 다시 실행해도 안전하다(`if not exists`, 정책은 지운 뒤 재생성).

CLI를 쓸 경우: `npx supabase link --project-ref <ref>` 후 `npx supabase db push`.

## 보안 모델

- 게임 클라이언트는 **anon(publishable) 키 + 로그인한 사용자의 JWT**로만 쓴다. 서비스 키는 게임·저장소 어디에도 두지 않는다 (`scripts/check-secrets.sh`가 막는다).
- 모든 테이블에 RLS가 켜져 있고 정책은 `authenticated` 역할에만 있다. 로그인하지 않은 요청은 읽기·쓰기 모두 거부된다.
- `matches`는 `user_id = auth.uid()`인 행만 insert/select. `match_players`·`match_events`는 자기 `matches` 행에 딸린 것만 가능.
- 자식 테이블 insert 정책은 `matches`를 조회하므로 `matches_select_own` 정책을 지우면 안 된다.
- 삭제 정책이 없다. 사용자 데이터는 계정 삭제 시 cascade로만 지워진다.
- 텍스트 길이·`payload` 크기(4 KB)·슬롯 범위에 check 제약이 있다. 계정당 insert 양 제한(쿼터)은 아직 없다.
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

`src/platform/telemetry/match_recorder.gd`가 경기 종료 시 `matches` 1행 → `match_players` 슬롯별 행 → `match_events`(500행 청크) 순서로 보낸다. 로그인하지 않았으면 보내지 않는다.
