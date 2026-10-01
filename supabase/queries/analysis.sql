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


-- 9. 방어 수단 사용률 (스타일·캐릭터별, 사람만, 경기 1분당) — 0004 이후 경기 (event_schema_version >= 8)
select p.style,
       p.character,
       count(*)                                                                as games,
       round(avg(p.dodges_roll + p.dodges_air) / avg(m.duration_ticks / 3600.0), 2) as dodges_per_min,
       round(avg(p.perfect_guards) / avg(m.duration_ticks / 3600.0), 2)          as perfect_guards_per_min,
       round(avg((p.dodges_roll + p.dodges_air + p.perfect_guards > 0)::int) * 100, 1) as used_any_pct,
       round(avg((p.result = 'win')::int) * 100, 1)                             as win_rate_pct
from match_players p
join matches m on m.id = p.match_id
where not p.is_bot and m.event_schema_version >= 8 and m.duration_ticks > 0
group by 1, 2
order by 1, 2;


-- 10. 낙법률 · DI 시도율 · 기상 선택 (경험이 쌓이며 배우나? user_match_seq 구간별, 사람만)
select case when m.user_match_seq <= 3 then '01-03'
            when m.user_match_seq <= 10 then '04-10'
            else '11+' end                                                       as match_seq_bucket,
       count(*)                                                                  as players,
       round(sum(p.techs)::numeric / nullif(sum(p.techs + p.knockdowns), 0) * 100, 1) as tech_rate_pct,
       round(sum(p.di_inputs)::numeric / nullif(sum(p.hits_taken), 0) * 100, 1)      as di_attempt_pct,
       round(sum(p.getups_roll)::numeric / nullif(sum(p.getups_stand + p.getups_roll + p.getups_attack), 0) * 100, 1)
                                                                                 as getup_roll_pct,
       round(sum(p.getups_attack)::numeric / nullif(sum(p.getups_stand + p.getups_roll + p.getups_attack), 0) * 100, 1)
                                                                                 as getup_attack_pct
from match_players p
join matches m on m.id = p.match_id
where not p.is_bot and m.event_schema_version >= 8
group by 1
order by 1;


-- 11. 가드 브레이크 빈도 (스타일별: 경기당 당한 수 / 깬 수. 깬 사람 없는 브레이크 = 가드를 쥐고 있다 바닥남,
--     match_events type 'guard_break' payload attacker_slot = -1)
select p.style,
       count(*)                                    as games,
       round(avg(p.guard_breaks), 2)               as broken_per_game,
       round(avg(p.guard_breaks_caused), 2)        as caused_per_game,
       round(sum(p.guard_breaks - p.guard_breaks_caused)::numeric / count(*), 2) as net_broken_per_game
from match_players p
join matches m on m.id = p.match_id
where m.event_schema_version >= 8
group by 1
order by broken_per_game desc;


-- 12. 반응 속도·방어 결과·위험 상황 선택 (스타일별, 사람만) — 실력 신호와 승률
select p.style,
       count(*)                                                                           as games,
       round(sum(p.reactions)::numeric / nullif(sum(p.threats_faced), 0) * 100, 1)        as reaction_rate_pct,
       round(avg(p.reaction_ticks_avg)::numeric / 60 * 1000)                              as reaction_ms_avg,
       round(sum(p.roll_evades)::numeric / nullif(sum(p.dodges_roll + p.dodges_air), 0) * 100, 1) as dodge_evade_pct,
       round(sum(p.techs)::numeric / nullif(sum(p.tech_attempts), 0) * 100, 1)             as tech_success_pct,
       round(sum(p.tumbles_survived)::numeric / nullif(sum(p.tumbles), 0) * 100, 1)        as tumble_survival_pct,
       round(avg(p.di_perp_avg)::numeric, 3)                                              as di_perp_avg,
       round(sum(p.high_dmg_attack_presses)::numeric
             / nullif(sum(p.high_dmg_attack_presses + p.high_dmg_guard_presses), 0) * 100, 1) as high_dmg_attack_share_pct,
       round(avg((p.result = 'win')::int) * 100, 1)                                       as win_rate_pct
from match_players p
join matches m on m.id = p.match_id
where not p.is_bot and m.event_schema_version >= 8
group by 1
order by 1;
