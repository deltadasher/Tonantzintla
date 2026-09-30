"""Dependency-free structural checks for the deployed docs/ website.

These checks do not establish browser layout, playback, or accessibility quality.
"""
from html.parser import HTMLParser
from pathlib import Path
import re
import struct
import unittest
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
BASE = "https://deltadasher.github.io/Tonantzintla/"
INSTRUMENTS = ("aperture", "ephemeris", "parallax", "resonance", "umbra")
PAGES = ("index.html", *(f"suite/{name}.html" for name in INSTRUMENTS), "404.html")


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__(convert_charrefs=True)
        self.path = path
        self.nodes = []
        self.ids = {}
        self.duplicates = []
        self.doctype = False
        self.feed(path.read_text())

    def handle_decl(self, value):
        if value.lower() == "doctype html":
            self.doctype = True

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.nodes.append((tag, attrs, self.getpos()[0]))
        if "id" in attrs:
            if attrs["id"] in self.ids:
                self.duplicates.append(attrs["id"])
            self.ids[attrs["id"]] = (tag, attrs)

    handle_startendtag = handle_starttag

    def find(self, tag, **attrs):
        return [a for t, a, _ in self.nodes if t == tag and all(a.get(k) == v for k, v in attrs.items())]


def local_target(page, value):
    url = urlsplit(value)
    if url.scheme or url.netloc:
        if url.scheme != "https" or url.netloc != "deltadasher.github.io":
            return None
        path = url.path
    else:
        path = url.path
    if path.startswith("/Tonantzintla/"):
        target = DOCS / unquote(path.removeprefix("/Tonantzintla/"))
    elif path.startswith("/"):
        raise AssertionError(f"{page.path.name}: root URL omits project prefix: {value}")
    elif path:
        target = page.path.parent / unquote(path)
    else:
        target = page.path
    target = target.resolve()
    if target.is_dir():
        target /= "index.html"
    return target, unquote(url.fragment)


def image_size(path):
    data = path.read_bytes()
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return struct.unpack(">II", data[16:24])
    if data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        offset = 12
        while offset + 8 <= len(data):
            kind = data[offset:offset + 4]
            length = int.from_bytes(data[offset + 4:offset + 8], "little")
            payload = data[offset + 8:offset + 8 + length]
            if kind == b"VP8X":
                return 1 + int.from_bytes(payload[4:7], "little"), 1 + int.from_bytes(payload[7:10], "little")
            if kind == b"VP8L":
                bits = int.from_bytes(payload[1:5], "little")
                return 1 + (bits & 0x3FFF), 1 + ((bits >> 14) & 0x3FFF)
            if kind == b"VP8 " and payload[3:6] == b"\x9d\x01\x2a":
                width, height = struct.unpack("<HH", payload[6:10])
                return width & 0x3FFF, height & 0x3FFF
            offset += 8 + length + (length % 2)
    return None


class StaticWebsiteTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pages = {str((DOCS / name).resolve()): Page(DOCS / name) for name in PAGES}

    def test_page_structure_and_references(self):
        for name in PAGES:
            with self.subTest(page=name):
                page = self.pages[str((DOCS / name).resolve())]
                self.assertTrue(page.doctype)
                self.assertEqual(page.duplicates, [], "IDs must be unique")
                self.assertEqual(len(page.find("html", lang="en")), 1)
                self.assertEqual(len(page.find("main")), 1)
                self.assertEqual(len(page.find("h1")), 1)
                self.assertEqual(len(page.find("title")), 1)
                self.assertEqual(len(page.find("meta", charset="utf-8")), 1)
                self.assertEqual(len(page.find("meta", name="viewport")), 1)
                self.assertTrue(page.find("link", rel="icon"))
                self.assertTrue(page.find("a", **{"class": "skip-link", "href": "#main-content"}))
                for tag, attrs, line in page.nodes:
                    location = f"{name}:{line} <{tag}>"
                    for key in ("aria-controls", "aria-labelledby", "aria-describedby"):
                        for reference in attrs.get(key, "").split():
                            self.assertIn(reference, page.ids, f"{location} missing {key} target")
                    if tag == "img":
                        self.assertIn("alt", attrs, f"{location} image needs alt, including decorative images")
                        self.assertIn("width", attrs, f"{location} reserve image space")
                        self.assertIn("height", attrs)
                        target = local_target(page, attrs["src"])[0]
                        dimensions = image_size(target)
                        if dimensions:
                            self.assertEqual((int(attrs["width"]), int(attrs["height"])), dimensions, location)
                    if tag == "button":
                        self.assertEqual(attrs.get("type"), "button", location)
                    if tag == "nav":
                        self.assertTrue(attrs.get("aria-label") or attrs.get("aria-labelledby"), location)
                    for key in ("src", "href", "poster"):
                        if key not in attrs:
                            continue
                        target = local_target(page, attrs[key])
                        if target:
                            path, fragment = target
                            self.assertTrue(path.is_relative_to(DOCS), f"{location} outside public docs")
                            self.assertTrue(path.is_file(), f"{location} missing local target: {attrs[key]}")
                            if fragment and path.suffix == ".html":
                                self.assertIn(str(path), self.pages, f"{location} unknown destination page")
                                self.assertIn(fragment, self.pages[str(path)].ids, f"{location} broken fragment: {attrs[key]}")
                        github = re.match(r"https://github.com/deltadasher/Tonantzintla/(?:tree|blob)/main/(.+)", attrs[key])
                        if github:
                            self.assertTrue((ROOT / github.group(1)).exists(), f"{location} missing source link")
                if name == "404.html":
                    self.assertTrue(page.find("meta", name="robots", content="noindex"))
                    continue
                canonical = BASE + ("" if name == "index.html" else name)
                self.assertEqual(page.find("link", rel="canonical")[0]["href"], canonical)
                for key, value in (("name", "description"), ("property", "og:title"), ("property", "og:description"), ("property", "og:image")):
                    self.assertTrue(page.find("meta", **{key: value})[0].get("content"))
                image = page.find("meta", property="og:image")[0]["content"]
                self.assertTrue(local_target(page, image)[0].is_file(), f"{name} broken social image")

    def test_instrument_navigation_and_tabs(self):
        home = self.pages[str((DOCS / "index.html").resolve())]
        self.assertTrue(any("site-tab" in attrs.get("class", "").split() for _, attrs, _ in home.nodes), "entrance needs a focus return target")
        tabs = home.find("button", role="tab")
        panels = home.find("section", role="tabpanel")
        self.assertEqual(len(tabs), 5)
        self.assertEqual(len(panels), 5)
        self.assertEqual(sum(t["aria-selected"] == "true" for t in tabs), 1)
        for name, tab, panel in zip(INSTRUMENTS, tabs, panels):
            self.assertEqual(tab["id"], "tab-" + name)
            self.assertEqual(tab["aria-controls"], panel["id"])
            self.assertEqual(panel["aria-labelledby"], tab["id"])
            self.assertEqual(tab["tabindex"], "0" if name == "aperture" else "-1")
            self.assertEqual("hidden" in panel, name != "aperture")
            page = self.pages[str((DOCS / f"suite/{name}.html").resolve())]
            links = [attrs for tag, attrs, _ in page.nodes if tag == "a" and attrs.get("href") in {f"{n}.html" for n in INSTRUMENTS}]
            self.assertEqual({link["href"] for link in links}, {f"{n}.html" for n in INSTRUMENTS})
            selected = [link for link in links if link.get("aria-current") == "page"]
            self.assertEqual(len(selected), 1)
            self.assertEqual(selected[0]["href"], f"{name}.html")

    def test_css_assets_and_sitemap(self):
        for stylesheet in DOCS.glob("*.css"):
            page = self.pages[str((DOCS / "index.html").resolve())]
            for value in re.findall(r"url\(\s*['\"]?([^)'\"]+)", stylesheet.read_text()):
                if value.startswith("data:") or value.startswith("#"):
                    continue
                target = local_target(page, value)
                self.assertIsNotNone(target, "fonts and decorative assets must remain local")
                self.assertTrue(target[0].is_file(), f"{stylesheet.name}: missing {value}")
        sitemap = ET.parse(DOCS / "sitemap.xml")
        urls = [entry.text for entry in sitemap.findall(".//{http://www.sitemaps.org/schemas/sitemap/0.9}loc")]
        self.assertEqual(set(urls), {BASE, *(BASE + f"suite/{name}.html" for name in INSTRUMENTS)})
        self.assertEqual(len(urls), 6)
        self.assertEqual((DOCS / "googlef5eea944e86f2bec.html").read_text().strip(), "google-site-verification: googlef5eea944e86f2bec.html")


if __name__ == "__main__":
    unittest.main(verbosity=2)
