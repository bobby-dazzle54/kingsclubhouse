# King's Clubhouse — kingsclubhouse.co.uk

Single-page venue-hire site for King's Clubhouse (KCS Old Boys RFC, Motspur Park, KT3).
Hosted on **GitHub Pages** from the `main` branch; the custom domain is set by `CNAME`.

## What's here

| Path | What it is |
|---|---|
| `index.html` | The whole site — one liquid-glass page (hero, events deck, spaces, enquiry form, what's on calendar, sign-up, FAQ, find us) |
| `config.js` | Where the site reads and posts: `API_BASE` (mapmyshift) + the Supabase fallback for the switch-over |
| `staff/index.html` | Sends anyone opening the old staff area to mapmyshift |
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
- What's on → `<section id="calendar">`; dates come from mapmyshift (`site_calendar`), edited in the King's Clubhouse workspace → What's on.
- FAQ, Find us → their sections, plain HTML.
- Contact email: **info@kingsclubhouse.co.uk** (header, hero, enquiry panel, Find us, footer, mobile menu, 404).
- Typography, header/menu and spacing rules from the 1 Nov 2026 tightening pass → the `<style id="tightcss">` block at the end of the page's CSS (overrides the rules above it; comments give before → after values). The header shows the email as an icon and hides the social icons until real handles exist (the footer keeps them).
- Footer: a quiet **Staff login** link to the King's Clubhouse workspace on mapmyshift.
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

**Because the live site reads placements, events and the gallery from mapmyshift, a photo change in `index.html` alone is overridden on page load** — change it in mapmyshift too (King's Clubhouse → Website → Photos / Photo spots). New built-in photos: add the file to `photos/` here, then upload the same photo in mapmyshift (or just upload it there — uploads are served by mapmyshift).

Photos added 26 Oct 2026: `nightmatch`, `clubroom`, `marqueeparty`, `marqueedinner`, `oktoberfest`, `cinema`, `watchparty` — hero is now 4 slides, the desktop slider 8.

## Staff area — the King's Clubhouse workspace in mapmyshift (since 9 Nov 2026)

The backend moved from Supabase to **mapmyshift.com → King's Clubhouse** (`https://mapmyshift.com/w/kings-clubhouse`, or `mapmyshift.com/kc`). The footer **Staff login** link and `kingsclubhouse.co.uk/staff/` both go there. Staff sign in with their mapmyshift login; the owner adds people under **Members** (Owner/Admin get first refusal and Settings; Manager = the team, sees money; Staff = the team without money; Viewer = read-only).

**What lives there:** Dashboard (the KPIs, enquiries per month won/lost/declined/open by number or £, 12-month bar sales and paying members, email sign-ups / WhatsApp / Facebook / Instagram) · Inbox (first refusal) / Team queue · Bookings (list + drag-and-drop board, the enquiry drawer: stage, £ value, labels, files, notes, replies from info@ or your own mail app, the timeline) · Contacts · Sign-ups · What's on · Website (event cards, photos, photo spots) · Figures (one row per month; CSV in and out) · Settings (the website, email, labels, reply templates, the import from Supabase).

**How the site talks to it** — `config.js` → `API_BASE` = `https://mapmyshift.com/api/site/kings-clubhouse`. `site.js` reads `site_placements`, `site_events`, `site_gallery` and `site_calendar` from there (the same paths and JSON the Supabase views had) and posts the two forms to `/enquiries` and `/signups` as JSON in a `text/plain` body (no CORS pre-flight). mapmyshift only accepts form posts from the addresses in its Settings → *Websites allowed to send enquiries* (`https://kingsclubhouse.co.uk` and `https://www.kingsclubhouse.co.uk`). Both forms carry a hidden `company_website` field: anything typed in it is a bot, and is thanked and dropped. One address posting over and over is slowed down.

**The switch-over fallback** — `config.js` still has the two Supabase lines. If mapmyshift can't be reached (or answers 404/5xx), a form falls back to Supabase and the page content falls back to Supabase, then to what's baked into `index.html`. mapmyshift → Settings → **Bring everything across** sweeps anything that landed in Supabase. **After a week live on mapmyshift, blank both `SUPABASE_` lines** — Supabase's free tier pauses an idle project anyway.

**Go-live order** (mapmyshift first, then this site):
1. Merge the mapmyshift pull request — Railway deploys it. `https://mapmyshift.com/w/kings-clubhouse` opens.
2. mapmyshift → King's Clubhouse → Settings → **Bring everything across from the old staff area**: sign in with an owner's old staff login → **Preview** → **Bring it across**.
3. Merge this repo's pull request — GitHub Pages deploys it in about a minute.
4. Run **Bring it across** once more: it adds only what arrived in between.
5. Email (optional): Settings → Email → connect Gmail as info@ (or point the n8n workflows at mapmyshift — the addresses and the shared secret are on that card).

`supabase/` stays as the record of the old schema and n8n workflows; nothing reads it any more.

## Still to wire up

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
