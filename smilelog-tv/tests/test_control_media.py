"""Kiểm MODE_RE và danh sách chế độ của smilelog-tv-control sau khi thêm chế độ media.
Chạy: python -m unittest smilelog-tv/tests/test_control_media.py (từ thư mục gốc repo)."""
import importlib.machinery
import importlib.util
import os
import sys
import tempfile
import socketserver
import types
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "..", "smilelog-tv-control")

if "grp" not in sys.modules:
    try:
        import grp  # noqa: F401
    except ImportError:  # Windows: chỉ cần để nạp được module
        sys.modules["grp"] = types.ModuleType("grp")

if not hasattr(socketserver, "UnixStreamServer"):  # Windows
    socketserver.UnixStreamServer = socketserver.TCPServer

loader = importlib.machinery.SourceFileLoader("smilelog_tv_control", PATH)
spec = importlib.util.spec_from_loader("smilelog_tv_control", loader)
control = importlib.util.module_from_spec(spec)
loader.exec_module(control)


class ModeRegexTest(unittest.TestCase):
    def test_accepts_known_modes(self):
        for m in ("tv", "full", "training", "media"):
            self.assertTrue(control.MODE_RE.match(m), m)

    def test_rejects_others(self):
        for m in ("", "toggle", "Media", "media ", "media\n2", "tv|media", "x", "mediaa", "../media"):
            self.assertFalse(control.MODE_RE.match(m), repr(m))


class FakeCliTest(unittest.TestCase):
    def make_cli(self, available, mode):
        d = tempfile.mkdtemp()
        cli = os.path.join(d, "cli.py")
        with open(cli, "w") as f:
            f.write(
                "#!%s\nimport sys\na = sys.argv[1:]\n"
                "print('%s' if a == ['mode', '--available'] else '%s')\n" % (sys.executable, available, mode)
            )
        os.chmod(cli, 0o755)
        return control.Actions(cli=cli)

    @unittest.skipIf(os.name == "nt", "cần shebang chạy được")
    def test_modes_and_mode(self):
        a = self.make_cli("tv full training media", "media")
        self.assertEqual(a.modes(), ["tv", "full", "training", "media"])
        self.assertEqual(a.mode(), "media")
        a = self.make_cli("tv full", "tv")
        self.assertEqual(a.modes(), ["tv", "full"])

    def test_set_rejects_unknown_and_accepts_media(self):
        a = control.Actions(cli=sys.executable, cooldown=0)
        self.assertFalse(a.run("set", "bogus"))
        self.assertFalse(a.run("set", None))
        # media hợp lệ về mặt regex: chạy "python mode media" sẽ thoát lỗi ở nền nhưng run() trả True
        self.assertTrue(a.run("set", "media"))


if __name__ == "__main__":
    unittest.main()
