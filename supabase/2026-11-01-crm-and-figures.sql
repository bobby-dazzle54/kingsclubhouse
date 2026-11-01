-- King's Clubhouse · 1 Nov 2026 · CRM (first refusal, pipeline, timeline, email) + club figures
-- Paste into Supabase → SQL Editor → New query → Run. Safe to re-run.
--
-- ▶ OWNER: put your login email between the quotes so you are the owner whatever order the logins were created in.
--   Leave it blank and the earliest login becomes the owner.
--
-- What this adds
--   staff            who can log in, owner / team, active
--   enquiries        + triage (first refusal), assigned_to, value £, labels, needs_reply, outcome, email thread
--   enquiry_activity timeline: form, notes, emails in/out, stage and value changes
--   notifications    "sent to team" / "picked up" / "new email" alerts inside the app
--   crm_labels, crm_templates, crm_settings (email webhook + secret)
--   email_outbox     replies written in the app; n8n sends them from info@ (optional)
--   club_metrics     one row per month: bar sales £, paying members, Facebook, Instagram, WhatsApp members
--   RPCs             crm_triage, crm_pick_up, crm_assign, crm_set_stage, crm_add_note, crm_set_labels,
--                    crm_send_email, crm_ingest_email, crm_mark_sent, crm_mark_failed, crm_set_owner

begin;

create extension if not exists pgcrypto;

-- =====================================================================
-- 1. staff directory
-- =====================================================================
create table if not exists public.staff (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  email       text not null,
  name        text not null default '',
  role        text not null default 'team' check (role in ('owner','team')),
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- every auth user gets a staff row; the first one is the owner
insert into public.staff (user_id, email, role, created_at)
select u.id, coalesce(u.email, ''),
       case when not exists (select 1 from public.staff) and row_number() over (order by u.created_at, u.id) = 1 then 'owner' else 'team' end,
       u.created_at
from auth.users u
where not exists (select 1 from public.staff s where s.user_id = u.id)
on conflict (user_id) do nothing;

-- any later login (added in Supabase → Authentication → Users) becomes team automatically
create or replace function public.crm_handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.is_anonymous is true then return new; end if;   -- never make an anonymous sign-in staff
  insert into public.staff (user_id, email, role)
  values (new.id, coalesce(new.email, ''), case when exists (select 1 from public.staff) then 'team' else 'owner' end)
  on conflict (user_id) do nothing;
  return new;
end $$;
do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'crm_on_auth_user_created') then
    create trigger crm_on_auth_user_created after insert on auth.users for each row execute function public.crm_handle_new_user();
  end if;
end $$;

create or replace function public.crm_is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.staff where user_id = auth.uid() and active);
$$;
create or replace function public.crm_is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.staff where user_id = auth.uid() and active and role = 'owner');
$$;

-- ▶ OWNER helper: select public.crm_set_owner('you@example.com');
create or replace function public.crm_set_owner(p_email text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_email is null or p_email = '' then return; end if;
  update public.staff set role = 'owner', active = true where lower(email) = lower(p_email);
  if not found then raise notice 'crm_set_owner: no login with email % yet — add it in Authentication → Users and run again', p_email; end if;
end $$;

alter table public.staff enable row level security;
drop policy if exists "staff read staff"   on public.staff;
drop policy if exists "owner edit staff"   on public.staff;
create policy "staff read staff" on public.staff for select to authenticated using (public.crm_is_staff());
create policy "owner edit staff" on public.staff for update to authenticated using (public.crm_is_owner()) with check (public.crm_is_owner());
grant select, update on public.staff to authenticated;

-- =====================================================================
-- 2. enquiries: pipeline + first refusal
-- =====================================================================
alter table public.enquiries
  add column if not exists triage            text not null default 'pending',
  add column if not exists assigned_to       uuid references public.staff(user_id) on delete set null,
  add column if not exists released_at       timestamptz,
  add column if not exists released_by       uuid,
  add column if not exists release_note      text,
  add column if not exists value             numeric(10,2),
  add column if not exists labels            text[] not null default '{}',
  add column if not exists subject           text,
  add column if not exists gmail_thread_id   text,
  add column if not exists needs_reply       boolean not null default true,
  add column if not exists last_activity_at  timestamptz not null default now(),
  add column if not exists closed_at         timestamptz,
  add column if not exists outcome_reason    text;

alter table public.enquiries drop constraint if exists enquiries_status_check;
update public.enquiries set status = 'won' where status = 'booked';
alter table public.enquiries add constraint enquiries_status_check check (status in ('new','contacted','quoted','won','lost','declined'));
alter table public.enquiries drop constraint if exists enquiries_triage_check;
alter table public.enquiries add constraint enquiries_triage_check check (triage in ('pending','mine','team','ignored'));
alter table public.enquiries drop constraint if exists enquiries_source_check;
alter table public.enquiries add constraint enquiries_source_check check (source in ('website','email','phone','walk-in','other'));
create index if not exists enquiries_triage_idx  on public.enquiries (triage, assigned_to);
create index if not exists enquiries_thread_idx  on public.enquiries (gmail_thread_id);
create index if not exists enquiries_email_idx   on public.enquiries (lower(email));
create index if not exists enquiries_created_idx on public.enquiries (created_at desc);

-- =====================================================================
-- 3. timeline, notifications, labels, templates, settings, outbox, figures
-- =====================================================================
create table if not exists public.enquiry_activity (
  id          uuid primary key default gen_random_uuid(),
  enquiry_id  uuid not null references public.enquiries(id) on delete cascade,
  created_at  timestamptz not null default now(),
  actor       uuid references public.staff(user_id) on delete set null,   -- null = the website / email / system
  kind        text not null check (kind in ('form','note','email_in','email_out','stage','value','triage','assign','label','system')),
  body        text not null default '',
  meta        jsonb not null default '{}'::jsonb
);
create index if not exists enquiry_activity_idx on public.enquiry_activity (enquiry_id, created_at);

create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  staff_id    uuid not null references public.staff(user_id) on delete cascade,
  enquiry_id  uuid references public.enquiries(id) on delete cascade,
  created_at  timestamptz not null default now(),
  title       text not null,
  body        text not null default '',
  read_at     timestamptz
);
create index if not exists notifications_idx on public.notifications (staff_id, read_at, created_at desc);

