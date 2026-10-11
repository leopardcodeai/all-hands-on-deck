-- DB hygiene pass (Supabase advisor findings, 2026-06-11) plus retention for
-- session_events. Preview frames move to Realtime Broadcast in the same
-- release, so the events table only carries low-volume control messages and
-- short-lived legacy frames from old clients.

-- 1. Duplicate indexes on session_participants: two identical pairs existed
--    (participants_* and session_participants_*). Keep the session_participants_*
--    ones, drop the older duplicates.
drop index if exists public.participants_session_idx;
drop index if exists public.participants_user_idx;

-- 2. Unindexed foreign keys flagged by the advisor. Matters mainly for the
--    cascade deletes the retention job below performs.
create index if not exists session_events_sender_participant_idx
  on public.session_events (sender_participant_id);
create index if not exists photos_uploaded_by_idx
  on public.photos (uploaded_by);
create index if not exists sessions_host_user_idx
  on public.sessions (host_user_id);

-- 3. RLS initplan fix: auth.uid() / current_anonymous_id() were re-evaluated
--    per row. Wrapping them in scalar subselects lets the planner evaluate
--    them once per statement.
alter policy "hosts update their sessions" on public.sessions
  using (host_user_id = (select auth.uid()))
  with check (host_user_id = (select auth.uid()));

alter policy "participants update themselves" on public.session_participants
  using (
    (user_id = (select auth.uid()))
    or (((select current_anonymous_id()) is not null)
        and (anonymous_id = (select current_anonymous_id())))
  )
  with check (
    (user_id = (select auth.uid()))
    or (((select current_anonymous_id()) is not null)
        and (anonymous_id = (select current_anonymous_id())))
  );

-- 4. Pin search_path on SECURITY-relevant helper functions (advisor lint 0011).
alter function public.current_anonymous_id() set search_path = public, pg_temp;
alter function public.is_active_session(uuid) set search_path = public, pg_temp;
alter function public.is_session_participant(uuid) set search_path = public, pg_temp;

-- 5. rls_auto_enable() is SECURITY DEFINER and was callable by anon/authenticated
--    via PostgREST RPC. It is an operator-only helper.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

-- 6. logs accepts unrestricted anonymous inserts; cap the payload size so the
--    table cannot be used as a free blob store.
alter table public.logs
  add constraint logs_payload_size_check
  check (
    pg_column_size(data) <= 8192
    and length(coalesce(message, '')) <= 2000
  ) not valid;
alter table public.logs validate constraint logs_payload_size_check;

-- 7. Retention: sessions are ephemeral (minutes), so events have no value after
--    a day. previewFrame rows (legacy clients only, post-broadcast) are bulky
--    and die after an hour. logs keep a week.
create extension if not exists pg_cron;

select cron.schedule(
  'cleanup-session-events',
  '*/30 * * * *',
  $$
    delete from public.session_events
      where created_at < now() - interval '24 hours'
         or (type = 'previewFrame' and created_at < now() - interval '1 hour');
    delete from public.logs
      where created_at < now() - interval '7 days';
  $$
);
