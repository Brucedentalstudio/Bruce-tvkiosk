import http.client
import json
import os
import sys
import tempfile
import threading
import time
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
        cls.usb = os.path.join(t, "usb")
        cls.orig_ismount = os.path.ismount
        os.path.ismount = lambda p: p == cls.usb or cls.orig_ismount(p)
        cfg = media.Config({"MEDIA_DIR": os.path.join(t, "media"), "MEDIA_USB_DIR": os.path.join(t, "usb"),
                            "MEDIA_UI_DIR": os.path.join(t, "ui"), "MEDIA_CACHE": os.path.join(t, "cache")})
        cls.srv = ThreadingHTTPServer(("127.0.0.1", 0), media.make_handler(cfg))
        cls.port = cls.srv.server_address[1]
        threading.Thread(target=cls.srv.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        os.path.ismount = cls.orig_ismount
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
        self.assertFalse(any(p.startswith("link/") for p in paths))
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
        for m in ("POST", "PUT", "DELETE", "PROPFIND"):
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

    def fake_converter(self, body):
        """Bộ chuyển giả (chạy được cả Windows): ghi PDF vào --outdir, đếm số lần gọi."""
        d = self.tmp.name
        calls = os.path.join(d, "calls.txt")
        py = os.path.join(d, "fake_lo.py")
        with open(py, "w") as f:
            f.write("import os, sys, time\n"
                    "a = sys.argv\nout = a[a.index('--outdir') + 1]\nsrc = a[-1]\n"
                    f"open({calls!r}, 'a').write('x')\n{body}\n"
                    "open(os.path.join(out, os.path.splitext(os.path.basename(src))[0] + '.pdf'), 'wb')"
                    ".write(b'%PDF-fake')\n")
        if os.name == "nt":
            exe = os.path.join(d, "fake_lo.bat")
            text = f'@"{sys.executable}" "{py}" %*\r\n'
        else:
            exe = os.path.join(d, "fake_lo.sh")
            text = f'#!/bin/sh\nexec "{sys.executable}" "{py}" "$@"\n'
        with open(exe, "w") as f:
            f.write(text)
        os.chmod(exe, 0o755)
        if os.path.exists(calls):
            os.remove(calls)
        return exe, calls

    def count(self, calls):
        return len(open(calls).read()) if os.path.exists(calls) else 0

    def test_pdf_conversion_cache_and_lock(self):
        with open(os.path.join(self.tmp.name, "media/local/deck2.pptx"), "wb") as f:
            f.write(b"x")
        exe, calls = self.fake_converter("time.sleep(0.5)")
        orig = media.converter
        media.converter = lambda: exe
        try:
            res = []
            ts = [threading.Thread(target=lambda: res.append(self.req("/pdf/local/deck2.pptx"))) for _ in range(2)]
            for t in ts:
                t.start()
            for t in ts:
                t.join()
            res.append(self.req("/pdf/local/deck2.pptx"))
        finally:
            media.converter = orig
        for r, body in res:
            self.assertEqual((r.status, body, r.getheader("Content-Type")), (200, b"%PDF-fake", "application/pdf"))
        self.assertEqual(self.count(calls), 1)  # khoá chuyển một lần + cache

    def test_pdf_timeout(self):
        with open(os.path.join(self.tmp.name, "media/local/deck3.pptx"), "wb") as f:
            f.write(b"x")
        exe, calls = self.fake_converter("time.sleep(20)")
        orig, orig_t = media.converter, media.CONVERT_TIMEOUT
        media.converter, media.CONVERT_TIMEOUT = (lambda: exe), 1
        try:
            t0 = time.time()
            r, body = self.req("/pdf/local/deck3.pptx")
        finally:
            media.converter, media.CONVERT_TIMEOUT = orig, orig_t
        self.assertEqual((r.status, json.loads(body)["error"]), (500, media.ERR_CONVERT))
        self.assertLess(time.time() - t0, 15)

    def test_usb_needs_mount_and_bad_input(self):
        cfg = media.Config({"MEDIA_USB_DIR": os.path.join(self.tmp.name, "ui")})  # có nội dung nhưng không mount
        self.assertFalse(media.available(cfg, "usb"))
        p = os.path.join(self.tmp.name, "bad.txt")
        with open(p, "wb") as f:
            f.write(b"B\xe0i | https://docs.google.com/presentation/d/ZZ9\n")  # cp1258, không phải UTF-8
        self.assertEqual(len(media.parse_slides(p)), 1)
        try:
            bad = os.path.join(os.fsencode(self.tmp.name), b"badname-\xff.png")
            open(bad, "wb").close()
        except (OSError, ValueError):
            return
        try:
            json.dumps(media.scan(self.tmp.name), ensure_ascii=False).encode("utf-8")
        finally:
            os.remove(bad)

    def test_conf(self):
        p = os.path.join(self.tmp.name, "t.conf")
        with open(p, "w", encoding="utf-8") as f:
            f.write('# x\nMEDIA_PORT="9444"\nMEDIA_DIR=/x/y\n')
        cfg = media.Config(media.read_conf(p))
        self.assertEqual((cfg.port, cfg.media_dir, cfg.usb_dir), (9444, "/x/y", "/media/usb"))


if __name__ == "__main__":
    unittest.main()
