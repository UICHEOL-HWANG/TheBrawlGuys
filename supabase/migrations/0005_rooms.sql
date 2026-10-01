-- TheBrawlGuys online rooms (Phase 6, PRD-NET-03 / PRD-DATA-02, docs/superpowers/specs/
-- 2026-10-01-online-p2p-design.md). A room code maps to its host; players then meet on the
-- Supabase Realtime broadcast channel realtime:room:<code> for WebRTC signaling (no game server).
-- Safe to re-run: type / table / index use IF NOT EXISTS, policies are dropped first.

do $$ begin
  create type public.room_status as enum ('waiting', 'playing', 'closed');
exception when duplicate_object then null;
end $$;

create table if not exists public.rooms (
  -- 6 characters, A-Z and 2-9 without I / O / 0 / 1 (src/net/rooms/room_code.gd)
  code         text primary key check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
  host_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  status       public.room_status not null default 'waiting',
  player_count integer not null default 1 check (player_count between 0 and 4),
  rule         text not null default 'stock' check (char_length(rule) <= 32),
  arena        text not null default '' check (char_length(arena) <= 32),
  created_at   timestamptz not null default now(),
  expires_at   timestamptz not null default now() + interval '2 hours'
);

create index if not exists rooms_expires_at_idx on public.rooms (expires_at);
create index if not exists rooms_host_id_idx on public.rooms (host_id);

-- ---------------------------------------------------------------------------------------------
-- Row-level security: the table itself shows a host only its own rooms (nobody can list open
-- rooms); other players find one open room by its code through get_room() below. Only the host
-- inserts, updates or deletes its own rooms. anon has no policy.
-- ---------------------------------------------------------------------------------------------
alter table public.rooms enable row level security;

drop policy if exists rooms_select_open on public.rooms;
drop policy if exists rooms_select_own on public.rooms;
create policy rooms_select_own on public.rooms
  for select to authenticated using (host_id = (select auth.uid()));
drop policy if exists rooms_insert_own on public.rooms;
create policy rooms_insert_own on public.rooms
  for insert to authenticated with check (host_id = (select auth.uid()));
drop policy if exists rooms_update_own on public.rooms;
create policy rooms_update_own on public.rooms
  for update to authenticated
  using (host_id = (select auth.uid())) with check (host_id = (select auth.uid()));
drop policy if exists rooms_delete_own on public.rooms;
create policy rooms_delete_own on public.rooms
  for delete to authenticated using (host_id = (select auth.uid()));

-- ---------------------------------------------------------------------------------------------
-- Lookup by code (RoomsApi.lookup → POST /rest/v1/rpc/get_room {"p_code": ...}): one open,
-- unexpired room or nothing. Exact match only, so a code still has to be known.
-- ---------------------------------------------------------------------------------------------
create or replace function public.get_room(p_code text)
returns setof public.rooms
language sql
stable
security definer
set search_path = ''
as $$
  select * from public.rooms
  where code = upper(p_code) and status <> 'closed' and expires_at > now()
  limit 1;
$$;

revoke all on function public.get_room(text) from public, anon;
grant execute on function public.get_room(text) to authenticated;

-- ---------------------------------------------------------------------------------------------
-- Guards: the server owns code, host, created_at and expires_at (a host cannot keep a room
-- alive by moving expires_at), and one host has at most MAX_OPEN (3) open rooms at a time.
-- ---------------------------------------------------------------------------------------------
create or replace function public.rooms_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
    new.expires_at := now() + interval '2 hours';
    if (select count(*) from public.rooms r
        where r.host_id = new.host_id and r.status <> 'closed' and r.expires_at > now()) >= 3 then
      raise exception 'too many open rooms' using errcode = 'P0001';
    end if;
  else
    new.code := old.code;
    new.host_id := old.host_id;
    new.created_at := old.created_at;
    new.expires_at := old.expires_at;
  end if;
  return new;
end;
$$;

drop trigger if exists rooms_guard on public.rooms;
create trigger rooms_guard before insert or update on public.rooms
  for each row execute function public.rooms_guard();

-- ---------------------------------------------------------------------------------------------
-- Cleanup: deletes expired and closed rooms. Run by hand, or schedule with pg_cron:
--   select cron.schedule('rooms-cleanup', '*/30 * * * *', 'select public.cleanup_rooms()');
-- ---------------------------------------------------------------------------------------------
create or replace function public.cleanup_rooms()
returns integer
language sql
security definer
set search_path = ''
as $$
  with gone as (
    delete from public.rooms
    where expires_at < now() or status = 'closed'
    returning 1
  )
  select count(*)::integer from gone;
$$;

revoke all on function public.cleanup_rooms() from public, anon, authenticated;
