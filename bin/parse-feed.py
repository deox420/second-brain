import os, sys, re, html, hashlib, unicodedata, datetime as dt
from email.utils import parsedate_to_datetime
import xml.etree.ElementTree as ET

date_str = sys.argv[1]
feed = os.environ.get("FEED_NAME", "fuente")
raw_dir = os.environ["RAW_DIR"]
data = sys.stdin.read()

def strip_ns(tag): return tag.split('}')[-1].lower()
def text(el): return (el.text or "").strip() if el is not None else ""

try:
    root = ET.fromstring(data)
except ET.ParseError:
    sys.exit(0)

items = [e for e in root.iter() if strip_ns(e.tag) in ("item", "entry")]
now = dt.datetime.now(dt.timezone.utc)
window = dt.timedelta(hours=28)
written = 0

def parse_date(s):
    s = s.strip()
    try:
        d = parsedate_to_datetime(s)
        if d.tzinfo is None: d = d.replace(tzinfo=dt.timezone.utc)
        return d
    except Exception: pass
    for fmt in ("%Y-%m-%dT%H:%M:%S.%f%z","%Y-%m-%dT%H:%M:%S%z","%Y-%m-%dT%H:%M:%SZ","%Y-%m-%d"):
        try:
            d = dt.datetime.strptime(s, fmt)
            if d.tzinfo is None: d = d.replace(tzinfo=dt.timezone.utc)
            return d
        except ValueError: continue
    return None

def slugify(t):
    t = unicodedata.normalize("NFKD", t).encode("ascii","ignore").decode()
    return re.sub(r"[^a-z0-9]+","-",t.lower()).strip("-")[:60] or "item"

for it in items:
    title = link = pub = desc = ""
    alt_link = ""
    for ch in it:
        t = strip_ns(ch.tag)
        if t == "title" and not title: title = text(ch)
        elif t == "link":
            href = text(ch) or ch.attrib.get("href","")
            rel = ch.attrib.get("rel","alternate")
            if rel == "alternate" and not alt_link: alt_link = href
            if not link: link = href
        elif t in ("pubdate","published","updated","date") and not pub: pub = text(ch)
        elif t in ("description","summary","content") and not desc: desc = text(ch)
    link = alt_link or link
    if not title: continue
    d = parse_date(pub) if pub else None
    if d is not None and (now - d) > window: continue
    desc = re.sub(r"<[^>]+>"," ",html.unescape(desc))
    desc = re.sub(r"\s+"," ",desc).strip()[:1200]
    h = hashlib.sha1((link or title).encode()).hexdigest()[:8]
    path = os.path.join(raw_dir, f"{slugify(title)}-{h}.md")
    if os.path.exists(path): continue
    safe_title = title.replace("\\","\\\\").replace('"','\\"')
    with open(path,"w",encoding="utf-8") as f:
        f.write("---\n")
        f.write(f'titulo: "{safe_title}"\n')
        f.write(f'fuente: "{feed}"\n')
        f.write(f'url: "{link}"\n')
        f.write(f"fecha: {date_str}\n")
        f.write(f'publicado: "{pub}"\n')
        f.write("---\n\n")
        f.write(f"# {title}\n\n{desc}\n")
    written += 1

print(f"    {written} items")