create table if not exists public.crm_labels (
  name    text primary key,
  colour  text not null default '#6E7F5C',
  sort    integer not null default 0
);
insert into public.crm_labels (name, colour, sort) values
  ('Hot lead', '#d4772f', 1), ('Needs quote', '#7f67b8', 2), ('Follow up', '#b8860b', 3), ('Repeat client', '#22874f', 4)
on conflict (name) do nothing;

create table if not exists public.crm_templates (
  id       uuid primary key default gen_random_uuid(),
  name     text not null,
  subject  text not null default '',
  body     text not null default '',
  sort     integer not null default 0
);
insert into public.crm_templates (name, subject, body, sort)
select * from (values
  ('First reply', 'Your enquiry to King''s Clubhouse',
   'Hi {{name}},' || E'\n\n' || 'Thanks for getting in touch about {{event}}. {{date}} looks possible — I''ll check the diary and come back to you with availability and a quote.' || E'\n\n' || 'In the meantime, is there anything else you''d like to tell us about the day?', 1),
  ('Quote', 'Your quote from King''s Clubhouse',
   'Hi {{name}},' || E'\n\n' || 'Here''s your quote for {{event}} on {{date}}:' || E'\n\n' || '• Hire: £' || E'\n' || '• Bar minimum spend: £' || E'\n' || '• Deposit to secure the date: £' || E'\n\n' || 'Everything you need to know about set-up times, food and drink and finishing by 11pm is on kingsclubhouse.co.uk. Shall I pencil the date in?', 2),
  ('Not available', 'Your enquiry to King''s Clubhouse',
   'Hi {{name}},' || E'\n\n' || 'Thanks for thinking of us for {{event}}. Unfortunately {{date}} is already taken. If your dates are flexible, tell me a few that could work and I''ll check them straight away.', 3),
  ('Chasing', 'Still thinking about King''s Clubhouse?',
   'Hi {{name}},' || E'\n\n' || 'Just checking you got our quote for {{event}}. Dates go quickly over the summer, so let me know if you''d like us to hold yours.', 4)
) as v(name, subject, body, sort)
where not exists (select 1 from public.crm_templates);

create table if not exists public.crm_settings (
  id                integer primary key default 1 check (id = 1),
  send_webhook_url  text,                                              -- n8n "send reply" production webhook URL
  api_secret        text not null default encode(gen_random_bytes(18), 'hex'),  -- shared with n8n; paste into both workflows
  signature         text not null default E'King''s Clubhouse\nArthur Road, Motspur Park, New Malden KT3 6LX\ninfo@kingsclubhouse.co.uk · kingsclubhouse.co.uk',
  ignored_senders   text[] not null default '{}',
  notify_email      boolean not null default true,                    -- n8n also emails staff about new enquiries
  migrated_at       timestamptz,
  updated_at        timestamptz not null default now()
);
insert into public.crm_settings (id) values (1) on conflict (id) do nothing;

