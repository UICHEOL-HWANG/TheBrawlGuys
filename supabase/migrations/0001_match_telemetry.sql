-- TheBrawlGuys match telemetry + profiles (platform A5, PRD-DATA-04).
-- Clients write with the anon key + the user's JWT; row-level security keeps every row owned by
-- auth.uid(). Safe to re-run: tables/indexes use IF NOT EXISTS, policies are dropped first.

-- ---------------------------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------------------------
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text check (char_length(display_name) <= 80),
  created_at   timestamptz not null default now()
);

create table if not exists public.matches (
  id             uuid primary key,
  user_id        uuid not null default auth.uid() references auth.users (id) on delete cascade,
  mode           text not null check (char_length(mode) <= 32),
  arena          text not null check (char_length(arena) <= 32),
  player_count   smallint not null check (player_count between 1 and 8),
  seed           bigint not null,
  started_at     timestamptz not null,
  duration_ticks integer not null check (duration_ticks >= 0),
  winner_slot    smallint,                    -- null: draw or abandoned
  result         text not null check (result in ('win', 'loss', 'draw', 'abandoned')),
  build_version  text not null default '' check (char_length(build_version) <= 32),
  platform       text not null default '' check (char_length(platform) <= 32),
  created_at     timestamptz not null default now()
);

create table if not exists public.match_players (
  match_id         uuid not null references public.matches (id) on delete cascade,
  slot             smallint not null check (slot between 0 and 7),
  is_bot           boolean not null,
  character        text not null check (char_length(character) <= 32),
  style            text not null default '' check (char_length(style) <= 32),
  input_device     text not null default '' check (char_length(input_device) <= 32),
  result           text not null check (result in ('win', 'loss', 'draw', 'abandoned')),
  stocks_left      smallint not null default 0,
  damage_dealt     real not null default 0,
  damage_taken     real not null default 0,
  hits             integer not null default 0,
  guards           integer not null default 0,
  grabs            integer not null default 0,
  jumps            integer not null default 0,
  whiffs           integer not null default 0,
  ringouts_scored  integer not null default 0,
  falls            integer not null default 0,
  falls_by_gimmick integer not null default 0,
  specials         integer not null default 0,
  items_used       integer not null default 0,
  primary key (match_id, slot)
);

-- Raw sim events, render events (jumped/landed/respawned) and position samples ("pos").
create table if not exists public.match_events (
  id          bigint generated always as identity primary key,
  match_id    uuid not null references public.matches (id) on delete cascade,
  tick        integer not null check (tick >= 0),
  type        text not null check (char_length(type) <= 32),
  actor_slot  smallint check (actor_slot between 0 and 7),
  target_slot smallint check (target_slot between 0 and 7),
  payload     jsonb not null default '{}'::jsonb check (pg_column_size(payload) <= 4096)
);

-- ---------------------------------------------------------------------------------------------
-- Indexes (foreign keys and the usual filters)
-- ---------------------------------------------------------------------------------------------
create index if not exists matches_user_started_idx on public.matches (user_id, started_at desc);
create index if not exists match_events_match_tick_idx on public.match_events (match_id, tick);
create index if not exists match_events_match_type_idx on public.match_events (match_id, type);

-- ---------------------------------------------------------------------------------------------
-- Row-level security: own rows only, authenticated users only (anon has no policy)
-- ---------------------------------------------------------------------------------------------
alter table public.profiles      enable row level security;
alter table public.matches       enable row level security;
alter table public.match_players enable row level security;
alter table public.match_events  enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = (select auth.uid()));
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

drop policy if exists matches_insert_own on public.matches;
create policy matches_insert_own on public.matches
  for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists matches_select_own on public.matches;
create policy matches_select_own on public.matches
  for select to authenticated using (user_id = (select auth.uid()));

-- Child rows: the exists subquery reads matches under matches_select_own, so keep that policy.
drop policy if exists match_players_insert_own on public.match_players;
create policy match_players_insert_own on public.match_players
  for insert to authenticated with check (exists (
    select 1 from public.matches m
    where m.id = match_players.match_id and m.user_id = (select auth.uid())));
drop policy if exists match_players_select_own on public.match_players;
create policy match_players_select_own on public.match_players
  for select to authenticated using (exists (
    select 1 from public.matches m
    where m.id = match_players.match_id and m.user_id = (select auth.uid())));

drop policy if exists match_events_insert_own on public.match_events;
create policy match_events_insert_own on public.match_events
  for insert to authenticated with check (exists (
    select 1 from public.matches m
    where m.id = match_events.match_id and m.user_id = (select auth.uid())));
drop policy if exists match_events_select_own on public.match_events;
create policy match_events_select_own on public.match_events
  for select to authenticated using (exists (
    select 1 from public.matches m
    where m.id = match_events.match_id and m.user_id = (select auth.uid())));

-- Least privilege on top of RLS: anon gets nothing; signed-in users only insert/select their
-- telemetry and may only rename themselves. No deletes through the API (account deletion cascades).
revoke all on public.profiles, public.matches, public.match_players, public.match_events from anon;
revoke update, delete, truncate on public.matches, public.match_players, public.match_events from authenticated;
revoke insert, update, delete, truncate on public.profiles from authenticated;
grant update (display_name) on public.profiles to authenticated;

-- ---------------------------------------------------------------------------------------------
-- Profile row for every new auth user
-- ---------------------------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    left(coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''), 80)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
