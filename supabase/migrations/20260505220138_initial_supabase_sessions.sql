-- All Hands On Deck Supabase baseline.
-- Applies the group-photo session model, RLS policies, Realtime publication,
-- and the private photos storage bucket.

create extension if not exists pgcrypto;

create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  host_user_id uuid null references auth.users(id) on delete set null,
  status text not null default 'active' check (status in ('active', 'ended', 'expired')),
  created_at timestamptz not null default now(),
  expires_at timestamptz null,
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.participants (
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

create table if not exists public.photos (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  uploaded_by uuid null references public.participants(id) on delete set null,
  anonymous_id text null,
  storage_path text not null,
  file_name text null,
  mime_type text null,
  width int null,
  height int null,
  size_bytes bigint null,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.session_events (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  sender_participant_id uuid null references public.participants(id) on delete set null,
  type text not null,
  payload jsonb not null default '{}'::jsonb,
  client_generated_id text null,
  created_at timestamptz not null default now()
);

create index if not exists sessions_code_idx on public.sessions (code);
create index if not exists sessions_active_code_idx on public.sessions (code) where status = 'active';
create index if not exists participants_session_idx on public.participants (session_id);
create index if not exists participants_user_idx on public.participants (user_id);
create index if not exists photos_session_created_idx on public.photos (session_id, created_at desc);
create index if not exists session_events_session_created_idx on public.session_events (session_id, created_at);
create unique index if not exists session_events_client_generated_id_idx
  on public.session_events (session_id, client_generated_id)
  where client_generated_id is not null;

alter table public.sessions enable row level security;
alter table public.participants enable row level security;
alter table public.photos enable row level security;
alter table public.session_events enable row level security;

create or replace function public.current_anonymous_id()
returns text
language sql
stable
as $$
  select nullif(
    coalesce(
      auth.jwt() -> 'app_metadata' ->> 'anonymous_id',
      auth.jwt() ->> 'anonymous_id',
      ''
    ),
    ''
  )
$$;

create or replace function public.is_active_session(target_session_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.sessions s
    where s.id = target_session_id
      and s.status = 'active'
      and (s.expires_at is null or s.expires_at > now())
  )
$$;

create or replace function public.is_session_participant(target_session_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.participants p
    where p.session_id = target_session_id
      and (
        p.user_id = auth.uid()
        or (public.current_anonymous_id() is not null and p.anonymous_id = public.current_anonymous_id())
      )
  )
$$;

-- Sessions can be found by code while active. Clients should still query by
-- exact code instead of listing all rows.
create policy "read active sessions by code"
on public.sessions
for select
to anon, authenticated
using (status = 'active' and (expires_at is null or expires_at > now()));

create policy "create active sessions"
on public.sessions
for insert
to anon, authenticated
with check (status = 'active');

create policy "hosts update their sessions"
on public.sessions
for update
to authenticated
using (host_user_id = auth.uid())
with check (host_user_id = auth.uid());

create policy "participants read their active session crew"
on public.participants
for select
to anon, authenticated
using (public.is_active_session(session_id));

create policy "join active sessions"
on public.participants
for insert
to anon, authenticated
with check (public.is_active_session(session_id));

create policy "participants update themselves"
on public.participants
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

create policy "session participants read photos"
on public.photos
for select
to anon, authenticated
using (public.is_active_session(session_id));

create policy "upload photos to active sessions"
on public.photos
for insert
to anon, authenticated
with check (public.is_active_session(session_id));

create policy "session participants read events"
on public.session_events
for select
to anon, authenticated
using (public.is_active_session(session_id));

create policy "write events to active sessions"
on public.session_events
for insert
to anon, authenticated
with check (public.is_active_session(session_id));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', false, 20971520, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "read photos objects for active sessions"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = 'sessions'
  and public.is_active_session(((storage.foldername(name))[2])::uuid)
);

create policy "upload photo objects to active sessions"
on storage.objects
for insert
to anon, authenticated
with check (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = 'sessions'
  and public.is_active_session(((storage.foldername(name))[2])::uuid)
);

drop publication if exists supabase_realtime;
create publication supabase_realtime;
alter publication supabase_realtime add table public.session_events;
alter publication supabase_realtime add table public.participants;
alter publication supabase_realtime add table public.photos;
