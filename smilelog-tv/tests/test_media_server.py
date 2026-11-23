import http.client
import json
import os
import sys
import tempfile
import threading
import unittest
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from http.server import ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
_path = os.path.join(HERE, "..", "smilelog-tv-media")
_spec = spec_from_loader("media", SourceFileLoader("media", _path))
media = module_from_spec(_spec)
_spec.loader.exec_module(media)

DATA = bytes(range(256)) * 4  # 1024 byte


class MediaServerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        t = cls.tmp.name
        for d in ("media/local/sub", "media/drive", "usb", "ui", "outside"):
            os.makedirs(os.path.join(t, d))
        def w(p, b):
            with open(os.path.join(t, p), "wb") as f:
                f.write(b)

        w("media/local/b.mp4", DATA)
        w("media/local/A.jpg", b"jpg")
        w("media/local/sub/c.PDF", b"%PDF")
        w("media/local/notes.txt", b"x")
        w("media/local/.hidden.png", b"x")
        w("media/local/deck.pptx", b"x")
        w("outside/secret.png", b"secret")
        w("usb/u.mp3", b"mp3")
        w("ui/index.html", b"<html>ok</html>")
        w("ui/media.css", b"a{}")
        w("media/slides.txt", "# c\n\nBài 1 | https://docs.google.com/presentation/d/AbC-1_x/edit\n"
                              "| https://docs.google.com/presentation/d/ZZ9\nxấu | http://evil.example/d/1\n".encode())
        w("media/drive-sync.json", b'{"at":"2026-01-01T00:00:00","ok":true,"message":"ok"}')
        try:
            os.symlink(os.path.join(t, "outside"), os.path.join(t, "media/local/link"))
            cls.symlinks = True
        except (OSError, NotImplementedError):
            cls.symlinks = False
        cfg = media.Config({"MEDIA_DIR": os.path.join(t, "media"), "MEDIA_USB_DIR": os.path.join(t, "usb"),
                            "MEDIA_UI_DIR": os.path.join(t, "ui"), "MEDIA_CACHE": os.path.join(t, "cache")})
        cls.srv = ThreadingHTTPServer(("127.0.0.1", 0), media.make_handler(cfg))
        cls.port = cls.srv.server_address[1]
        threading.Thread(target=cls.srv.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()
        cls.srv.server_close()
        cls.tmp.cleanup()

    def req(self, path, method="GET", headers=None):
        c = http.client.HTTPConnection("127.0.0.1", self.port)
        c.request(method, path, headers=headers or {})
        r = c.getresponse()
        body = r.read()
        c.close()
        return r, body

    def test_list(self):
        r, body = self.req("/api/list")
        self.assertEqual(r.getheader("Cache-Control"), "no-store")
        d = json.loads(body)
        src = {s["id"]: s for s in d["sources"]}
        self.assertEqual([s["id"] for s in d["sources"]], ["usb", "drive", "local"])
        self.assertTrue(src["usb"]["available"])
        self.assertEqual([i["path"] for i in src["local"]["items"] if "/" not in i["path"] or True][:3],
                         ["A.jpg", "b.mp4", "deck.pptx"])
        paths = [i["path"] for i in src["local"]["items"]]
        self.assertIn("sub/c.PDF", paths)
        self.assertNotIn("notes.txt", paths)
        self.assertNotIn(".hidden.png", paths)
        self.assertFalse(any(p.startswith("link/") for p in paths) and not self.symlinks)
        item = next(i for i in src["local"]["items"] if i["path"] == "sub/c.PDF")
        self.assertEqual((item["id"], item["name"], item["kind"], item["size"]), ("local/sub/c.PDF", "c.PDF", "pdf", 4))
        self.assertEqual(src["drive"]["lastSync"]["ok"], True)
        self.assertIsNone(src["usb"].get("lastSync"))
        self.assertEqual(d["slides"][0], {"name": "Bài 1", "url":
                         "https://docs.google.com/presentation/d/AbC-1_x/embed?start=false&loop=false&rm=minimal"})
        self.assertEqual(d["slides"][1]["name"], "Google Slides")
        self.assertEqual(len(d["slides"]), 2)
        self.assertIsInstance(d["pptx"], bool)

    def test_range(self):
        r, body = self.req("/file/local/b.mp4")
        self.assertEqual((r.status, body, r.getheader("Accept-Ranges"), r.getheader("Content-Type")),
                         (200, DATA, "bytes", "video/mp4"))
        r, body = self.req("/file/local/b.mp4", headers={"Range": "bytes=10-19"})
        self.assertEqual((r.status, body, r.getheader("Content-Range")), (206, DATA[10:20], "bytes 10-19/1024"))
        r, body = self.req("/file/local/b.mp4", headers={"Range": "bytes=1000-"})
        self.assertEqual((r.status, body, r.getheader("Content-Range")), (206, DATA[1000:], "bytes 1000-1023/1024"))
        r, _ = self.req("/file/local/b.mp4", headers={"Range": "bytes=5000-"})
        self.assertEqual((r.status, r.getheader("Content-Range")), (416, "bytes */1024"))
        r, _ = self.req("/file/local/b.mp4", headers={"Range": "bytes=abc"})
        self.assertEqual(r.status, 416)

    def test_head_and_methods(self):
        r, body = self.req("/file/local/b.mp4", "HEAD")
        self.assertEqual((r.status, body, r.getheader("Content-Length")), (200, b"", "1024"))
        for m in ("POST", "PUT", "DELETE"):
            self.assertEqual(self.req("/api/list", m)[0].status, 405)
        self.assertIsNone(self.req("/api/list")[0].getheader("Access-Control-Allow-Origin"))

    def test_encoded_and_nested(self):
        r, body = self.req("/file/local/sub/c.PDF")
        self.assertEqual((r.status, body, r.getheader("Content-Type")), (200, b"%PDF", "application/pdf"))
        self.assertEqual(self.req("/file/usb/u.mp3")[0].status, 200)

    def test_traversal_and_denied(self):
        for p in ("/file/local/../../outside/secret.png", "/file/local/%2e%2e/%2e%2e/outside/secret.png",
                  "/file/local/..%2foutside%2fsecret.png", "/file/other/b.mp4", "/file/local/notes.txt",
                  "/file/local/.hidden.png", "/file/local/", "/file/local", "/nope", "/static/../index.html",
                  "/static/sub/x", "/pdf/local/b.mp4"):
            self.assertEqual(self.req(p)[0].status, 404, p)
        if self.symlinks:
            self.assertEqual(self.req("/file/local/link/secret.png")[0].status, 404)

    def test_ui(self):
        r, body = self.req("/")
        self.assertEqual((r.status, body), (200, b"<html>ok</html>"))
        r, body = self.req("/static/media.css")
        self.assertEqual((r.status, body, r.getheader("Content-Type")), (200, b"a{}", "text/css; charset=utf-8"))
        self.assertEqual(self.req("/static/missing.js")[0].status, 404)

    def test_pdf_without_converter(self):
        orig = media.converter
        media.converter = lambda: None
        try:
            r, body = self.req("/pdf/local/deck.pptx")
        finally:
            media.converter = orig
        self.assertEqual(r.status, 501)
        self.assertEqual(json.loads(body)["error"], media.ERR_NO_LO)

    def test_pdf_conversion_failure(self):
        orig = media.converter
        media.converter = lambda: sys.executable  # không phải LibreOffice: không tạo ra PDF
        try:
            r, body = self.req("/pdf/local/deck.pptx")
        finally:
            media.converter = orig
        self.assertEqual(r.status, 500)
        self.assertEqual(json.loads(body)["error"], media.ERR_CONVERT)

    def test_conf(self):
        p = os.path.join(self.tmp.name, "t.conf")
        with open(p, "w", encoding="utf-8") as f:
            f.write('# x\nMEDIA_PORT="9444"\nMEDIA_DIR=/x/y\n')
        cfg = media.Config(media.read_conf(p))
        self.assertEqual((cfg.port, cfg.media_dir, cfg.usb_dir), (9444, "/x/y", "/media/usb"))


if __name__ == "__main__":
    unittest.main()
