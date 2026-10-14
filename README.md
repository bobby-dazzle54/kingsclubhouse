# King's Clubhouse — kingsclubhouse.co.uk

Single-page venue-hire site for King's Clubhouse (KCS Old Boys RFC, Motspur Park, KT3).
Hosted on **GitHub Pages** from the `main` branch; the custom domain is set by `CNAME`.

## What's here

| Path | What it is |
|---|---|
| `index.html` | The whole site — one liquid-glass page (hero, events deck, spaces, pricing, enquiry form, FAQ, find us) |
| `photos/` | The 11 venue photos (`.webp`) + `og.jpg` share image for link previews |
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
- Spaces → the six `.room` cards in `<section id="spaces">`.
- Pricing, FAQ, Find us → their sections, plain HTML.
- Photo captions for the phone gallery → the `GALLERY` array in the script.

### Mobile behaviour (≤760px)
- Hero fits one screen; the proof points scroll sideways as pills.
- The photo slider is replaced by a tap-to-enlarge grid of all 11 photos (lightbox).
- Spaces show as six photo tiles; tapping one opens the full details in a bottom sheet with "Enquire about this space".
- Long copy is clamped with "Read more"; the enquiry form keeps essentials up front with optional fields behind "Add more details"; FAQ shows 7 then "Show all 19 questions".
- The Google-reviews placeholder is hidden on phones until live reviews are connected.

### Photo notes
No dedicated shots exist yet for the **Outdoor Kitchen & Braai** (currently the summer-evening-outside shot) or **Facilities** (currently the floodlit-match shot). Swap `data-photo` on those cards when real ones are taken; add new photos to `photos/` and the `PHOTOS` map at the top of the body.

## Still to wire up

- **Enquiry form** — currently *preview mode* (shows the thank-you, sends nothing). Set `data-endpoint` on `<form id="enquiryForm">` to a form handler URL (Formspree / FormSubmit / own backend) and enquiries will email the venue inbox. The community sign-up form needs a mailing-list endpoint the same way.
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
