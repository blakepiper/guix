#!/usr/bin/env python3
"""Exercise host monitor policies without touching the running X server."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "home/przvl/bin/alpinews-monitors"


class MonitorTests(unittest.TestCase):
    def run_policy(self, host, outputs, fail_mode=False):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = root / "alpinews"
            config.mkdir()
            # Use the actual host config string, so changes exercise deployment.
            source = (ROOT / "hosts" / host / "home.scm").read_text()
            (config / "display.conf").write_text(source.split('#:display-config "')[1].split('"')[0])
            (root / "outputs").write_text(outputs)
            stub = root / "xrandr"
            stub.write_text('''#!/bin/sh
if [ "$1" = --query ]; then cat "$TEST_ROOT/outputs"; exit; fi
printf '%s\\n' "$*" >> "$TEST_ROOT/calls"
case " $* " in *" --mode "*) [ "$TEST_FAIL_MODE" = 0 ] || exit 1;; esac
''')
            stub.chmod(0o755)
            env = dict(os.environ, XDG_CONFIG_HOME=tmp, DISPLAY=":999",
                       TEST_ROOT=tmp, TEST_FAIL_MODE=str(int(fail_mode)),
                       PATH=tmp + os.pathsep + os.environ["PATH"])
            subprocess.run(["sh", str(HELPER)], env=env, check=True,
                           capture_output=True, text=True)
            calls = root / "calls"
            return calls.read_text().splitlines() if calls.exists() else []

    def test_zen_discovers_readable_panel(self):
        self.assertEqual(self.run_policy("zen", "eDP-7 connected\n  1920x1200 59.95*+\n"),
                         ["--output eDP-7 --mode 1920x1200 --rate 60 --scale 1x1 --primary"])

    def test_zen_mirrors_dock_at_common_resolution(self):
        calls = self.run_policy("zen", "eDP-2 connected\n  1920x1080 59.97\nDP-1-4-4 connected\n  1920x1080 120.00\n")
        self.assertEqual(calls, ["--output eDP-2 --mode 1920x1080 --rate 60 --scale 1x1 --primary --output DP-1-4-4 --mode 1920x1080 --rate 120 --scale 1x1 --same-as eDP-2"])

    def test_zen_falls_back_to_preferred_mode(self):
        calls = self.run_policy("zen", "eDP-9 connected\nHDMI-3 disconnected\n", True)
        self.assertEqual(calls[0], "--output HDMI-3 --off")
        self.assertEqual(calls[-1], "--output eDP-9 --auto --scale 1x1 --primary")

    def test_no_internal_leaves_outputs_unchanged(self):
        self.assertEqual(self.run_policy("zen", "DP-1 connected\n"), [])

    def test_t490_mirror_unchanged(self):
        calls = self.run_policy("t490", "eDP-1 connected\n  1920x1080 60.00\nHDMI-2 connected\n  1920x1080 60.00\n")
        self.assertEqual(calls, ["--output eDP-1 --mode 1920x1080 --rate 60 --scale 1x1 --primary --output HDMI-2 --mode 1920x1080 --rate 60 --scale 1x1 --same-as eDP-1"])

    def test_t490_internal_only_unchanged(self):
        calls = self.run_policy("t490", "eDP-1 connected\nHDMI-2 disconnected\n")
        self.assertEqual(calls, ["--output HDMI-2 --off", "--output eDP-1 --auto --scale 1x1 --primary"])


if __name__ == "__main__":
    unittest.main()