create table if not exists public.email_outbox (
  id                uuid primary key default gen_random_uuid(),
  enquiry_id        uuid not null references public.enquiries(id) on delete cascade,
  to_email          text not null,
  to_name           text not null default '',
  subject           text not null,
  body              text not null,                                     -- plain text; the signature is appended by crm_send_email
  created_by        uuid references public.staff(user_id) on delete set null,
  created_at        timestamptz not null default now(),
  status            text not null default 'queued' check (status in ('queued','sent','failed','manual')),
  sent_at           timestamptz,
  error             text,
  gmail_message_id  text,
  gmail_thread_id   text,
  in_reply_to       text
);
create index if not exists email_outbox_idx on public.email_outbox (enquiry_id, created_at);

create table if not exists public.club_metrics (
  month               date primary key check (month = date_trunc('month', month)::date),
  bar_sales           numeric(12,2),      -- £ for the month
  paying_members      integer,            -- total paying members at month end
  facebook_followers  integer,
  instagram_followers integer,
  whatsapp_members    integer,            -- people actually in the WhatsApp group
  email_subscribers   integer,            -- optional override; blank = counted from sign-ups
  notes               text,
  updated_by          uuid references public.staff(user_id) on delete set null,
  updated_at          timestamptz not null default now()
);

drop trigger if exists club_metrics_touch on public.club_metrics;
create trigger club_metrics_touch before update on public.club_metrics for each row execute function public.touch_updated_at();
drop trigger if exists crm_settings_touch on public.crm_settings;
create trigger crm_settings_touch before update on public.crm_settings for each row execute function public.touch_updated_at();

-- =====================================================================
-- 4. guards: team can't change who sees what, or capture an email thread
-- =====================================================================
create or replace function public.crm_enquiry_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return new; end if;                     -- server-side (SQL editor, n8n via RPC)
  if current_setting('crm.bypass', true) = 'on' then return new; end if;  -- inside crm_triage / crm_pick_up / crm_assign
  if public.crm_is_owner() then return new; end if;
  if new.triage is distinct from old.triage or new.assigned_to is distinct from old.assigned_to
     or new.released_at is distinct from old.released_at or new.released_by is distinct from old.released_by
     or new.gmail_thread_id is distinct from old.gmail_thread_id or new.source is distinct from old.source
     or new.created_at is distinct from old.created_at or new.email is distinct from old.email then
    raise exception 'Only an owner can change that (triage, assignment, email thread, sender or dates).';
  end if;
  return new;
end $$;
drop trigger if exists crm_enquiry_guard on public.enquiries;
create trigger crm_enquiry_guard before update on public.enquiries for each row execute function public.crm_enquiry_guard();

-- =====================================================================
-- 5. row-level security
-- =====================================================================
-- enquiries: owners see everything; team see what has been sent to the team
drop policy if exists "staff all enquiries"   on public.enquiries;
drop policy if exists "public insert enquiry" on public.enquiries;
drop policy if exists "crm select enquiries"  on public.enquiries;
drop policy if exists "crm insert enquiries"  on public.enquiries;
drop policy if exists "crm update enquiries"  on public.enquiries;
drop policy if exists "crm delete enquiries"  on public.enquiries;
create policy "public insert enquiry" on public.enquiries for insert to anon
  with check (status = 'new' and source = 'website' and triage = 'pending' and assigned_to is null and gmail_thread_id is null);
create policy "crm select enquiries" on public.enquiries for select to authenticated
  using (public.crm_is_owner() or (public.crm_is_staff() and triage = 'team'));
create policy "crm insert enquiries" on public.enquiries for insert to authenticated
  with check (public.crm_is_staff() and gmail_thread_id is null);
create policy "crm update enquiries" on public.enquiries for update to authenticated
  using (public.crm_is_owner() or (public.crm_is_staff() and triage = 'team'))
  with check (public.crm_is_owner() or (public.crm_is_staff() and triage = 'team'));
create policy "crm delete enquiries" on public.enquiries for delete to authenticated using (public.crm_is_owner());

-- sign-ups: staff only (was any authenticated user)
drop policy if exists "staff all signups" on public.signups;
create policy "staff all signups" on public.signups for all to authenticated using (public.crm_is_staff()) with check (public.crm_is_staff());

alter table public.enquiry_activity enable row level security;
drop policy if exists "crm read activity"   on public.enquiry_activity;
drop policy if exists "crm insert activity" on public.enquiry_activity;
create policy "crm read activity" on public.enquiry_activity for select to authenticated
  using (exists (select 1 from public.enquiries e where e.id = enquiry_activity.enquiry_id));
create policy "crm insert activity" on public.enquiry_activity for insert to authenticated
  with check (actor = auth.uid() and kind in ('note','label') and exists (select 1 from public.enquiries e where e.id = enquiry_activity.enquiry_id));

