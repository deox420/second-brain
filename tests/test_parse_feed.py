#!/usr/bin/env python3
# Tests de bin/parse-feed.py (caja negra: subprocess + fixtures RSS/Atom).
# Sin dependencias externas: python3 -m unittest discover tests
import os
import subprocess
import sys
import tempfile
import unittest
import datetime as dt
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PARSER = REPO / "bin" / "parse-feed.py"
TODAY = dt.date.today().isoformat()


def rfc2822(delta_hours=0):
    d = dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=delta_hours)
    return d.strftime("%a, %d %b %Y %H:%M:%S +0000")


def iso_ms(delta_hours=0):
    d = dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=delta_hours)
    return d.strftime("%Y-%m-%dT%H:%M:%S.123+00:00")


def rss(items):
    body = "".join(
        f"<item><title>{t}</title><link>{l}</link>"
        f"<pubDate>{p}</pubDate><description>{d}</description></item>"
        for t, l, p, d in items
    )
    return f'<?xml version="1.0"?><rss version="2.0"><channel>{body}</channel></rss>'


ATOM = f"""<?xml version="1.0"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <title>Entrada Atom</title>
    <link rel="self" href="https://feed.example/atom.xml"/>
    <link rel="alternate" href="https://ejemplo.es/articulo"/>
    <published>{iso_ms()}</published>
    <summary>Resumen.</summary>
  </entry>
</feed>"""


class ParseFeedTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.raw = Path(self.tmp.name) / "raw"
        self.raw.mkdir()
        self.seen = Path(self.tmp.name) / "news-seen.txt"

    def tearDown(self):
        self.tmp.cleanup()

    def run_parser(self, xml, date=TODAY, seen=True):
        env = dict(os.environ, FEED_NAME="Test", RAW_DIR=str(self.raw))
        if seen:
            env["SEEN_FILE"] = str(self.seen)
        r = subprocess.run(
            [sys.executable, str(PARSER), date],
            input=xml, capture_output=True, text=True, env=env,
        )
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout

    def files(self):
        return sorted(p.name for p in self.raw.iterdir())

    def test_rss_slug_sin_tildes(self):
        """B2: 'España' y 'año' no deben romperse en el nombre de archivo."""
        self.run_parser(rss([("España: el año según informe", "https://e.es/1", rfc2822(), "x")]))
        self.assertEqual(len(self.files()), 1)
        self.assertTrue(self.files()[0].startswith("espana-el-ano-segun-informe-"))

    def test_yaml_escapado(self):
        """B3: comillas y dos puntos en el título no rompen el frontmatter."""
        self.run_parser(rss([('Título: con "comillas" y \\barra', "https://e.es/2", rfc2822(), "x")]))
        contenido = (self.raw / self.files()[0]).read_text()
        self.assertIn('titulo: "Título: con \\"comillas\\" y \\\\barra"', contenido)
        self.assertIn('url: "https://e.es/2"', contenido)

    def test_fechas_iso_con_milisegundos_y_rfc2822(self):
        """B4: ambos formatos de fecha se aceptan si son frescos."""
        out = self.run_parser(rss([("Uno", "https://e.es/3", rfc2822(), "x")]) )
        self.assertIn("1 nuevos", out)
        out = self.run_parser(ATOM)
        self.assertIn("1 nuevos", out)

    def test_atom_link_alternate(self):
        """B5: en Atom se guarda la URL del artículo, no la del feed (rel=self)."""
        self.run_parser(ATOM)
        contenido = (self.raw / self.files()[0]).read_text()
        self.assertIn('url: "https://ejemplo.es/articulo"', contenido)
        self.assertNotIn("feed.example", contenido.split("# ")[0].split("url:")[1].split("\n")[0])

    def test_item_antiguo_descartado(self):
        """Ventana de frescura: un item de hace 40h no entra."""
        out = self.run_parser(rss([("Vieja", "https://e.es/4", rfc2822(40), "x")]))
        self.assertIn("0 nuevos", out)
        self.assertIn("1 antiguos", out)
        self.assertEqual(self.files(), [])

    def test_dedup_mismo_dia_y_dia_siguiente(self):
        """B6: el mismo item no se escribe dos veces, ni siquiera al día siguiente."""
        feed = rss([("Repetida", "https://e.es/5", rfc2822(), "x")])
        self.assertIn("1 nuevos", self.run_parser(feed))
        self.assertIn("(1 ya vistos", self.run_parser(feed))
        manana = (dt.date.today() + dt.timedelta(days=1)).isoformat()
        raw2 = Path(self.tmp.name) / "raw2"
        raw2.mkdir()
        env = dict(os.environ, FEED_NAME="Test", RAW_DIR=str(raw2), SEEN_FILE=str(self.seen))
        r = subprocess.run([sys.executable, str(PARSER), manana],
                           input=feed, capture_output=True, text=True, env=env)
        self.assertIn("(1 ya vistos", r.stdout)
        self.assertEqual(list(raw2.iterdir()), [])

    def test_poda_del_registro_a_7_dias(self):
        """El registro de vistos olvida hashes de hace más de 7 días."""
        viejo = (dt.date.today() - dt.timedelta(days=9)).isoformat()
        self.seen.write_text(f"{viejo} cafe1234\n")
        self.run_parser(rss([("Nueva", "https://e.es/6", rfc2822(), "x")]))
        registro = self.seen.read_text()
        self.assertNotIn("cafe1234", registro)
        self.assertIn(TODAY, registro)

    def test_xml_invalido_no_revienta(self):
        """Un feed corrupto se omite con aviso, exit 0 y cero archivos."""
        out = self.run_parser("esto no es xml <<<")
        self.assertIn("XML inválido", out)
        self.assertEqual(self.files(), [])

    def test_sin_seen_file_sigue_funcionando(self):
        """SEEN_FILE es opcional: sin él, solo dedup por archivo existente."""
        out = self.run_parser(rss([("Suelta", "https://e.es/7", rfc2822(), "x")]), seen=False)
        self.assertIn("1 nuevos", out)


if __name__ == "__main__":
    unittest.main()
