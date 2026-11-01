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
- Typography, header/menu and spacing rules from the 1 Nov 2026 tightening pass → the `<style id="tightcss">` block at the end of the page's CSS (overrides the rules above it; comments give before → after values). The header shows the email as an icon and hides the social icons until real handles exist (the footer keeps them).
- Footer: a quiet **Staff login** link to `/staff/`.
- Photo captions for the phone gallery → the `GALLERY` array in the script.

### Mobile behaviour (≤760px)
- Hero fits one screen; the proof points scroll sideways as pills.
- The photo slider is replaced by a tap-to-enlarge grid of photos: the first 7, then a "See all photos" button (lightbox on every photo).
- Spaces show as photo tiles (Whole Venue full width); tapping one opens the full details in a bottom sheet with "Enquire about this space".
- The calendar shows dots on days with events; tapping a day lists that day's events below.
- Long copy is clamped with "Read more"; the enquiry form keeps essentials up front with optional fields behind "Add more details"; FAQ shows 7 then "Show all 19 questions".
- The Google-reviews placeholder (`.greviews`) is hidden on every size until live reviews are connected.
- The sticky Enquire / Sign-up bar appears once the hero has scrolled past (the hero has the same two buttons).

### Photo notes
No dedicated shot exists yet for the **Outdoor Kitchen & Braai** (currently the summer-evening-outside shot). Swap `data-photo` on those cards when real ones are taken; add new photos to `photos/` and the `PHOTOS` map at the top of the body.

**Because the live site reads placements, events and the gallery from Supabase, a photo change in `index.html` alone is overridden on page load** — change the database too (staff area, or a migration in `supabase/` pasted into the SQL editor, as with `2026-10-26-new-photos.sql`).

Photos added 26 Oct 2026: `nightmatch`, `clubroom`, `marqueeparty`, `marqueedinner`, `oktoberfest`, `cinema`, `watchparty` — hero is now 4 slides, the desktop slider 8.

## Staff area — `kingsclubhouse.co.uk/staff` (CRM + club figures)

Backend: **Supabase** (free tier). `staff/index.html` is a single-file app using the vendored `staff/supabase.js` (supabase-js 2.45.4). The public site reads live content from the same database and falls back to the baked-in content if `config.js` is empty or the database is unreachable. A **Staff login** link sits at the bottom of the public page.

**Tabs:** Dashboard · Inbox (owners) / Team queue (team) · Enquiries (list + drag-and-drop board) · Contacts · Sign-ups · Events · Calendar · Photos · Figures · Settings.

- **Dashboard** — waiting for you, need a reply, open pipeline £, won this year £, win rate, enquiries this month; audience tiles (email sign-ups, WhatsApp members, Facebook, Instagram); charts for the last 12 months: enquiries per month (won / lost / declined / still open, number ↔ value £), **bar sales**, **paying members**, and the four audience figures as small multiples; needs-a-reply list; enquiries by event type.
- **First refusal** — every new enquiry (website form or email to info@) is visible to owners only until an owner chooses *Reply myself*, *Send to team* (everyone is told) or *Not an enquiry*. Team members see the team queue and *Pick up* what they want; owners can also assign to one person. Enforced by row-level security, not just hidden.
- **Pipeline** — New → Contacted → Quoted → Won / Lost / Declined, £ value, reason when lost, labels, a timeline of the form, notes, emails in and out, and stage changes. Reply from the enquiry with a template; sent from info@ when n8n is connected, otherwise it opens your own mail app and logs the reply.
- **Figures** — one row per month: bar sales £, paying members, WhatsApp members, Facebook and Instagram followers (email sign-ups count themselves from the website). Each box saves itself; the dashboard reads from here.

| File | What it is |
|---|---|
| `config.js` | Project URL + **publishable** key (public by design). Never a secret / service_role key. |
| `supabase/schema.sql` | Base tables, row-level security, storage bucket, seed data. Paste into the Supabase SQL editor once; safe to re-run. |
| `supabase/2026-10-26-*.sql` | Calendar / spaces / new photos (already run). |
| `supabase/2026-11-01-crm-and-figures.sql` | **CRM + figures**: `staff`, enquiry triage/pipeline columns, `enquiry_activity`, `notifications`, `crm_labels`, `crm_templates`, `crm_settings`, `email_outbox`, `club_metrics`, the `crm_*` functions and policies. Safe to re-run. The staff area shows a banner until this has been run. |
| `supabase/n8n-alerts-workflow.json` | n8n: "new enquiry / sign-up" email alert to info@ (optional once the CRM is live — the app shows new enquiries in the Inbox and the bell). |
| `supabase/n8n-crm-send.json` | n8n: sends replies written in the app from info@ (Gmail), in the original thread when there is one, and reports back with `crm_mark_sent` / `crm_mark_failed`. |
| `supabase/n8n-crm-inbox.json` | n8n: every minute, files new emails in info@ on the right enquiry (`crm_ingest_email`) or opens a new one for the owners. |

**Setting it up (once)**
1. Supabase → New project (London, free). Project Settings → API Keys → copy the **Project URL** and the **publishable** key (`sb_publishable_…`) into `config.js`, push.
2. SQL Editor → paste `supabase/schema.sql` → Run. Then paste `supabase/2026-11-01-crm-and-figures.sql` → Run. The first login created becomes the owner; to pick explicitly, run `select public.crm_set_owner('you@…');`.
3. Authentication → Providers → Email: turn **off** "Allow new users to sign up" (only staff you add can log in). Authentication → URL configuration → Site URL `https://kingsclubhouse.co.uk`, add redirect `https://kingsclubhouse.co.uk/staff/`.
4. Authentication → Users → **Add user** for each staff member (email + password). They appear in Settings → Team as "Team"; owners can promote them. They can reset their password from the login page.
5. Email in the app (optional): Database → Extensions → enable **pg_net**. n8n → import `supabase/n8n-crm-send.json` and `supabase/n8n-crm-inbox.json`; in each one's *Settings* code node paste the shared secret (staff area → Settings → Email) and the publishable key; pick the Gmail credential for info@; activate both. Copy the send workflow's **production** webhook URL into Settings → Email → *Send webhook URL*. Until this is done, replies open in your own mail app and are still logged.

**How the pieces connect**
- Visitors (anon key) can read events/photos/placements and insert one enquiry or sign-up — nothing else.
- Staff are the rows in `staff` (created automatically for every login). Owners see every enquiry; team see those sent to the team. The database refuses a team member changing who an enquiry is with, or attaching an email thread to it.
- Replies written in the app go into `email_outbox`; a trigger hands them to the n8n webhook via `pg_net`; n8n sends from info@ and calls back. Incoming email is matched by Gmail thread, then by an open enquiry from the same address in the last 120 days, otherwise a new enquiry is opened for the owners.
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