alter table public.notifications enable row level security;
drop policy if exists "own notifications" on public.notifications;
drop policy if exists "own notifications update" on public.notifications;
create policy "own notifications" on public.notifications for select to authenticated using (staff_id = auth.uid());
create policy "own notifications update" on public.notifications for update to authenticated using (staff_id = auth.uid()) with check (staff_id = auth.uid());

alter table public.crm_labels enable row level security;
alter table public.crm_templates enable row level security;
alter table public.crm_settings enable row level security;
drop policy if exists "staff read labels"     on public.crm_labels;
drop policy if exists "owner edit labels"     on public.crm_labels;
drop policy if exists "staff read templates"  on public.crm_templates;
drop policy if exists "owner edit templates"  on public.crm_templates;
drop policy if exists "owner settings"        on public.crm_settings;
create policy "staff read labels"    on public.crm_labels    for select to authenticated using (public.crm_is_staff());
create policy "owner edit labels"    on public.crm_labels    for all    to authenticated using (public.crm_is_owner()) with check (public.crm_is_owner());
create policy "staff read templates" on public.crm_templates for select to authenticated using (public.crm_is_staff());
create policy "owner edit templates" on public.crm_templates for all    to authenticated using (public.crm_is_owner()) with check (public.crm_is_owner());
create policy "owner settings"       on public.crm_settings  for all    to authenticated using (public.crm_is_owner()) with check (public.crm_is_owner());

alter table public.email_outbox enable row level security;
drop policy if exists "crm read outbox" on public.email_outbox;
create policy "crm read outbox" on public.email_outbox for select to authenticated
  using (exists (select 1 from public.enquiries e where e.id = email_outbox.enquiry_id));

alter table public.club_metrics enable row level security;
drop policy if exists "staff all metrics" on public.club_metrics;
create policy "staff all metrics" on public.club_metrics for all to authenticated using (public.crm_is_staff()) with check (public.crm_is_staff());

grant select, insert                 on public.enquiry_activity to authenticated;
grant select, update                 on public.notifications    to authenticated;
grant select, insert, update, delete on public.crm_labels       to authenticated;
grant select, insert, update, delete on public.crm_templates    to authenticated;
grant select, update                 on public.crm_settings     to authenticated;
grant select                         on public.email_outbox     to authenticated;
grant select, insert, update, delete on public.club_metrics     to authenticated;

-- =====================================================================
-- 6. helpers
-- =====================================================================
create or replace function public.crm_log(p_enquiry uuid, p_kind text, p_body text, p_meta jsonb default '{}'::jsonb, p_actor uuid default null) returns void
language sql security definer set search_path = public as $$
  insert into public.enquiry_activity (enquiry_id, actor, kind, body, meta) values (p_enquiry, p_actor, p_kind, coalesce(p_body, ''), coalesce(p_meta, '{}'::jsonb));
  update public.enquiries set last_activity_at = now() where id = p_enquiry;
$$;

create or replace function public.crm_notify(p_staff uuid[], p_enquiry uuid, p_title text, p_body text) returns void
language sql security definer set search_path = public as $$
  insert into public.notifications (staff_id, enquiry_id, title, body)
  select s.user_id, p_enquiry, p_title, coalesce(p_body, '') from public.staff s where s.active and s.user_id = any (p_staff);
$$;

create or replace function public.crm_owners() returns uuid[]
language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(user_id), '{}') from public.staff where active and role = 'owner';
$$;

create or replace function public.crm_visible(p_enquiry uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.enquiries e where e.id = p_enquiry
                 and (public.crm_is_owner() or (public.crm_is_staff() and e.triage = 'team')));
$$;

