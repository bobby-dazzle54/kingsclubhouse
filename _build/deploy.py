#!/usr/bin/env python3
"""King's Clubhouse — turn the self-contained homepage into the deployable site folder.

    python3 _build/deploy.py  [path/to/kings-kt3-glass-homepage.html]

Reads the built single-page file (default: ../kings-kt3-glass-homepage.html, i.e. the project folder's
output from build_onepage.py), then writes into this repo:
  index.html        the same page, but with the 11 embedded photos swapped for photos/<key>.webp
  photos/*.webp     the photos, written once each (browser-cacheable; index.html drops from ~2.7 MB to ~100 KB)
  photos/og.jpg     1200x630 share image (hero1) for Facebook / WhatsApp / iMessage link previews
  favicon.svg / favicon.png / apple-touch-icon.png
  sitemap.xml
Everything else in the repo (CNAME, 404.html, robots.txt, README.md) is static and left alone.

Pipeline for a copy change:  edit _build/build_onepage.py → python3 _build/build_onepage.py →
python3 _build/deploy.py → git commit → git push   (GitHub Pages redeploys in ~1 minute).
"""
import base64, json, os, pathlib, re, sys

HERE = pathlib.Path(__file__).resolve().parent      # <repo>/_build
REPO = HERE.parent                                  # <repo>
SITE_URL = 'https://kingsclubhouse.co.uk'

src = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(
    os.environ.get('SRC') or REPO.parent / 'kings-kt3-glass-homepage.html')
if not src.exists():
    sys.exit(f'Source page not found: {src}\nPass its path: python3 _build/deploy.py /path/to/kings-kt3-glass-homepage.html')
page = src.read_text()

# ---- 1. embedded photos -> files ----------------------------------------------------------------
m = re.search(r'<script>var PHOTOS=(\{.*?\});</script>', page, re.S)
if not m:
    sys.exit('PHOTOS map not found in the source page')
photos = json.loads(m.group(1))
(REPO / 'photos').mkdir(exist_ok=True)
paths = {}
for key, uri in photos.items():
    if uri.startswith('data:'):
        mime, b64 = uri[5:].split(';base64,', 1)
        ext = {'image/webp': 'webp', 'image/jpeg': 'jpg', 'image/png': 'png'}[mime]
        out = REPO / 'photos' / f'{key}.{ext}'
        out.write_bytes(base64.b64decode(b64))
        paths[key] = f'photos/{key}.{ext}'
    else:
        paths[key] = uri          # already a path (deploy.py run twice)
page = page.replace(m.group(0), '<script>var PHOTOS=' + json.dumps(paths) + ';</script>')
# any stray inline data URIs left in CSS/markup (none expected) -> leave as-is but report
stray = len(re.findall(r'data:image/[a-z]+;base64,', page))

# ---- 2. head: canonical, icons, Open Graph -------------------------------------------------------
title = re.search(r'<title>(.*?)</title>', page).group(1)
desc = re.search(r'<meta name="description" content="(.*?)">', page).group(1)
head_extra = f'''<link rel="canonical" href="{SITE_URL}/">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="icon" href="/favicon.png" type="image/png" sizes="64x64">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<meta property="og:type" content="website">
<meta property="og:site_name" content="King's Clubhouse">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{desc}">
<meta property="og:url" content="{SITE_URL}/">
<meta property="og:image" content="{SITE_URL}/photos/og.jpg">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:locale" content="en_GB">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{title}">
<meta name="twitter:description" content="{desc}">
<meta name="twitter:image" content="{SITE_URL}/photos/og.jpg">'''
page = re.sub(r'\n<link rel="canonical".*?<meta name="twitter:image"[^>]*>', '', page, flags=re.S)  # idempotent
page = page.replace('<link rel="preconnect" href="https://fonts.googleapis.com">',
                    head_extra + '\n<link rel="preconnect" href="https://fonts.googleapis.com">', 1)

(REPO / 'index.html').write_text(page)

# ---- 3. share image + icons --------------------------------------------------------------------
from PIL import Image, ImageDraw, ImageFont
hero = Image.open(REPO / 'photos' / paths['hero1'].split('/')[-1]).convert('RGB')
W, H = 1200, 630
scale = max(W / hero.width, H / hero.height)
hero = hero.resize((round(hero.width * scale), round(hero.height * scale)), Image.LANCZOS)
left, top = (hero.width - W) // 2, (hero.height - H) // 2
hero.crop((left, top, left + W, top + H)).save(REPO / 'photos' / 'og.jpg', quality=86, optimize=True, progressive=True)

DEEP, MILK = '#3C4A33', '#FAFAF5'
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
<rect width="64" height="64" rx="14" fill="{DEEP}"/>
<text x="32" y="47" text-anchor="middle" font-family="'DM Serif Display','Iowan Old Style',Georgia,'Times New Roman',serif" font-size="44" fill="{MILK}">K</text>
</svg>
'''
(REPO / 'favicon.svg').write_text(svg)
font_path = next((p for p in ['/usr/share/fonts/truetype/baskerville/GFSBaskerville.otf',
                              '/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf'] if os.path.exists(p)), None)
def icon(size, out):
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, size - 1, size - 1), radius=round(size * 0.22), fill=DEEP)
    if font_path:
        f = ImageFont.truetype(font_path, round(size * 0.72))
        bb = d.textbbox((0, 0), 'K', font=f)
        d.text(((size - (bb[2] - bb[0])) / 2 - bb[0], (size - (bb[3] - bb[1])) / 2 - bb[1]), 'K', font=f, fill=MILK)
    im.save(out)
icon(64, REPO / 'favicon.png')
icon(180, REPO / 'apple-touch-icon.png')

# ---- 4. sitemap --------------------------------------------------------------------------------
(REPO / 'sitemap.xml').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>{SITE_URL}/</loc><changefreq>monthly</changefreq><priority>1.0</priority></url>
</urlset>
''')

kb = (REPO / 'index.html').stat().st_size / 1024
print(f'index.html {kb:,.0f} KB · {len(paths)} photos in photos/ · og.jpg + icons + sitemap written'
      + (f' · WARNING {stray} inline data URIs still in page' if stray else ''))
