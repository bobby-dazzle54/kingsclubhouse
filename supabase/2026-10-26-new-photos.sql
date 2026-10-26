-- King's Clubhouse · 26 Oct 2026 · weave in 7 new photos
-- Paste into Supabase → SQL Editor → New query → Run. Safe to re-run.
-- Needs the matching push to GitHub first (the files live in /photos/ in the repo).

begin;

-- 1. the new photos (in the library + phone gallery)
insert into public.photos (key, url, caption, alt, in_gallery, sort) values
  ('nightmatch',    '/photos/nightmatch.webp',    'A floodlit evening match',          'Floodlit evening match with spectators along the rail', true, 18),
  ('clubroom',      '/photos/clubroom.webp',      'The clubhouse, set for a function', 'The clubhouse function room with round tables, sofas and the honours board', true, 8),
  ('marqueeparty',  '/photos/marqueeparty.webp',  'A live band in the marquee',        'Guests dancing to a live band in a marquee', true, 2),
  ('marqueedinner', '/photos/marqueedinner.webp', 'Summer dinner in the marquee',      'Guests at round tables at a summer dinner in a marquee', true, 5),
  ('oktoberfest',   '/photos/oktoberfest.webp',   'Oktoberfest night',                 'Guests in lederhosen and dirndls at an Oktoberfest party', true, 11),
  ('cinema',        '/photos/cinema.webp',        'Outdoor cinema at sunset',          'Families on blankets and deckchairs watching an outdoor cinema screen at sunset', true, 4),
  ('watchparty',    '/photos/watchparty.webp',    'Big match on the big screen',       'Crowd watching a rugby match on a big screen outdoors', true, 10)
on conflict (key) do nothing;

-- 2. gallery order (phones: one wide tile, then rows of three; near-identical crops kept apart)
update public.photos ph set sort = v.sort
from (values
  ('hero1',1),('marqueeparty',2),('interior',3),('cinema',4),('marqueedinner',5),('floodlit',6),
  ('pitches',7),('clubroom',8),('funday',9),('watchparty',10),('oktoberfest',11),('bigpitch',12),
  ('hero3',13),('hero2',14),('fundaycard',15),('bar',16),('seating',17),('nightmatch',18)
) as v(key, sort)
where ph.key = v.key;

-- 3. new slots: 4th hero slide, desktop slider 6–8
insert into public.placements (slot, label, photo_id) values
  ('hero4',  'Hero slide 4',                (select id from public.photos where key='hero3')),
  ('slide6', 'Welcome slider 6 (desktop)',  (select id from public.photos where key='watchparty')),
  ('slide7', 'Welcome slider 7 (desktop)',  (select id from public.photos where key='pitches')),
  ('slide8', 'Welcome slider 8 (desktop)',  (select id from public.photos where key='marqueeparty'))
on conflict (slot) do nothing;

-- 4. re-point existing slots
update public.placements pl set photo_id = (select id from public.photos where key = v.key)
from (values
  ('hero2','marqueeparty'),('hero3','nightmatch'),
  ('slide1','clubroom'),('slide2','marqueedinner'),('slide3','bar'),('slide4','cinema'),('slide5','oktoberfest'),
  ('space.clubhouse','clubroom'),('space.marquee','marqueedinner')
) as v(slot, key)
where pl.slot = v.slot;

-- 5. event cards
update public.events e set photo_id = (select id from public.photos where key = v.key), updated_at = now()
from (values
  ('Milestone birthdays','oktoberfest'),
  ('Formal dinners','marqueedinner'),
  ('Live music and DJs','marqueeparty'),
  ('Community days and outdoor cinema','cinema'),
  ('Watch parties and international nights','watchparty')
) as v(title, key)
where e.title = v.title;

commit;

-- check: should return 18 / 22 / 5
select (select count(*) from public.photos where in_gallery) as gallery_photos,
       (select count(*) from public.placements) as slots,
       (select count(*) from public.events e join public.photos p on p.id = e.photo_id
         where p.key in ('oktoberfest','marqueedinner','marqueeparty','cinema','watchparty')) as events_with_new_photos;
