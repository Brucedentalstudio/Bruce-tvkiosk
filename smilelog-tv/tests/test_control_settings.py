"""Kiểm tra /settings của smilelog-tv-control: đọc cấu hình, kiểm tra giá trị, cần token.

Chạy: python3 -m unittest discover -s smilelog-tv/tests
"""
import importlib.machinery
import importlib.util
import json
import os
import socketserver
import sys
import tempfile
import threading
import types
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
# Chạy được cả trên Windows (không có grp, socket unix); bài kiểm tra không dùng tới hai thứ đó.
sys.modules.setdefault("grp", types.ModuleType("grp"))
if not hasattr(socketserver, "UnixStreamServer"):
    socketserver.UnixStreamServer = socketserver.TCPServer
_loader = importlib.machinery.SourceFileLoader("smilelog_tv_control", os.path.join(HERE, "..", "smilelog-tv-control"))
_spec = importlib.util.spec_from_loader(_loader.name, _loader)
ctl = importlib.util.module_from_spec(_spec)
_loader.exec_module(ctl)


def write_conf(text):
    f = tempfile.NamedTemporaryFile("w", suffix=".conf", delete=False, encoding="utf-8")
    f.write(text)
    f.close()
    return f.name


class FakeActions:
    def mode(self):
        return "full"

    def modes(self):
        return ["tv", "full"]


class ReadConf(unittest.TestCase):
    def test_quotes_comments_and_last_wins(self):
        path = write_conf('# chú thích\nDIM_START="22:00"\nDIM_END=\'05:00\'\nDIM_LEVEL=0.4  # tối hơn\n'
                          'DIM_LEVEL="0.5"\n  KHO_ROTATE_SEC="45"\nbad line\n')
        conf = ctl.read_conf(path)
        os.unlink(path)
        self.assertEqual(conf["DIM_START"], "22:00")
        self.assertEqual(conf["DIM_END"], "05:00")
        self.assertEqual(conf["DIM_LEVEL"], "0.5")
        self.assertEqual(conf["KHO_ROTATE_SEC"], "45")

    def test_missing_file_is_empty(self):
        self.assertEqual(ctl.read_conf(os.path.join(HERE, "khong-co.conf")), {})


class Settings(unittest.TestCase):
    def test_defaults_when_keys_missing(self):
        s = ctl.settings({}, "full")
        self.assertEqual((s["shift_min"], s["shift_px"]), (5, 4))
        self.assertEqual((s["saver_every_min"], s["saver_sec"]), (60, 60))
        self.assertEqual((s["dim_start"], s["dim_end"], s["dim_level"]), ("22:00", "05:00", 0.3))
        self.assertEqual(s["rotate_sec"], 30)
        self.assertEqual(s["rotate_stages"], ["MAU", "CAD", "CAM", "CAMNGUOI", "SU", "COMPOSITE", "QC"])
        self.assertTrue(s["switch_button"])
        self.assertEqual(s["mode"], "full")

    def test_empty_or_zero_turns_off(self):
        s = ctl.settings({"BURNIN_SHIFT_MIN": "", "BURNIN_SAVER_EVERY_MIN": "0", "DIM_START": "",
                          "KHO_ROTATE_SEC": "0"}, "full")
        self.assertEqual((s["shift_min"], s["saver_every_min"], s["dim_level"], s["rotate_sec"]), (0, 0, 0, 0))
        self.assertEqual(s["dim_start"], "")

    def test_out_of_range_and_garbage_turn_off(self):
        s = ctl.settings({"BURNIN_SHIFT_PX": "500", "BURNIN_SHIFT_MIN": "abc", "BURNIN_SAVER_SEC": "-1",
                          "DIM_LEVEL": "1", "KHO_ROTATE_SEC": "2"}, "tv")
        self.assertEqual((s["shift_px"], s["shift_min"], s["saver_sec"], s["dim_level"], s["rotate_sec"]),
                         (0, 0, 0, 0, 0))

    def test_hhmm_validation(self):
        for bad in ("24:00", "7:00", "22:60", "22h", "22:00; rm -rf /"):
            s = ctl.settings({"DIM_START": bad}, "tv")
            self.assertEqual((s["dim_start"], s["dim_level"]), ("", 0), bad)
        s = ctl.settings({"DIM_START": "23:30", "DIM_END": "06:15", "DIM_LEVEL": "0.5"}, "tv")
        self.assertEqual((s["dim_start"], s["dim_end"], s["dim_level"]), ("23:30", "06:15", 0.5))

    def test_stage_list_validation(self):
        for bad in ("mau,cad", "MAU, CAD", "MAU,,CAD", "MAU;CAD", "<script>", ""):
            s = ctl.settings({"KHO_ROTATE_STAGES": bad}, "full")
            self.assertEqual((s["rotate_stages"], s["rotate_sec"]), ([], 0), bad)
        s = ctl.settings({"KHO_ROTATE_STAGES": "CAD,SU"}, "full")
        self.assertEqual(s["rotate_stages"], ["CAD", "SU"])

    def test_switch_button_and_timezone(self):
        s = ctl.settings({"SHOW_SWITCH_BUTTON": "no", "TIMEZONE": "Khong/Co"}, "tv")
        self.assertFalse(s["switch_button"])
        self.assertIsNone(s["timezone"])


class Endpoint(unittest.TestCase):
    def setUp(self):
        self.conf = write_conf('KHO_ROTATE_STAGES="CAD,QC"\nBURNIN_SHIFT_PX="2"\n')
        self.old_conf, ctl.CONF = ctl.CONF, self.conf
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), ctl.make_handler(FakeActions(), "bi-mat"))
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.url = f"http://127.0.0.1:{self.server.server_address[1]}/settings"

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        ctl.CONF = self.old_conf
        os.unlink(self.conf)

    def get(self, token):
        req = urllib.request.Request(self.url, headers={"X-Smilelog-Token": token})
        with urllib.request.urlopen(req, timeout=5) as r:
            return json.load(r)

    def test_needs_token(self):
        with self.assertRaises(urllib.error.HTTPError) as e:
            self.get("sai")
        self.assertEqual(e.exception.code, 403)
        e.exception.close()

    def test_reads_conf_each_time(self):
        s = self.get("bi-mat")
        self.assertEqual((s["rotate_stages"], s["shift_px"], s["mode"]), (["CAD", "QC"], 2, "full"))
        with open(self.conf, "a", encoding="utf-8") as f:
            f.write('KHO_ROTATE_SEC=""\n')
        self.assertEqual(self.get("bi-mat")["rotate_sec"], 0)


if __name__ == "__main__":
    unittest.main()
