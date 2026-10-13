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

The copy lives in `_build/build_onepage.py` in the **project folder** (not this repo). To change wording, prices, FAQs, events:

```bash
cd "~/Documents/Claude/Projects/The Clubhouse KT16"
python3 _build/build_onepage.py            # rebuilds kings-kt3-glass-homepage.html (self-contained preview)
cd kingsclubhouse-site                     # this repo, cloned inside the project folder
python3 _build/deploy.py ../kings-kt3-glass-homepage.html   # rewrites index.html + photos/
git add -A && git commit -m "Update copy" && git push
```

GitHub Pages redeploys within about a minute of each push. Quick one-word fixes can also be made directly in `index.html` on GitHub (pencil icon) — just mirror them in `build_onepage.py` later so they aren't lost on the next rebuild.

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
