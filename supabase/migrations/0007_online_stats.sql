-- TheBrawlGuys online match network stats (Phase 6 netcode, event schema 9, docs/tracking-plan.md).
-- Only the HOST of an online match uploads matches / match_players / match_events / match_inputs
-- (it is authoritative and its input log replays); clients send Amplitude events only, with the
-- same match_id. Offline matches never send these columns, so their uploads work before this runs;
-- online uploads are rejected by PostgREST until it does.
-- Safe to re-run (IF NOT EXISTS; the checks are added only when missing).

alter table public.matches
  add column if not exists net_host boolean,            -- the uploading peer hosted (always true today); null offline
  add column if not exists rtt_p50 real,                -- round trip ms over the match (host: to its clients); null without samples
  add column if not exists rtt_p95 real,
  add column if not exists corrections integer,         -- own-fighter prediction corrections (clients only; 0 on the host)
  add column if not exists disconnects integer,         -- player drops the uploading peer saw
  add column if not exists disconnect_reason text;      -- newest drop: timeout | left | host_left | room_full

alter table public.match_players
  add column if not exists disconnect_reason text;      -- online: why this slot's player dropped (timeout | left); null otherwise

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'matches_disconnect_reason_check') then
    alter table public.matches
      add constraint matches_disconnect_reason_check
      check (disconnect_reason is null or disconnect_reason in ('timeout', 'left', 'host_left', 'room_full'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'match_players_disconnect_reason_check') then
    alter table public.match_players
      add constraint match_players_disconnect_reason_check
      check (disconnect_reason is null or disconnect_reason in ('timeout', 'left'));
  end if;
end $$;