-- =====================================================================
-- 7. actions (called from the staff area)
-- =====================================================================
-- first refusal: 'mine' (stays with the owners), 'team' (everyone sees it, team can pick it up), 'ignored' (not an enquiry)
create or replace function public.crm_triage(p_id uuid, p_decision text, p_note text default null, p_ignore_sender boolean default false) returns void
language plpgsql security definer set search_path = public as $$
declare e public.enquiries; who text;
begin
  if not public.crm_is_owner() then raise exception 'Only an owner can do that.'; end if;
  perform set_config('crm.bypass', 'on', true);
  if p_decision not in ('mine','team','ignored') then raise exception 'Unknown decision %', p_decision; end if;
  select * into e from public.enquiries where id = p_id; if not found then raise exception 'Enquiry not found'; end if;
  select coalesce(nullif(name, ''), email) into who from public.staff where user_id = auth.uid();
  update public.enquiries set
    triage = p_decision,
    assigned_to = case when p_decision = 'mine' then auth.uid() else null end,
    released_at = case when p_decision = 'team' then now() else released_at end,
    released_by = case when p_decision = 'team' then auth.uid() else released_by end,
    release_note = case when p_decision = 'team' then p_note else release_note end,
    needs_reply = case when p_decision = 'ignored' then false else needs_reply end,
    status = case when p_decision = 'ignored' and status = 'new' then 'declined' else status end,
    closed_at = case when p_decision = 'ignored' then now() else closed_at end,
    outcome_reason = case when p_decision = 'ignored' then coalesce(outcome_reason, 'Not an enquiry') else outcome_reason end
  where id = p_id;
  perform public.crm_log(p_id, 'triage',
    case p_decision when 'mine' then who || ' is replying to this one'
                    when 'team' then who || ' sent this to the team' || coalesce(': ' || p_note, '')
                    else who || ' marked this as not an enquiry' end,
    jsonb_build_object('decision', p_decision), auth.uid());
  if p_decision = 'team' then
    perform public.crm_notify((select coalesce(array_agg(user_id), '{}') from public.staff where active and user_id <> auth.uid()),
      p_id, 'New enquiry for the team: ' || e.name, coalesce(p_note, left(coalesce(e.message, ''), 140)));
  end if;
  if p_decision = 'ignored' and p_ignore_sender and e.email <> '' then
    update public.crm_settings set ignored_senders = array(select distinct unnest(ignored_senders || lower(e.email))) where id = 1;
  end if;
end $$;

