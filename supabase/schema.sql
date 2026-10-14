-- King's Clubhouse · Supabase schema
-- Run once in the Supabase SQL editor (Project → SQL Editor → New query → paste → Run).
-- Safe to re-run: everything is "if not exists" / "or replace", seed inserts skip duplicates.

create extension if not exists pgcrypto;

-- ---------- photos ----------
create table if not exists public.photos (
  id            uuid primary key default gen_random_uuid(),
  key           text unique,                      -- short handle, e.g. 'hero1' (baked-in photos) or null for uploads
  storage_path  text,                             -- 'uploads/<uuid>.jpg' in the 'photos' bucket, null for baked-in
  url           text not null,                    -- what the <img> uses: site-relative '/photos/x.webp' or a Storage public URL
  caption       text not null default '',         -- shown in the phone gallery lightbox
  alt           text not null default '',         -- accessibility text
  in_gallery    boolean not null default true,    -- appears in the phone photo grid
  sort          integer not null default 0,       -- gallery order
  created_at    timestamptz not null default now()
);

-- ---------- events (the "Events we host" deck) ----------
create table if not exists public.events (
  id            uuid primary key default gen_random_uuid(),
  slug          text not null,                    -- pre-selects "Type of event" on the enquiry form (kids, birthday, bbq, dinner, wedding, tournament, community, corporate, other)
  tag           text not null,                    -- small orange label, e.g. 'School holidays'
  title         text not null,
  teaser        text not null,                    -- one line on the card
  description   text not null,                    -- full text in the pop-up
  photo_id      uuid references public.photos(id) on delete set null,
  sort          integer not null default 0,
  visible       boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ---------- placements (which photo sits in which fixed slot on the site) ----------
create table if not exists public.placements (
  slot          text primary key,                 -- hero1, hero2, hero3, highlight1..3, space.clubhouse, space.balcony, space.braai, space.marquee, space.pitches, space.facilities, pricing, slide1..5
  label         text not null,
  photo_id      uuid references public.photos(id) on delete set null
);

-- ---------- enquiries (the big form) ----------
create table if not exists public.enquiries (
  id             uuid primary key default gen_random_uuid(),
  created_at     timestamptz not null default now(),
  name           text not null,
  email          text not null,
  phone          text,
  event_type     text,
  preferred_date date,
  dates_flexible boolean not null default false,
  start_time     text,
  finish_time    text,
  adults         integer,
  children       integer,
  spaces         text[] not null default '{}',
  caterer        text,
  member         text,
  message        text,
  status         text not null default 'new' check (status in ('new','contacted','quoted','booked','lost')),
  notes          text,
  source         text not null default 'website',
  updated_at     timestamptz not null default now()
);

-- ---------- community sign-ups ----------
create table if not exists public.signups (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  name        text not null,
  email       text not null,
  mobile      text,
  news        boolean not null default true,      -- events & news by email
  whatsapp    boolean not null default false,     -- wants the WhatsApp invite
  status      text not null default 'active' check (status in ('active','unsubscribed')),
  notes       text
);

-- updated_at helper
create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
drop trigger if exists events_touch on public.events;
create trigger events_touch before update on public.events for each row execute function public.touch_updated_at();
drop trigger if exists enquiries_touch on public.enquiries;
create trigger enquiries_touch before update on public.enquiries for each row execute function public.touch_updated_at();

-- ---------- row-level security ----------
-- Visitors (anon key): read the public content, write nothing except their own enquiry / sign-up.
-- Staff (any signed-in user — public sign-ups are disabled in Auth settings): full access.
alter table public.photos     enable row level security;
alter table public.events     enable row level security;
alter table public.placements enable row level security;
alter table public.enquiries  enable row level security;
alter table public.signups    enable row level security;

drop policy if exists "public read photos"     on public.photos;
drop policy if exists "public read events"     on public.events;
drop policy if exists "public read placements" on public.placements;
drop policy if exists "public insert enquiry"  on public.enquiries;
drop policy if exists "public insert signup"   on public.signups;
drop policy if exists "staff all photos"       on public.photos;
drop policy if exists "staff all events"       on public.events;
drop policy if exists "staff all placements"   on public.placements;
drop policy if exists "staff all enquiries"    on public.enquiries;
drop policy if exists "staff all signups"      on public.signups;

create policy "public read photos"     on public.photos     for select to anon, authenticated using (true);
create policy "public read events"     on public.events     for select to anon using (visible);
create policy "public read placements" on public.placements for select to anon, authenticated using (true);
create policy "public insert enquiry"  on public.enquiries  for insert to anon with check (status = 'new' and source = 'website');
create policy "public insert signup"   on public.signups    for insert to anon with check (status = 'active');

create policy "staff all photos"     on public.photos     for all to authenticated using (true) with check (true);
create policy "staff all events"     on public.events     for all to authenticated using (true) with check (true);
create policy "staff all placements" on public.placements for all to authenticated using (true) with check (true);
create policy "staff all enquiries"  on public.enquiries  for all to authenticated using (true) with check (true);
create policy "staff all signups"    on public.signups    for all to authenticated using (true) with check (true);

-- ---------- storage bucket for uploaded photos ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 10485760, array['image/jpeg','image/png','image/webp','image/heic'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "public read photo files"  on storage.objects;
drop policy if exists "staff write photo files"  on storage.objects;
drop policy if exists "staff update photo files" on storage.objects;
drop policy if exists "staff delete photo files" on storage.objects;
create policy "public read photo files"  on storage.objects for select to anon, authenticated using (bucket_id = 'photos');
create policy "staff write photo files"  on storage.objects for insert to authenticated with check (bucket_id = 'photos');
create policy "staff update photo files" on storage.objects for update to authenticated using (bucket_id = 'photos');
create policy "staff delete photo files" on storage.objects for delete to authenticated using (bucket_id = 'photos');

-- ---------- seed: the 11 baked-in photos ----------
insert into public.photos (key, url, caption, alt, in_gallery, sort) values
  ('hero1',      '/photos/hero1.webp',      'A summer evening outside the clubhouse',          'The clubhouse in full swing on a summer evening', true, 1),
  ('interior',   '/photos/interior.webp',   'Inside the clubhouse',                            'Clubhouse interior with bar, round tables and sofas', true, 2),
  ('bar',        '/photos/bar.webp',        'The bar',                                         'The clubhouse bar with round tables', true, 3),
  ('pitches',    '/photos/pitches.webp',    'Sunrise over the pitches from the balcony',       'Pitches stretching out from the balcony at sunrise', true, 4),
  ('funday',     '/photos/funday.webp',     'A bouncy castle on the grass',                    'Inflatable set up on the grass beside the clubhouse', true, 5),
  ('seating',    '/photos/seating.webp',    'Sofas and the trophy cabinet',                    'Clubhouse seating area with sofas and trophy cabinet', true, 6),
  ('floodlit',   '/photos/floodlit.webp',   'Under the floodlights',                           'Evening match under the floodlights', true, 7),
  ('hero3',      '/photos/hero3.webp',      'The view from the balcony',                       'Sunrise over the pitches from the clubhouse', true, 8),
  ('fundaycard', '/photos/fundaycard.webp', 'Family day on the grounds',                       'Inflatable on the grass for a family day', true, 9),
  ('bigpitch',   '/photos/bigpitch.webp',   'Evening match on the big pitch',                  'Floodlit match on the big pitch', true, 10),
  ('hero2',      '/photos/hero2.webp',      'Spectators on the touchline',                     'Evening match under floodlights with spectators on the touchline', true, 11)
on conflict (key) do nothing;

-- ---------- seed: fixed photo slots ----------
insert into public.placements (slot, label, photo_id) values
  ('hero1',            'Hero slide 1',                      (select id from public.photos where key='hero1')),
  ('hero2',            'Hero slide 2',                      (select id from public.photos where key='hero2')),
  ('hero3',            'Hero slide 3',                      (select id from public.photos where key='hero3')),
  ('slide1',           'Welcome slider 1 (desktop)',        (select id from public.photos where key='interior')),
  ('slide2',           'Welcome slider 2 (desktop)',        (select id from public.photos where key='bar')),
  ('slide3',           'Welcome slider 3 (desktop)',        (select id from public.photos where key='pitches')),
  ('slide4',           'Welcome slider 4 (desktop)',        (select id from public.photos where key='funday')),
  ('slide5',           'Welcome slider 5 (desktop)',        (select id from public.photos where key='floodlit')),
  ('highlight1',       'Highlight card: Room to roam',      (select id from public.photos where key='pitches')),
  ('highlight2',       'Highlight card: Your event, your way', (select id from public.photos where key='fundaycard')),
  ('highlight3',       'Highlight card: A proper bar',      (select id from public.photos where key='bar')),
  ('space.clubhouse',  'Space: The Clubhouse',              (select id from public.photos where key='seating')),
  ('space.balcony',    'Space: The Balcony',                (select id from public.photos where key='hero3')),
  ('space.braai',      'Space: Outdoor Kitchen & Braai',    (select id from public.photos where key='hero1')),
  ('space.marquee',    'Space: Grounds & Marquee',          (select id from public.photos where key='funday')),
  ('space.pitches',    'Space: The Pitches',                (select id from public.photos where key='pitches')),
  ('space.facilities', 'Space: Facilities',                 (select id from public.photos where key='hero2')),
  ('pricing',          'Pricing section photo',             (select id from public.photos where key='bar'))
on conflict (slot) do nothing;

-- ---------- seed: the 10 events (only if the table is empty) ----------
insert into public.events (slug, tag, title, teaser, description, photo_id, sort, visible)
select * from (values
  ('kids',       'School holidays', 'Kids'' parties',                         'Space to run, pitches to play on, a clubhouse for cake and a braai for the grown-ups.', 'Space to run, pitches to play on, a clubhouse for cake and a braai for the grown-ups. Bring an entertainer or a bouncy castle, or ask us about a rugby or touch session for the kids. It''s ideal for school-holiday birthdays.', (select id from public.photos where key='fundaycard'), 1, true),
  ('birthday',   '30th to 70th',    'Milestone birthdays',                    'We''ve celebrated 30ths, 40ths, 50ths and 60ths.', 'We''ve celebrated 30ths, 40ths, 50ths and 60ths. This summer we''re hosting a 70th with a brass band. Use the clubhouse and bar, or go big with a marquee and a stage.', (select id from public.photos where key='interior'), 2, true),
  ('bbq',        'Outdoor kitchen', 'BBQs and cook-outs',                     'Our outdoor kitchen and braai pits make it easy.', 'Our outdoor kitchen and braai pits make it easy. Fire them up for a family day, a team social or an end-of-term party. Bring your own food or your own caterer.', (select id from public.photos where key='hero1'), 3, true),
  ('dinner',     'Marquee',         'Formal dinners',                         'We''ve hosted black-tie dinners in a marquee on the grounds, with seating for up to 150 guests from May to August.', 'We''ve hosted black-tie dinners in a marquee on the grounds, with seating for up to 150 guests from May to August.', (select id from public.photos where key='seating'), 4, true),
  ('wedding',    'Three a year',    'Wedding celebrations',                   'Say “I do” wherever you like, then bring everyone back to ours.', 'Say “I do” wherever you like, then bring everyone back to ours. Hold a marquee on the grounds, a braai feast, speeches on the balcony and dancing in the bar. We host just three weddings a year and the dates go fast, so get in touch at least six months ahead.', (select id from public.photos where key='hero3'), 5, true),
  ('other',      'Stage & balcony', 'Live music and DJs',                     'Bands on an outdoor stage and DJs on the balcony.', 'Bands on an outdoor stage and DJs on the balcony. We''ve done it and it works.', (select id from public.photos where key='bar'), 6, true),
  ('tournament', 'Pitches',         'Tournaments and festivals',              'In July 2025 the Junior Touch Cup brought more than 300 kids to the club, with a barbecue running all day.', 'In July 2025 the Junior Touch Cup brought more than 300 kids to the club, with a barbecue running all day. We''ve hosted mini rugby festivals with over 100 teams, plus 7s competitions. Six changing rooms and plenty of grass make it straightforward.', (select id from public.photos where key='floodlit'), 7, true),
  ('community',  'Community',       'Community days and outdoor cinema',      'Our three outdoor cinema days brought the whole neighbourhood out.', 'Our three outdoor cinema days brought the whole neighbourhood out. Planning a fundraiser, fete or summer screening? Talk to us.', (select id from public.photos where key='funday'), 8, true),
  ('community',  'Big matches',     'Watch parties and international nights', 'Our South African series nights round the braai are a club favourite.', 'Our South African series nights round the braai are a club favourite. They''re great for big matches and cultural celebrations.', (select id from public.photos where key='bigpitch'), 9, true),
  ('corporate',  'Team days',       'Corporate and team days',                'Team BBQs, sports days and summer socials, with a bar, open grass and parking for around 100 cars.', 'Team BBQs, sports days and summer socials, with a bar, open grass and parking for around 100 cars.', (select id from public.photos where key='pitches'), 10, true)
) as v(slug, tag, title, teaser, description, photo_id, sort, visible)
where not exists (select 1 from public.events);

-- ---------- views for the public site (one round-trip each) ----------
create or replace view public.site_events with (security_invoker = true) as
  select e.id, e.slug, e.tag, e.title, e.teaser, e.description, e.sort, p.url as photo_url, p.alt as photo_alt
  from public.events e left join public.photos p on p.id = e.photo_id
  where e.visible order by e.sort, e.created_at;
create or replace view public.site_placements with (security_invoker = true) as
  select pl.slot, p.url, p.alt from public.placements pl join public.photos p on p.id = pl.photo_id;
create or replace view public.site_gallery with (security_invoker = true) as
  select url, caption, alt from public.photos where in_gallery order by sort, created_at;
grant select on public.site_events, public.site_placements, public.site_gallery to anon, authenticated;
