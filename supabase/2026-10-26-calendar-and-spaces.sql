-- King's Clubhouse · 26 Oct 2026 · "What's on" calendar + new spaces line-up
-- Paste into Supabase → SQL Editor → New query → Run. Safe to re-run.

begin;

-- 1. calendar of public events (edited in the staff area → Calendar)
create table if not exists public.calendar_events (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  event_date   date not null,
  start_time   text,                                   -- 'HH:MM', optional
  end_time     text,                                   -- 'HH:MM', optional
  location     text not null default 'King''s Clubhouse',
  price        text not null default 'Free',           -- label on the card: 'Free', '£5', 'Members'…
  description  text not null default '',
  link_url     text,                                   -- optional booking/ticket link
  photo_id     uuid references public.photos(id) on delete set null,
  visible      boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists calendar_events_date_idx on public.calendar_events (event_date);
drop trigger if exists calendar_touch on public.calendar_events;
create trigger calendar_touch before update on public.calendar_events for each row execute function public.touch_updated_at();

alter table public.calendar_events enable row level security;
drop policy if exists "public read calendar" on public.calendar_events;
drop policy if exists "staff all calendar"   on public.calendar_events;
create policy "public read calendar" on public.calendar_events for select to anon using (visible);
create policy "staff all calendar"   on public.calendar_events for all to authenticated using (true) with check (true);
grant select on public.calendar_events to anon;
grant select, insert, update, delete on public.calendar_events to authenticated;

create or replace view public.site_calendar with (security_invoker = true) as
  select c.id, c.title, c.event_date, c.start_time, c.end_time, c.location, c.price, c.description, c.link_url, p.url as photo_url
  from public.calendar_events c left join public.photos p on p.id = c.photo_id
  where c.visible
  order by c.event_date, c.start_time nulls first;
grant select on public.site_calendar to anon, authenticated;

-- 2. spaces: Balcony and Facilities cards and the pricing section are gone; Whole Venue added; Pitches now the floodlit match
delete from public.placements where slot in ('space.balcony', 'space.facilities', 'pricing');
insert into public.placements (slot, label, photo_id) values
  ('space.whole', 'Space: The Whole Venue',              (select id from public.photos where key='hero3')),
  ('enquire',     'Enquiry section background',          (select id from public.photos where key='marqueeparty'))
on conflict (slot) do nothing;
update public.placements set photo_id = (select id from public.photos where key='nightmatch') where slot = 'space.pitches';

commit;

-- check: should return 0 / 21 / true
select (select count(*) from public.calendar_events) as calendar_dates,
       (select count(*) from public.placements) as slots,
       exists (select 1 from public.placements where slot = 'space.whole') as whole_venue_slot;
