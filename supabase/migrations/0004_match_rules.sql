-- TheBrawlGuys match rules, defense counters and skill signals (combat-depth C/D, docs/tracking-plan.md §3.4,
-- event schemas 7 and 8). Run after 0003_special_hits.sql.
-- Schema 7 sends matches.rule / match_players.team / score only for team and timed matches.
-- Schema 8 sends the defense / skill columns below on EVERY match_players row, so until this runs
-- every match upload from a schema 8 build is rejected by PostgREST (matches row only, no
-- players / events / inputs).
-- Safe to re-run (IF NOT EXISTS; the checks are added only when missing).
-- matches.mode stays the controller mode (bot | local_2p | online); the match rule is separate.

alter table public.matches
  add column if not exists rule text not null default 'stock';  -- stock | team | timed

alter table public.match_players
  add column if not exists team smallint,   -- team mode: 0 (P1 + P3) or 1 (P2 + P4); null otherwise
  add column if not exists score integer;   -- timed mode: credited ring-outs minus self-destructs; null otherwise

-- Defense and recovery (event schema 8, DefenseTelemetry). Counts per slot per match.
alter table public.match_players
  add column if not exists hits_taken integer not null default 0,           -- clean hits taken (launches)
  add column if not exists di_inputs integer not null default 0,            -- launches with a non-neutral stick on the DI tick
  add column if not exists dodges_roll integer not null default 0,
  add column if not exists dodges_air integer not null default 0,
  add column if not exists perfect_guards integer not null default 0,
  add column if not exists guard_breaks integer not null default 0,         -- own guard broken
  add column if not exists guard_breaks_caused integer not null default 0,  -- last blocked hitter within 60 ticks
  add column if not exists knockdowns integer not null default 0,           -- tumble landings without a tech
  add column if not exists techs integer not null default 0,                -- tech in place or roll
  add column if not exists getups_stand integer not null default 0,
  add column if not exists getups_roll integer not null default 0,
  add column if not exists getups_attack integer not null default 0;

-- Skill and context signals (event schema 8, SkillFeatures; definitions in tracking-plan §3.4.1).
alter table public.match_players
  add column if not exists threats_faced integer not null default 0,           -- opponent swings started within 3 m
  add column if not exists reactions integer not null default 0,               -- guard / dodge presses 1..30 ticks after a threat
  add column if not exists reaction_ticks_avg real,                            -- null without reactions
  add column if not exists roll_evades integer not null default 0,             -- dodged through a nearby swing that missed
  add column if not exists tech_attempts integer not null default 0,           -- tumbles with a guard press (success = techs)
  add column if not exists di_perp_avg real,                                   -- 0..1 stick share across the launch; null without launches
  add column if not exists tumbles integer not null default 0,
  add column if not exists tumbles_survived integer not null default 0,        -- tumble ended in the same life
  add column if not exists edge_guard_presses integer not null default 0,      -- past 80 % of the arena radius
  add column if not exists edge_attack_presses integer not null default 0,
  add column if not exists edge_dodges integer not null default 0,
  add column if not exists high_dmg_guard_presses integer not null default 0,  -- at 100 % damage or more
  add column if not exists high_dmg_attack_presses integer not null default 0,
  add column if not exists high_dmg_dodges integer not null default 0,
  add column if not exists high_dmg_ticks integer not null default 0,
  add column if not exists team_assists integer not null default 0;           -- team mode: teammate rang out my victim within 3 s

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'matches_rule_check') then
    alter table public.matches
      add constraint matches_rule_check check (rule in ('stock', 'team', 'timed'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'match_players_team_check') then
    alter table public.match_players
      add constraint match_players_team_check check (team is null or team between 0 and 1);
  end if;
end $$;

create index if not exists matches_rule_started_idx on public.matches (rule, started_at desc);
