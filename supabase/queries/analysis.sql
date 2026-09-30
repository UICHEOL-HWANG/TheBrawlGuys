-- TheBrawlGuys analysis queries
-- Run in Supabase Dashboard > SQL Editor (admin view, sees every user's rows).
-- Tables come from supabase/migrations/0001_match_telemetry.sql.
-- Column names follow the approved plan and may shift slightly with the final migration.


-- 1. 캐릭터별 승률 (사람 플레이어만)
select character,
       count(*)                                   as games,
       round(avg((result = 'win')::int) * 100, 1) as win_rate_pct
from match_players
where not is_bot
group by character
order by win_rate_pct desc;


-- 2. 경기장별 링아웃 원인 (넉백 / 기믹 / 자멸)
select m.arena,
       e.payload->>'cause' as cause,
       count(*)            as ringouts
from match_events e
join matches m on m.id = e.match_id
where e.type = 'ringout'
group by 1, 2
order by 1, 3 desc;


-- 3. 링아웃 위치 (경기장 히트맵 원자료, x/z 좌표)
select m.arena,
       (e.payload->'pos'->>0)::float as x,
       (e.payload->'pos'->>2)::float as z
from match_events e
join matches m on m.id = e.match_id
where e.type = 'ringout';


-- 4. 경기 길이 분포 (초 단위, 60틱 = 1초)
select m.arena,
       count(*)                                        as games,
       round(avg(m.duration_ticks) / 60.0, 1)          as avg_sec,
       round(percentile_cont(0.5) within group
             (order by m.duration_ticks)::numeric / 60, 1) as median_sec
from matches m
group by m.arena
order by avg_sec desc;


-- 5. 스타일 매치업 승률 (내 스타일 vs 상대 스타일, 1:1 경기)
select a.style                                     as my_style,
       b.style                                     as opp_style,
       count(*)                                    as games,
       round(avg((a.result = 'win')::int) * 100, 1) as win_rate_pct
from match_players a
join match_players b on b.match_id = a.match_id and b.slot <> a.slot
join matches m on m.id = a.match_id and m.player_count = 2
group by 1, 2
order by 1, 2;


-- 6. 가장 많이 맞히는 공격 / 평균 넉백 (원시 hit 이벤트)
select e.payload->>'attack_kind' as attack_kind,
       count(*)                  as hits,
       round(avg((e.payload->>'knockback')::float)::numeric, 2) as avg_knockback
from match_events e
where e.type = 'hit'
group by 1
order by hits desc;


-- 7. 아이템이 승패에 주는 영향 (아이템 사용 횟수 구간별 승률)
select case when items_used = 0 then '0'
            when items_used <= 2 then '1-2'
            else '3+' end                            as items_bucket,
       count(*)                                     as players,
       round(avg((result = 'win')::int) * 100, 1)   as win_rate_pct
from match_players
where not is_bot
group by 1
order by 1;


-- 8. 일별 경기 수 / 플레이한 유저 수
select date_trunc('day', started_at)::date as day,
       count(*)                            as matches,
       count(distinct user_id)             as players
from matches
group by 1
order by 1 desc;
