-- TheBrawlGuys match rules (combat-depth D, docs/tracking-plan.md §3.4, event schema 7).
-- Run after 0003_special_hits.sql. A build with event schema 7 sends these columns ONLY for team
-- and timed matches (stock rows keep the 0003 shape), so until this runs, stock matches still
-- upload but team / timed match uploads are rejected by PostgREST.
-- Safe to re-run (IF NOT EXISTS; the checks are added only when missing).
-- matches.mode stays the controller mode (bot | local_2p | online); the match rule is separate.

alter table public.matches
  add column if not exists rule text not null default 'stock';  -- stock | team | timed

alter table public.match_players
  add column if not exists team smallint,   -- team mode: 0 (P1 + P3) or 1 (P2 + P4); null otherwise
  add column if not exists score integer;   -- timed mode: credited ring-outs minus self-destructs; null otherwise

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
