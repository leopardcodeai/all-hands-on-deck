-- APP-85: MVP WebRTC/P2P controls.
-- Supabase remains the session backend; video stays on WebRTC P2P and is not
-- stored in Supabase.

alter table public.sessions
  add column if not exists join_token_expires_at timestamptz null,
  add column if not exists max_viewers int not null default 3,
  add column if not exists max_duration_minutes int not null default 10,
  add column if not exists turn_minutes_used numeric not null default 0,
  add column if not exists realtime_messages_per_minute int not null default 120,
  add column if not exists web_viewers_feature_stage text not null default 'beta';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'sessions_max_viewers_positive') then
    alter table public.sessions add constraint sessions_max_viewers_positive check (max_viewers > 0) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'sessions_max_duration_limit') then
    alter table public.sessions add constraint sessions_max_duration_limit check (max_duration_minutes between 1 and 10) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'sessions_turn_minutes_nonnegative') then
    alter table public.sessions add constraint sessions_turn_minutes_nonnegative check (turn_minutes_used >= 0) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'sessions_realtime_rate_limit_positive') then
    alter table public.sessions add constraint sessions_realtime_rate_limit_positive check (realtime_messages_per_minute > 0) not valid;
  end if;
end $$;

do $$
begin
  if to_regclass('public.session_participants') is null
     and to_regclass('public.participants') is not null then
    alter table public.participants rename to session_participants;
  end if;
end $$;

create table if not exists public.session_participants (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  user_id uuid null references auth.users(id) on delete set null,
  anonymous_id text null,
  display_name text null,
  role text not null default 'guest' check (role in ('host', 'guest', 'viewer')),
  peer_id text null,
  livekit_identity text null,
  joined_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index if not exists session_participants_session_idx on public.session_participants (session_id);
create index if not exists session_participants_user_idx on public.session_participants (user_id);
alter table public.session_participants enable row level security;

create or replace view public.participants
with (security_invoker = true)
as
select * from public.session_participants;

create or replace function public.is_session_participant(target_session_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.session_participants p
    where p.session_id = target_session_id
      and (
        p.user_id = auth.uid()
        or (public.current_anonymous_id() is not null and p.anonymous_id = public.current_anonymous_id())
      )
  )
$$;

drop policy if exists "participants read their active session crew" on public.session_participants;
create policy "participants read their active session crew"
on public.session_participants
for select
to anon, authenticated
using (public.is_active_session(session_id));

drop policy if exists "join active sessions" on public.session_participants;
create policy "join active sessions"
on public.session_participants
for insert
to anon, authenticated
with check (
  public.is_active_session(session_id)
  and (
    role <> 'viewer'
    or (
      select count(*)
      from public.session_participants existing
      where existing.session_id = public.session_participants.session_id
        and existing.role = 'viewer'
    ) < (
      select s.max_viewers
      from public.sessions s
      where s.id = session_id
    )
  )
);

drop policy if exists "participants update themselves" on public.session_participants;
create policy "participants update themselves"
on public.session_participants
for update
to authenticated
using (
  user_id = auth.uid()
  or (public.current_anonymous_id() is not null and anonymous_id = public.current_anonymous_id())
)
with check (
  user_id = auth.uid()
  or (public.current_anonymous_id() is not null and anonymous_id = public.current_anonymous_id())
);

do $$
begin
  alter publication supabase_realtime add table public.session_participants;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
