# King's Clubhouse — kingsclubhouse.co.uk

Single-page venue-hire site for King's Clubhouse (KCS Old Boys RFC, Motspur Park, KT3).
Hosted on **GitHub Pages** from the `main` branch; the custom domain is set by `CNAME`.

## What's here

| Path | What it is |
|---|---|
| `index.html` | The whole site — one liquid-glass page (hero, events deck, spaces, enquiry form, what's on calendar, sign-up, FAQ, find us) |
| `photos/` | The 18 venue photos (`.webp`) + `og.jpg` share image for link previews |
| `404.html` | Not-found page, points back to `/` |
| `CNAME` | `kingsclubhouse.co.uk` — tells GitHub Pages which domain serves the site |
| `favicon.svg` / `favicon.png` / `apple-touch-icon.png` | Browser-tab + home-screen icons |
| `robots.txt` / `sitemap.xml` | Search-engine basics |
| `_build/deploy.py` | Turns the self-contained build (`kings-kt3-glass-homepage.html`) into this folder |

## Making a change

**`index.html` in this repo is the source of truth** (since the mobile pass on 14 Oct 2026). Edit it directly — on GitHub (pencil icon) or locally — then commit and push. GitHub Pages redeploys within about a minute.

Do **not** re-run `_build/build_onepage.py` / `_build/deploy.py` from the project folder: they predate the mobile pass and would overwrite it. If you need the self-contained single-file preview again, rebuild it *from* this `index.html`, not the other way round.

Where things live in `index.html`:
- Event cards → the `EVENTS` array in the script at the bottom (title, teaser, full text, photo key).
- Spaces → the five `.room` cards in `<section id="spaces">` (Clubhouse, Outdoor Kitchen & Braai, Grounds & Marquee, Pitches, and the wide `.room.whole` Whole Venue card).
- What's on → `<section id="calendar">`; dates come from Supabase (`site_calendar`), edited in the staff area → Calendar.
- FAQ, Find us → their sections, plain HTML.
- Contact email: **info@kingsclubhouse.co.uk** (header, hero, enquiry panel, Find us, footer, mobile menu, 404).
- Photo captions for the phone gallery → the `GALLERY` array in the script.

### Mobile behaviour (≤760px)
- Hero fits one screen; the proof points scroll sideways as pills.
- The photo slider is replaced by a tap-to-enlarge grid of all 18 photos (lightbox).
- Spaces show as photo tiles (Whole Venue full width); tapping one opens the full details in a bottom sheet with "Enquire about this space".
- The calendar shows dots on days with events; tapping a day lists that day's events below.
- Long copy is clamped with "Read more"; the enquiry form keeps essentials up front with optional fields behind "Add more details"; FAQ shows 7 then "Show all 19 questions".
- The Google-reviews placeholder is hidden on phones until live reviews are connected.

### Photo notes
No dedicated shot exists yet for the **Outdoor Kitchen & Braai** (currently the summer-evening-outside shot). Swap `data-photo` on those cards when real ones are taken; add new photos to `photos/` and the `PHOTOS` map at the top of the body.

**Because the live site reads placements, events and the gallery from Supabase, a photo change in `index.html` alone is overridden on page load** — change the database too (staff area, or a migration in `supabase/` pasted into the SQL editor, as with `2026-10-26-new-photos.sql`).

Photos added 26 Oct 2026: `nightmatch`, `clubroom`, `marqueeparty`, `marqueedinner`, `oktoberfest`, `cinema`, `watchparty` — hero is now 4 slides, the desktop slider 8.

## Staff area — `kingsclubhouse.co.uk/staff`

Backend: **Supabase** (free tier). `staff/index.html` is a single-file admin (login · Enquiries · Sign-ups · Events · Calendar · Photos + placements) using the vendored `staff/supabase.js` (supabase-js 2.45.4). The public site reads live content from the same database and falls back to the baked-in content if `config.js` is empty or the database is unreachable.

| File | What it is |
|---|---|
| `config.js` | Project URL + **publishable** key (public by design). Never a secret / service_role key. |
| `supabase/schema.sql` | Tables, row-level security, storage bucket, seed data. Paste into the Supabase SQL editor once; safe to re-run. |
| `supabase/n8n-alerts-workflow.json` | Import into n8n for the "new enquiry / sign-up" email (sends to info@kingsclubhouse.co.uk). |

**Setting it up (once)**
1. Supabase → New project (London, free). Project Settings → API Keys → copy the **Project URL** and the **publishable** key (`sb_publishable_…`) into `config.js`, push.
2. SQL Editor → paste `supabase/schema.sql` → Run.
3. Authentication → Providers → Email: turn **off** "Allow new users to sign up" (only staff you add can log in). Authentication → URL configuration → Site URL `https://kingsclubhouse.co.uk`, add redirect `https://kingsclubhouse.co.uk/staff/`.
4. Authentication → Users → **Add user** for each staff member (email + password). They can reset it from the login page.
5. Email alerts: n8n → import `supabase/n8n-alerts-workflow.json`, set the Gmail credential and the venue address in the last node, activate, copy the **production** webhook URL. Supabase → Integrations → Database Webhooks → create one for `enquiries` (INSERT) and one for `signups` (INSERT) pointing at that URL.

**How the pieces connect**
- Visitors (anon key) can read events/photos/placements and insert one enquiry or sign-up — nothing else (row-level security in `schema.sql`).
- Staff (any signed-in user) can do everything. Public sign-ups are disabled, so "signed in" means "staff".
- Uploaded photos are resized to 1600px in the browser and stored in the public `photos` bucket; built-in photos stay in `photos/` in this repo.
- Changing an event, placement or photo in the staff area is live on the site on the next page load — no deploy needed.

## Still to wire up

- **Enquiry + sign-up forms** — store to Supabase once `config.js` is filled (see Staff area above). Until then they're in *preview mode* (thank-you only, nothing sent).
- **Social links + WhatsApp invite** — `href="#"` placeholders until the handles/link are supplied.
- **Google reviews strip** — placeholder cards until connected to live reviews (Places API).

## Domain / DNS (GitHub Pages)

At the registrar for `kingsclubhouse.co.uk`:

| Type | Host | Value |
|---|---|---|
| A | `@` | `185.199.108.153` |
| A | `@` | `185.199.109.153` |
| A | `@` | `185.199.110.153` |
| A | `@` | `185.199.111.153` |
| CNAME | `www` | `bobby-dazzle54.github.io` |

Then in the repo: Settings → Pages → Custom domain `kingsclubhouse.co.uk` → tick **Enforce HTTPS** once the DNS check passes.