-- team: take an enquiry from the queue
create or replace function public.crm_pick_up(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare e public.enquiries; who text;
begin
  if not public.crm_is_staff() then raise exception 'Staff only.'; end if;
  perform set_config('crm.bypass', 'on', true);
  select * into e from public.enquiries where id = p_id for update; if not found then raise exception 'Enquiry not found'; end if;
  if e.triage <> 'team' then raise exception 'This enquiry has not been sent to the team.'; end if;
  if e.assigned_to is not null and e.assigned_to <> auth.uid() then raise exception 'Someone has already picked this up.'; end if;
  select coalesce(nullif(name, ''), email) into who from public.staff where user_id = auth.uid();
  update public.enquiries set assigned_to = auth.uid() where id = p_id;
  perform public.crm_log(p_id, 'assign', who || ' picked this up', jsonb_build_object('staff', auth.uid()), auth.uid());
  perform public.crm_notify((select coalesce(array_agg(user_id), '{}') from public.staff where active and role = 'owner' and user_id <> auth.uid()),
    p_id, who || ' picked up ' || e.name, '');
end $$;

-- owner: hand an enquiry to one named person (or null to clear)
create or replace function public.crm_assign(p_id uuid, p_staff uuid) returns void
language plpgsql security definer set search_path = public as $$
declare who text; target text; e public.enquiries;
begin
  if not public.crm_is_owner() then raise exception 'Only an owner can do that.'; end if;
  perform set_config('crm.bypass', 'on', true);
  select * into e from public.enquiries where id = p_id; if not found then raise exception 'Enquiry not found'; end if;
  select coalesce(nullif(name, ''), email) into who from public.staff where user_id = auth.uid();
  select coalesce(nullif(name, ''), email) into target from public.staff where user_id = p_staff;
  update public.enquiries set assigned_to = p_staff, triage = case when p_staff is null then triage when triage = 'pending' then 'team' else triage end,
    released_at = coalesce(released_at, case when p_staff is not null then now() end), released_by = coalesce(released_by, case when p_staff is not null then auth.uid() end)
  where id = p_id;
  perform public.crm_log(p_id, 'assign', case when p_staff is null then who || ' cleared the assignment' else who || ' assigned this to ' || target end, jsonb_build_object('staff', p_staff), auth.uid());
  if p_staff is not null and p_staff <> auth.uid() then
    perform public.crm_notify(array[p_staff], p_id, who || ' assigned you ' || e.name, left(coalesce(e.message, ''), 140));
  end if;
end $$;

-- anyone who can see it: stage / value / outcome
create or replace function public.crm_set_stage(p_id uuid, p_status text, p_value numeric default null, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
declare e public.enquiries; who text;
begin
  if not public.crm_visible(p_id) then raise exception 'Not allowed.'; end if;
  if p_status not in ('new','contacted','quoted','won','lost','declined') then raise exception 'Unknown stage %', p_status; end if;
  select * into e from public.enquiries where id = p_id;
  select coalesce(nullif(name, ''), email) into who from public.staff where user_id = auth.uid();
  update public.enquiries set status = p_status,
    value = coalesce(p_value, value),
    closed_at = case when p_status in ('won','lost','declined') then coalesce(closed_at, now()) else null end,
    outcome_reason = case when p_status in ('lost','declined') then coalesce(p_reason, outcome_reason) else null end
  where id = p_id;
  if e.status is distinct from p_status then
    perform public.crm_log(p_id, 'stage', who || ' moved this to ' || p_status || case when p_status in ('lost','declined') and p_reason is not null then ' — ' || p_reason else '' end,
      jsonb_build_object('from', e.status, 'to', p_status, 'reason', p_reason), auth.uid());
  end if;
  if p_value is not null and e.value is distinct from p_value then
    perform public.crm_log(p_id, 'value', who || ' set the value to £' || to_char(p_value, 'FM999,999,990.00'), jsonb_build_object('from', e.value, 'to', p_value), auth.uid());
  end if;
end $$;

create or replace function public.crm_add_note(p_id uuid, p_body text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.crm_visible(p_id) then raise exception 'Not allowed.'; end if;
  if coalesce(trim(p_body), '') = '' then return; end if;
  perform public.crm_log(p_id, 'note', trim(p_body), '{}'::jsonb, auth.uid());
end $$;

create or replace function public.crm_set_labels(p_id uuid, p_labels text[]) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.crm_visible(p_id) then raise exception 'Not allowed.'; end if;
  update public.enquiries set labels = coalesce(p_labels, '{}') where id = p_id;
end $$;

create or replace function public.crm_mark_replied(p_id uuid, p_how text default 'by hand') returns void
language plpgsql security definer set search_path = public as $$
declare who text;
begin
  if not public.crm_visible(p_id) then raise exception 'Not allowed.'; end if;
  select coalesce(nullif(name, ''), email) into who from public.staff where user_id = auth.uid();
  update public.enquiries set needs_reply = false, status = case when status = 'new' then 'contacted' else status end where id = p_id;
  perform public.crm_log(p_id, 'email_out', who || ' replied ' || p_how, jsonb_build_object('manual', true), auth.uid());
end $$;

-- write a reply in the app. If the n8n webhook is set up it is sent from info@; otherwise it is logged as 'manual'
-- and the app opens the mail client with the same text.
create or replace function public.crm_send_email(p_id uuid, p_subject text, p_body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare e public.enquiries; s public.crm_settings; o public.email_outbox; who text; full_body text; last_in text;
begin
  if not public.crm_visible(p_id) then raise exception 'Not allowed.'; end if;
  if coalesce(trim(p_subject), '') = '' or coalesce(trim(p_body), '') = '' then raise exception 'A subject and a message are needed.'; end if;
  select * into e from public.enquiries where id = p_id;
  select * into s from public.crm_settings where id = 1;
  select coalesce(nullif(name, ''), email) into who from public.staff where user_id = auth.uid();
  full_body := trim(p_body) || E'\n\n' || coalesce(s.signature, '');
  select meta->>'message_id' into last_in from public.enquiry_activity where enquiry_id = p_id and kind = 'email_in' order by created_at desc limit 1;
  insert into public.email_outbox (enquiry_id, to_email, to_name, subject, body, created_by, status, gmail_thread_id, in_reply_to)
  values (p_id, e.email, e.name, trim(p_subject), full_body, auth.uid(), case when coalesce(s.send_webhook_url, '') <> '' then 'queued' else 'manual' end, e.gmail_thread_id, last_in)
  returning * into o;
  update public.enquiries set needs_reply = false, status = case when status = 'new' then 'contacted' else status end, subject = coalesce(subject, trim(p_subject)) where id = p_id;
  perform public.crm_log(p_id, 'email_out', trim(p_body), jsonb_build_object('outbox', o.id, 'subject', trim(p_subject), 'status', o.status, 'by', who), auth.uid());
  return jsonb_build_object('id', o.id, 'status', o.status, 'to', o.to_email, 'subject', o.subject, 'body', o.body);
end $$;

-- queued replies are handed to n8n by pg_net (Database → Extensions → pg_net). Without pg_net the row just waits
-- and the app shows it as "not sent yet" with an "open in mail" fallback.
create or replace function public.crm_outbox_dispatch() returns trigger
language plpgsql security definer set search_path = public as $$
declare s public.crm_settings;
begin
  if new.status <> 'queued' then return new; end if;
  select * into s from public.crm_settings where id = 1;
  if coalesce(s.send_webhook_url, '') = '' then return new; end if;
  if exists (select 1 from pg_extension where extname = 'pg_net') then
    execute format('select net.http_post(url := %L, body := %L::jsonb, headers := %L::jsonb)',
      s.send_webhook_url,
      jsonb_build_object('outbox_id', new.id, 'enquiry_id', new.enquiry_id, 'to', new.to_email, 'to_name', new.to_name, 'subject', new.subject, 'body', new.body,
                         'thread_id', new.gmail_thread_id, 'in_reply_to', new.in_reply_to, 'secret', s.api_secret)::text,
      '{"Content-Type":"application/json"}');
  end if;
  return new;
end $$;
drop trigger if exists crm_outbox_dispatch on public.email_outbox;
create trigger crm_outbox_dispatch after insert on public.email_outbox for each row execute function public.crm_outbox_dispatch();

-- =====================================================================
-- 8. called by n8n (anon key + the shared secret)
-- =====================================================================
create or replace function public.crm_check_secret(p_secret text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_secret is null or p_secret <> (select api_secret from public.crm_settings where id = 1) then raise exception 'Bad secret'; end if;
end $$;

-- an email arrived at info@: join its thread, join an open enquiry from the same address, or open a new one
create or replace function public.crm_ingest_email(p_secret text, p_from_email text, p_from_name text, p_subject text, p_body text, p_thread_id text, p_message_id text, p_received_at timestamptz default now()) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s public.crm_settings; e public.enquiries; fe text; fn text; body text;
begin
  perform public.crm_check_secret(p_secret);
  select * into s from public.crm_settings where id = 1;
  fe := lower(trim(coalesce(p_from_email, '')));
  fn := coalesce(nullif(trim(p_from_name), ''), split_part(fe, '@', 1));
  body := left(coalesce(p_body, ''), 20000);
  if fe = '' or fe = any (s.ignored_senders) or exists (select 1 from public.staff where lower(email) = fe)
     or fe like '%noreply%' or fe like '%no-reply%' or fe like 'mailer-daemon%' then
    return jsonb_build_object('ignored', true);
  end if;
  if p_message_id is not null and exists (select 1 from public.enquiry_activity where kind = 'email_in' and meta->>'message_id' = p_message_id) then
    return jsonb_build_object('duplicate', true);
  end if;
  -- 1. same Gmail thread
  if p_thread_id is not null then select * into e from public.enquiries where gmail_thread_id = p_thread_id limit 1; end if;
  -- 2. a reply to something we sent (thread id recorded on the outbox row)
  if e.id is null and p_thread_id is not null then
    select q.* into e from public.enquiries q join public.email_outbox o on o.enquiry_id = q.id where o.gmail_thread_id = p_thread_id order by o.created_at desc limit 1;
  end if;
  -- 3. an open enquiry from the same address in the last 120 days
  if e.id is null then
    select * into e from public.enquiries where lower(email) = fe and status in ('new','contacted','quoted') and created_at > now() - interval '120 days' order by created_at desc limit 1;
  end if;
  if e.id is not null then
    update public.enquiries set needs_reply = true, gmail_thread_id = coalesce(gmail_thread_id, p_thread_id), subject = coalesce(subject, p_subject) where id = e.id;
    perform public.crm_log(e.id, 'email_in', body, jsonb_build_object('from', fe, 'from_name', fn, 'subject', p_subject, 'message_id', p_message_id, 'thread_id', p_thread_id, 'received_at', p_received_at));
    perform public.crm_notify(case when e.triage in ('team') then (select coalesce(array_agg(user_id), '{}') from public.staff where active)
                                   when e.assigned_to is not null then (select array_agg(distinct x) from unnest(public.crm_owners() || e.assigned_to) x)
                                   else public.crm_owners() end,
      e.id, 'New email from ' || e.name, left(body, 140));
    return jsonb_build_object('enquiry_id', e.id, 'joined', true);
  end if;
  insert into public.enquiries (name, email, source, status, triage, subject, message, gmail_thread_id, needs_reply)
  values (fn, fe, 'email', 'new', 'pending', p_subject, body, p_thread_id, true) returning * into e;
  perform public.crm_log(e.id, 'email_in', body, jsonb_build_object('from', fe, 'from_name', fn, 'subject', p_subject, 'message_id', p_message_id, 'thread_id', p_thread_id, 'received_at', p_received_at));
  perform public.crm_notify(public.crm_owners(), e.id, 'New email enquiry from ' || fn, coalesce(p_subject, ''));
  return jsonb_build_object('enquiry_id', e.id, 'created', true);
end $$;

create or replace function public.crm_mark_sent(p_secret text, p_outbox_id uuid, p_message_id text, p_thread_id text) returns void
language plpgsql security definer set search_path = public as $$
declare o public.email_outbox;
begin
  perform public.crm_check_secret(p_secret);
  update public.email_outbox set status = 'sent', sent_at = now(), gmail_message_id = p_message_id, gmail_thread_id = coalesce(p_thread_id, gmail_thread_id), error = null where id = p_outbox_id returning * into o;
  if o.id is not null and p_thread_id is not null then
    update public.enquiries set gmail_thread_id = coalesce(gmail_thread_id, p_thread_id) where id = o.enquiry_id;
  end if;
end $$;

create or replace function public.crm_mark_failed(p_secret text, p_outbox_id uuid, p_error text) returns void
language plpgsql security definer set search_path = public as $$
declare o public.email_outbox;
begin
  perform public.crm_check_secret(p_secret);
  update public.email_outbox set status = 'failed', error = left(coalesce(p_error, 'unknown'), 500) where id = p_outbox_id returning * into o;
  if o.id is not null then
    update public.enquiries set needs_reply = true where id = o.enquiry_id;
    perform public.crm_notify(public.crm_owners() || coalesce(array[o.created_by], '{}'), o.enquiry_id, 'A reply did not send', left(coalesce(p_error, ''), 140));
  end if;
end $$;

-- the website form posts straight into enquiries; log it on the timeline and tell the owners
create or replace function public.crm_on_new_enquiry() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.source = 'website' then
    perform public.crm_log(new.id, 'form', coalesce(new.message, ''), jsonb_build_object('event_type', new.event_type, 'preferred_date', new.preferred_date, 'adults', new.adults, 'children', new.children, 'spaces', new.spaces));
    perform public.crm_notify(public.crm_owners(), new.id, 'New enquiry from ' || new.name, coalesce(nullif(new.event_type, ''), '') || case when new.preferred_date is not null then ' · ' || to_char(new.preferred_date, 'DD Mon YYYY') else '' end);
  elsif new.source in ('phone','walk-in','other') then
    perform public.crm_log(new.id, 'form', coalesce(new.message, ''), jsonb_build_object('source', new.source), auth.uid());
  end if;
  return new;
end $$;
drop trigger if exists crm_on_new_enquiry on public.enquiries;
create trigger crm_on_new_enquiry after insert on public.enquiries for each row execute function public.crm_on_new_enquiry();

grant execute on function public.crm_is_staff(), public.crm_is_owner(), public.crm_visible(uuid), public.crm_owners() to authenticated;
grant execute on function public.crm_triage(uuid, text, text, boolean), public.crm_pick_up(uuid), public.crm_assign(uuid, uuid), public.crm_set_stage(uuid, text, numeric, text),
  public.crm_add_note(uuid, text), public.crm_set_labels(uuid, text[]), public.crm_mark_replied(uuid, text), public.crm_send_email(uuid, text, text) to authenticated;
grant execute on function public.crm_ingest_email(text, text, text, text, text, text, text, timestamptz), public.crm_mark_sent(text, uuid, text, text), public.crm_mark_failed(text, uuid, text) to anon, authenticated;
revoke execute on function public.crm_log(uuid, text, text, jsonb, uuid), public.crm_notify(uuid[], uuid, text, text), public.crm_check_secret(text), public.crm_set_owner(text) from anon, authenticated;

-- =====================================================================
-- 9. one-off carry-over of enquiries that were here before the CRM (runs once)
-- =====================================================================
do $$
declare r record;
begin
  if (select migrated_at from public.crm_settings where id = 1) is not null then return; end if;
  for r in select * from public.enquiries where not exists (select 1 from public.enquiry_activity a where a.enquiry_id = enquiries.id) loop
    insert into public.enquiry_activity (enquiry_id, created_at, kind, body, meta)
      values (r.id, r.created_at, 'form', coalesce(r.message, ''), jsonb_build_object('event_type', r.event_type, 'preferred_date', r.preferred_date, 'adults', r.adults, 'children', r.children, 'spaces', r.spaces));
    if coalesce(trim(r.notes), '') <> '' then
      insert into public.enquiry_activity (enquiry_id, created_at, kind, body) values (r.id, coalesce(r.updated_at, r.created_at), 'note', r.notes);
    end if;
    update public.enquiries set
      triage = case when status = 'new' then 'pending' else 'team' end,
      needs_reply = (status = 'new'),
      last_activity_at = coalesce(updated_at, created_at),
      closed_at = case when status in ('won','lost','declined') then coalesce(updated_at, created_at) else null end
    where id = r.id;
  end loop;
  update public.crm_settings set migrated_at = now() where id = 1;
end $$;

-- =====================================================================
-- 10. views the app reads in one go
-- =====================================================================
create or replace view public.crm_staff with (security_invoker = true) as
  select user_id, email, name, role, active, created_at from public.staff;
grant select on public.crm_staff to authenticated;

commit;

-- ▶ OWNER (optional): make sure the right person is the owner, then check the result
-- select public.crm_set_owner('james@example.com');
select (select count(*) from public.staff) as staff_logins,
       (select count(*) from public.staff where role = 'owner') as owners,
       (select count(*) from public.enquiries) as enquiries,
       (select count(*) from public.enquiries where triage = 'pending') as waiting_for_owner,
       (select count(*) from public.club_metrics) as months_of_figures,
       (select api_secret from public.crm_settings where id = 1) as secret_for_n8n;
