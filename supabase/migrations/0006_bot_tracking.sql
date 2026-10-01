-- TheBrawlGuys bot tracking for difficulty ML (PRD-BOT-04~06, docs/tracking-plan.md §3.4.2 / §4.2,
-- event schema 11). Run after 0004_match_rules.sql (0005 is the online rooms migration; the two
-- are independent, either order works).
-- Schema 9 sends the columns below on EVERY matches / match_players row (null when not
-- applicable), so until this runs every match upload from a schema 11 build is rejected by
-- PostgREST (no matches row; players / events / inputs never follow).
-- Safe to re-run (IF NOT EXISTS; checks added only when missing).
-- match_events needs no change: probe_stage / dda_adjusted / bot_intent rows use its six columns.

alter table public.matches
  add column if not exists dda_variant text;  -- A/B arm of the human's device: on | off; null = no human

-- Per bot slot: the difficulty dial d (0..1) at the start, mean over the match, at the end, and
-- how many times DDA moved it. Null on human rows.
alter table public.match_players
  add column if not exists bot_d_start real,
  add column if not exists bot_d_mean real,
  add column if not exists bot_d_end real,
  add column if not exists dda_adjustments integer;

-- The opening probe: on the probing bot's row, the human slot it probed, the probe features
-- (ProbeObserver.FEATURES: react_ticks, response_rate, dodge_rate, tech_rate, punish_rate,
-- damage_share, attack_rate, edge_share) and the skill estimate (0..1) made from them.
-- skill_rating: on the human's row, the device rating before this match (null = unrated).
alter table public.match_players
  add column if not exists probe_target_slot smallint,
  add column if not exists probe_features jsonb,
  add column if not exists probe_estimate real,
  add column if not exists skill_rating real;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'matches_dda_variant_check') then
    alter table public.matches
      add constraint matches_dda_variant_check check (dda_variant is null or dda_variant in ('on', 'off'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'match_players_bot_d_range') then
    alter table public.match_players
      add constraint match_players_bot_d_range check (
        (bot_d_start is null or bot_d_start between 0 and 1)
        and (bot_d_end is null or bot_d_end between 0 and 1)
        and (probe_estimate is null or probe_estimate between 0 and 1)
        and (skill_rating is null or skill_rating between 0 and 1));
  end if;
end $$;

create index if not exists matches_dda_variant_idx on public.matches (dda_variant, started_at desc)
  where dda_variant is not null;
