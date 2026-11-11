#!/usr/bin/env python3
"""Offline checks; never inject input into the running desktop."""

import os
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import desktop


class DesktopTests(unittest.TestCase):
    def setUp(self):
        self.window = {
            "address": "0xabc", "class": "Google-chrome", "pid": 23,
            "mapped": True, "at": [100, 100], "size": [800, 600],
            "workspace": {"id": 3, "name": "project"},
        }
        self.active = self.window.copy()
        self.locked = False
        self.typed = []
        self.clicked = False
        self.steal_focus = False

    def query(self, name):
        return {
            "clients": [self.window], "activewindow": self.active,
            "locked": {"locked": self.locked},
        }[name]

    def command(self, argv, *, input=None):
        if argv[0] == "hyprctl" and "eval" in argv:
            self.active = self.window.copy()
            self.active["visible"] = True
        if argv[0] == "wtype":
            if input is not None:
                self.typed.append(input)
            if "t" in argv and self.steal_focus:
                self.active = {"address": "0xdef"}
        if argv[0] == "wlrctl":
            self.clicked = True
        return "ok"

    def test_caller_uses_terminal_ancestry_instead_of_active_window(self):
        other = dict(self.window, address="0xdef", pid=99)
        with patch.object(desktop, "ancestor_pids", return_value=[31, 29, 23, 1]):
            self.assertEqual(desktop.caller_window([other, self.window]), self.window)

    def test_focus_returns_the_observed_state_after_focusing(self):
        self.window["visible"] = False
        with patch.object(desktop, "query", self.query), patch.object(desktop, "command", self.command):
            result = desktop.focus("0xabc")
        self.assertTrue(result["visible"])

    def test_rotated_fractional_monitor_keeps_negative_origin(self):
        monitor = {"x": -960, "y": -20, "width": 1920, "height": 1080,
                   "scale": 1.5, "transform": 1}
        self.assertEqual(desktop.monitor_geometry(monitor), [-960, -20, 720, 1280])

    def test_focus_loss_prevents_typing(self):
        self.active = {"address": "0xdef"}
        with patch.object(desktop, "query", self.query), patch.object(desktop, "command", self.command):
            with self.assertRaises(desktop.DesktopError):
                desktop.type_text("0xabc", "do not deliver")
        self.assertEqual(self.typed, [])

    def test_unlocked_focused_window_receives_literal_unicode_text(self):
        text = "你好 $HOME $(not-a-shell)"
        with patch.object(desktop, "query", self.query), patch.object(desktop, "command", self.command):
            desktop.type_text("0xabc", text)
        self.assertEqual(self.typed, [text])

    def test_open_tab_delivers_url_to_a_focused_chrome_window(self):
        with patch.object(desktop, "query", self.query), patch.object(desktop, "command", self.command):
            result = desktop.open_tab("0xabc", "http://localhost:5173/")
        self.assertEqual(self.typed, ["http://localhost:5173/"])
        self.assertFalse(result["verified_url"])

    def test_locked_session_prevents_typing(self):
        self.locked = True
        with patch.object(desktop, "query", self.query), patch.object(desktop, "command", self.command):
            with self.assertRaises(desktop.DesktopError):
                desktop.type_text("0xabc", "do not deliver")
        self.assertEqual(self.typed, [])

    def test_url_with_newline_never_reaches_browser(self):
        with patch.object(desktop, "query", self.query), patch.object(desktop, "command", self.command):
            with self.assertRaises(desktop.DesktopError):
                desktop.open_tab("0xabc", "https://example.org/\ncommands")
        self.assertEqual(self.typed, [])

    def test_open_tab_stops_when_focus_changes_after_new_tab(self):
        self.steal_focus = True
        with patch.object(desktop, "query", self.query), patch.object(desktop, "command", self.command):
            with self.assertRaises(desktop.DesktopError):
                desktop.open_tab("0xabc", "https://example.org/")
        self.assertEqual(self.typed, [])

    def test_click_outside_target_window_never_delivers_button(self):
        with patch.object(desktop, "query", self.query), patch.object(desktop, "command", self.command):
            with self.assertRaises(desktop.DesktopError):
                desktop.pointer("0xabc", 99, 120, "click", ["left"])
        self.assertFalse(self.clicked)

    def test_stale_window_address_is_rejected(self):
        with patch.object(desktop, "query", self.query):
            with self.assertRaises(desktop.DesktopError):
                desktop.window("0xdead")

    def test_monitor_move_during_capture_rejects_obsolete_coordinates(self):
        monitor = {"name": "test", "width": 1920, "height": 1080, "x": 0,
                   "y": 0, "scale": 1, "transform": 0, "focused": True}

        def query(name):
            return [monitor.copy()] if name == "monitors" else self.query(name)

        def capture(argv, **kwargs):
            Path(argv[-1]).write_bytes(b"\x89PNG\r\n\x1a\n" + b"\0" * 8 + struct.pack(">II", 1920, 1080))
            monitor["x"] = -1920
            return ""

        with tempfile.TemporaryDirectory() as directory, \
                patch.dict(os.environ, {"XDG_RUNTIME_DIR": directory}), \
                patch.object(desktop, "query", query), \
                patch.object(desktop, "command", capture), \
                patch.object(desktop, "grim_path", return_value="grim"):
            with self.assertRaises(desktop.DesktopError):
                desktop.screenshot(monitor_name="test")


if __name__ == "__main__":
    unittest.main()
