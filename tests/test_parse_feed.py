"""Tests de bin/parse-feed.py (parser RSS/Atom del cron de noticias).

Cubren los bugs históricos B1-B6: stdin por pipe, slugs con tildes, frontmatter
YAML entrecomillado, fechas RFC 2822 / ISO 8601, link rel=alternate en Atom y
deduplicación persistente entre días (SEEN_FILE).
"""
import datetime as dt
import os
import subprocess
import sys
from email.utils import format_datetime
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PARSER = REPO / "bin" / "parse-feed.py"


def run_parser(xml, raw_dir, date_str=None, feed="Test", seen_file=None):
    env = dict(os.environ, FEED_NAME=feed, RAW_DIR=str(raw_dir))
    if seen_file is not None:
        env["SEEN_FILE"] = str(seen_file)
    else:
        env.pop("SEEN_FILE", None)
    if date_str is None:
        date_str = dt.date.today().isoformat()
    proc = subprocess.run(
        [sys.executable, str(PARSER), date_str],
        input=xml, capture_output=True, text=True, env=env,
    )
    assert proc.returncode == 0, proc.stderr
    return proc.stdout


def now_utc():
    return dt.datetime.now(dt.timezone.utc)


def rss_feed(items):
    body = "".join(items)
    return ('<?xml version="1.0" encoding="UTF-8"?>'
            f'<rss version="2.0"><channel><title>t</title>{body}</channel></rss>')


def rss_item(title, link, pub, desc="descripción"):
    return (f"<item><title>{title}</title><link>{link}</link>"
            f"<pubDate>{pub}</pubDate><description>{desc}</description></item>")


def test_rss_item_fresco_se_escribe(tmp_path):
    pub = format_datetime(now_utc() - dt.timedelta(hours=2))
    out = run_parser(rss_feed([rss_item("Titular fresco", "https://x.es/a", pub)]), tmp_path)
    assert "nuevos=1" in out
    assert len(list(tmp_path.glob("*.md"))) == 1


def test_item_antiguo_se_descarta(tmp_path):
    pub = format_datetime(now_utc() - dt.timedelta(hours=40))
    out = run_parser(rss_feed([rss_item("Viejo", "https://x.es/v", pub)]), tmp_path)
    assert "nuevos=0" in out and "antiguos=1" in out
    assert list(tmp_path.glob("*.md")) == []


def test_slug_con_tildes_y_enes(tmp_path):
    pub = format_datetime(now_utc())
    run_parser(rss_feed([rss_item("España: año de innovación", "https://x.es/e", pub)]), tmp_path)
    (f,) = tmp_path.glob("*.md")
    assert f.name.startswith("espana-ano-de-innovacion-")


def test_frontmatter_yaml_valido_con_comillas(tmp_path):
    pub = format_datetime(now_utc())
    title = 'El "plan B": ¿qué pasa ahora?'
    run_parser(rss_feed([rss_item(title.replace('"', "&quot;"), "https://x.es/q", pub)]), tmp_path)
    (f,) = tmp_path.glob("*.md")
    text = f.read_text(encoding="utf-8")
    assert 'titulo: "El \\"plan B\\": ¿qué pasa ahora?"' in text
    assert 'url: "https://x.es/q"' in text


def test_atom_prefiere_link_alternate(tmp_path):
    iso = (now_utc() - dt.timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%S.500+0000")
    atom = ('<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom">'
            "<entry><title>Entrada Atom</title>"
            '<link rel="self" href="https://feed.example/self.xml"/>'
            '<link rel="alternate" href="https://x.es/articulo"/>'
            f"<published>{iso}</published><summary>s</summary></entry></feed>")
    out = run_parser(atom, tmp_path)
    assert "nuevos=1" in out
    (f,) = tmp_path.glob("*.md")
    assert 'url: "https://x.es/articulo"' in f.read_text(encoding="utf-8")


def test_fecha_rfc2822_con_zona_textual(tmp_path):
    pub = format_datetime(now_utc() - dt.timedelta(hours=40))
    pub = pub.rsplit(" ", 1)[0] + " EST"  # zona textual, no offset numérico
    out = run_parser(rss_feed([rss_item("Zona EST vieja", "https://x.es/z", pub)]), tmp_path)
    assert "antiguos=1" in out


def test_item_sin_fecha_se_incluye(tmp_path):
    xml = rss_feed(["<item><title>Sin fecha</title><link>https://x.es/s</link>"
                    "<description>d</description></item>"])
    out = run_parser(xml, tmp_path)
    assert "nuevos=1" in out


def test_html_de_descripcion_se_limpia(tmp_path):
    pub = format_datetime(now_utc())
    desc = "&lt;p&gt;Texto &lt;b&gt;importante&lt;/b&gt;&lt;/p&gt;"
    run_parser(rss_feed([rss_item("Con HTML", "https://x.es/h", pub, desc)]), tmp_path)
    (f,) = tmp_path.glob("*.md")
    body = f.read_text(encoding="utf-8")
    assert "<p>" not in body and "Texto importante" in body


def test_xml_invalido_no_revienta(tmp_path):
    out = run_parser("esto no es XML", tmp_path)
    assert "XML inválido" in out
    assert list(tmp_path.glob("*.md")) == []


def test_dedup_mismo_dia_sin_seen_file(tmp_path):
    pub = format_datetime(now_utc())
    xml = rss_feed([rss_item("Repetido", "https://x.es/r", pub)])
    run_parser(xml, tmp_path)
    out = run_parser(xml, tmp_path)
    assert "nuevos=0" in out and "duplicados=1" in out


def test_dedup_entre_dias_con_seen_file(tmp_path):
    raw1 = tmp_path / "d1"; raw2 = tmp_path / "d2"
    raw1.mkdir(); raw2.mkdir()
    seen = tmp_path / "news-seen.txt"
    pub = format_datetime(now_utc())
    xml = rss_feed([rss_item("Solapado", "https://x.es/o", pub)])
    hoy = dt.date.today()
    out1 = run_parser(xml, raw1, hoy.isoformat(), seen_file=seen)
    assert "nuevos=1" in out1
    # "Día siguiente": misma noticia dentro de la ventana de 28h, otra carpeta.
    out2 = run_parser(xml, raw2, (hoy + dt.timedelta(days=1)).isoformat(), seen_file=seen)
    assert "nuevos=0" in out2 and "duplicados=1" in out2
    assert list(raw2.glob("*.md")) == []


def test_seen_file_poda_entradas_viejas(tmp_path):
    seen = tmp_path / "news-seen.txt"
    vieja = (dt.date.today() - dt.timedelta(days=10)).isoformat()
    reciente = dt.date.today().isoformat()
    seen.write_text(f"{vieja} aaaaaaaa\n{reciente} bbbbbbbb\n", encoding="utf-8")
    pub = format_datetime(now_utc())
    run_parser(rss_feed([rss_item("Nueva", "https://x.es/n", pub)]), tmp_path,
               seen_file=seen)
    contenido = seen.read_text(encoding="utf-8")
    assert "aaaaaaaa" not in contenido       # podada (>7 días)
    assert "bbbbbbbb" in contenido           # conservada
