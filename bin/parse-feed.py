#!/usr/bin/env python3
# parse-feed.py — parser RSS/Atom del radar de noticias (segundo cerebro).
#
# Lee el XML de un feed por stdin y escribe un archivo Markdown por item
# reciente (ventana ~28h) en RAW_DIR. Lo invoca bin/cron-news-ingest.sh,
# pero es testeable de forma aislada (ver tests/test_parse_feed.py).
#
# Variables de entorno:
#   FEED_NAME  nombre de la fuente (etiqueta que verá la nota diaria)
#   RAW_DIR    carpeta destino de los items crudos (.raw/news/YYYY-MM-DD)
#   SEEN_FILE  (opcional) registro persistente "fecha hash" de items ya
#              recogidos; evita que la ventana de 28h repita un item entre
#              días consecutivos (B6). Se poda a 7 días.
# Argumento posicional: fecha del lote, YYYY-MM-DD.
#
# Salida (una línea, la recoge el log del cron):
#   "    N nuevos (D ya vistos, A antiguos)"

import os, sys, re, html, hashlib, unicodedata, datetime as dt
from email.utils import parsedate_to_datetime
import xml.etree.ElementTree as ET

date_str = sys.argv[1]
feed = os.environ.get("FEED_NAME", "fuente")
raw_dir = os.environ["RAW_DIR"]
seen_file = os.environ.get("SEEN_FILE", "")

def strip_ns(tag): return tag.split('}')[-1].lower()
def text(el): return (el.text or "").strip() if el is not None else ""

data = sys.stdin.read()
try:
    root = ET.fromstring(data)
except ET.ParseError:
    print("    0 nuevos (XML inválido, feed omitido)")
    sys.exit(0)

# ── Registro persistente de items ya vistos (B6) ─────────────────────────────
batch_date = dt.date.fromisoformat(date_str)
seen = {}  # hash -> fecha (str)
if seen_file and os.path.exists(seen_file):
    with open(seen_file, encoding="utf-8") as fh:
        for line in fh:
            parts = line.split()
            if len(parts) == 2:
                d, h = parts
                try:
                    if (batch_date - dt.date.fromisoformat(d)).days <= 7:
                        seen[h] = d
                except ValueError:
                    continue

items = [e for e in root.iter() if strip_ns(e.tag) in ("item", "entry")]
now = dt.datetime.now(dt.timezone.utc)
window = dt.timedelta(hours=28)
written = dup = old = 0

def parse_date(s):
    s = s.strip()
    try:
        d = parsedate_to_datetime(s)  # RFC 2822, zonas textuales incluidas (B4)
        if d.tzinfo is None: d = d.replace(tzinfo=dt.timezone.utc)
        return d
    except Exception: pass
    for fmt in ("%Y-%m-%dT%H:%M:%S.%f%z", "%Y-%m-%dT%H:%M:%S%z",
                "%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%d"):
        try:
            d = dt.datetime.strptime(s, fmt)
            if d.tzinfo is None: d = d.replace(tzinfo=dt.timezone.utc)
            return d
        except ValueError: continue
    return None

def slugify(t):
    # NFKD: "España" → "espana", no "espa-a" (B2; CLAUDE.md §3: kebab sin tildes)
    t = unicodedata.normalize("NFKD", t).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", t.lower()).strip("-")[:60] or "item"

def yaml_str(s):
    # Frontmatter robusto: todo campo de texto entrecomillado y escapado (B3)
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

new_hashes = []
for it in items:
    title = link = pub = desc = ""
    alt_link = ""
    for ch in it:
        t = strip_ns(ch.tag)
        if t == "title" and not title: title = text(ch)
        elif t == "link":
            href = text(ch) or ch.attrib.get("href", "")
            rel = ch.attrib.get("rel", "alternate")
            # Atom: preferir rel="alternate" (la URL del artículo, no la del feed) (B5)
            if rel == "alternate" and not alt_link: alt_link = href
            if not link: link = href
        elif t in ("pubdate", "published", "updated", "date") and not pub: pub = text(ch)
        elif t in ("description", "summary", "content") and not desc: desc = text(ch)
    link = alt_link or link
    if not title:
        continue
    d = parse_date(pub) if pub else None
    if d is not None and (now - d) > window:
        old += 1
        continue
    h = hashlib.sha1((link or title).encode()).hexdigest()[:8]
    path = os.path.join(raw_dir, f"{slugify(title)}-{h}.md")
    if h in seen or os.path.exists(path):
        dup += 1
        continue
    desc = re.sub(r"<[^>]+>", " ", html.unescape(desc))
    desc = re.sub(r"\s+", " ", desc).strip()[:1200]
    with open(path, "w", encoding="utf-8") as f:
        f.write("---\n")
        f.write(f"titulo: {yaml_str(title)}\n")
        f.write(f"fuente: {yaml_str(feed)}\n")
        f.write(f"url: {yaml_str(link)}\n")
        f.write(f"fecha: {date_str}\n")
        f.write(f"publicado: {yaml_str(pub)}\n")
        f.write("---\n\n")
        f.write(f"# {title}\n\n{desc}\n")
    written += 1
    new_hashes.append(h)
    seen[h] = date_str

# Reescritura podada del registro (entradas de ≤7 días + las nuevas).
if seen_file and seen:
    with open(seen_file, "w", encoding="utf-8") as fh:
        for h, d in sorted(seen.items(), key=lambda kv: (kv[1], kv[0])):
            fh.write(f"{d} {h}\n")

print(f"    {written} nuevos ({dup} ya vistos, {old} antiguos)")
