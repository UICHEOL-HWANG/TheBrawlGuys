-- TheBrawlGuys Phase 5 special moves (T10, docs/tracking-plan.md §3.4.1, event schema 4).
-- Run after 0002_replay_and_features.sql. Safe to re-run (IF NOT EXISTS).
-- match_players.specials (0001) already holds activations; this adds the per-target hit count.

alter table public.match_players
  add column if not exists special_hits integer not null default 0;  -- special_hit events (targets hit)
