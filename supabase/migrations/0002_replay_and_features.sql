-- TheBrawlGuys replay log + reproducibility header + behaviour features (platform A7/A8,
-- PRD-DATA-04, docs/analytics-strategy.md). Run after 0001_match_telemetry.sql.
-- Safe to re-run: add column / create table / index use IF NOT EXISTS, policies are dropped first,
-- check constraints are added only when missing.

-- ---------------------------------------------------------------------------------------------
-- matches: reproducibility header (analytics-strategy §1, §3.1)
-- ---------------------------------------------------------------------------------------------
alter table public.matches
  add column if not exists config_fingerprint   bigint,     -- GameConfig.fingerprint() (sim groups)
  add column if not exists sim_version          smallint,   -- World.SNAPSHOT_VERSION
  add column if not exists event_schema_version smallint,   -- EventCatalog.SCHEMA_VERSION
  add column if not exists final_state_hash     bigint,     -- World.state_hash() when tracking ended
  add column if not exists session_id           bigint,     -- Amplitude session id (epoch ms)
  add column if not exists user_match_seq       integer,    -- n-th match of this user on this install
  add column if not exists config_variant       text not null default 'control';

-- ---------------------------------------------------------------------------------------------
-- match_players: controller and bot tuning (analytics-strategy §3.1)
-- ---------------------------------------------------------------------------------------------
alter table public.match_players
  add column if not exists controller      text,
  add column if not exists bot_difficulty  text,          -- null for humans
  add column if not exists bot_params_hash bigint;        -- hash of the Bot config group; null for humans

-- ---------------------------------------------------------------------------------------------
-- match_players: behaviour features (A8, analytics-strategy §3.2; MatchFeatures.COLUMNS).
-- Ratios are 0..1 over the slot's living ticks (inputs: all ticks); rates are per minute of match.
-- ---------------------------------------------------------------------------------------------
alter table public.match_players
  add column if not exists press_light               integer,
  add column if not exists press_heavy               integer,
  add column if not exists press_guard               integer,
  add column if not exists press_grab                integer,
  add column if not exists press_jump                integer,
  add column if not exists press_special             integer,  -- 0 until Phase 5 adds the button
  add column if not exists inputs_per_min            real,     -- button presses per minute
  add column if not exists direction_changes         integer,  -- 8-way stick direction changes
  add column if not exists mash_ratio                real,     -- presses repeating a button within 10 ticks
  add column if not exists guard_hold_ratio          real,
  add column if not exists idle_gaps                 integer,  -- runs of >= 5 s neutral input
  add column if not exists hit_accuracy              real,     -- hits / (hits + whiffs); null without swings
  add column if not exists max_combo                 integer,  -- hits while the target stayed in hitstun
  add column if not exists damage_per_min            real,
  add column if not exists distance_travelled        real,     -- metres, within each life
  add column if not exists avg_nearest_opponent_dist real,     -- metres; null when never had a living opponent
  add column if not exists edge_time_ratio           real,     -- beyond 80 % of the arena radius
  add column if not exists air_time_ratio            real,
  add column if not exists item_hold_ticks           jsonb,    -- {"bat": ticks, "rock": ..., "bomb": ...}
  add column if not exists first_item_tick           integer,  -- null: never picked anything up
  add column if not exists contested_pickups         integer,  -- pickups with a living opponent within 2 m
  add column if not exists first_blood               boolean,  -- credited with the match's first ringout
  add column if not exists comeback_win              boolean;  -- won after trailing by at least one stock

-- ---------------------------------------------------------------------------------------------
-- match_inputs: replay-grade input log, one row per slot (analytics-strategy §1 L0)
-- frames = base64(gzip(binary run-length track)), encoding names that pipeline.
-- ---------------------------------------------------------------------------------------------
create table if not exists public.match_inputs (
  match_id    uuid not null references public.matches (id) on delete cascade,
  slot        smallint not null check (slot between 0 and 7),
  encoding    text not null check (char_length(encoding) <= 32),
  frames      text not null check (octet_length(frames) <= 1048576),
  frame_count integer not null check (frame_count between 0 and 16777216),
  created_at  timestamptz not null default now(),
  primary key (match_id, slot)
);

-- ---------------------------------------------------------------------------------------------
-- Check constraints on the new columns (added once per table; ADD CONSTRAINT has no IF NOT EXISTS)
-- ---------------------------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'matches_config_variant_len'
                 and conrelid = 'public.matches'::regclass) then
    alter table public.matches add constraint matches_config_variant_len
      check (char_length(config_variant) <= 32);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'matches_user_match_seq_pos'
                 and conrelid = 'public.matches'::regclass) then
    alter table public.matches add constraint matches_user_match_seq_pos
      check (user_match_seq is null or user_match_seq >= 1);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'match_players_controller_kind'
                 and conrelid = 'public.match_players'::regclass) then
    alter table public.match_players add constraint match_players_controller_kind
      check (controller is null or controller in ('local', 'bot', 'remote'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'match_players_bot_difficulty_len'
                 and conrelid = 'public.match_players'::regclass) then
    alter table public.match_players add constraint match_players_bot_difficulty_len
      check (char_length(bot_difficulty) <= 16);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'match_players_item_hold_ticks_size'
                 and conrelid = 'public.match_players'::regclass) then
    alter table public.match_players add constraint match_players_item_hold_ticks_size
      check (item_hold_ticks is null
             or (jsonb_typeof(item_hold_ticks) = 'object' and pg_column_size(item_hold_ticks) <= 512));
  end if;
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------------------------
create index if not exists matches_user_session_idx on public.matches (user_id, session_id);

-- ---------------------------------------------------------------------------------------------
-- Row-level security: same pattern as 0001 (own rows via matches.user_id, authenticated only)
-- ---------------------------------------------------------------------------------------------
alter table public.match_inputs enable row level security;

drop policy if exists match_inputs_insert_own on public.match_inputs;
create policy match_inputs_insert_own on public.match_inputs
  for insert to authenticated with check (exists (
    select 1 from public.matches m
    where m.id = match_inputs.match_id and m.user_id = (select auth.uid())));
drop policy if exists match_inputs_select_own on public.match_inputs;
create policy match_inputs_select_own on public.match_inputs
  for select to authenticated using (exists (
    select 1 from public.matches m
    where m.id = match_inputs.match_id and m.user_id = (select auth.uid())));

revoke all on public.match_inputs from anon;
revoke update, delete, truncate on public.match_inputs from authenticated;

-- PostgREST caches the schema: reload it so the new table and columns accept inserts right away.
notify pgrst, 'reload schema';
