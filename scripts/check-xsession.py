#!/usr/bin/env python3
"""Exercise the real session script in disposable homes; never start real X."""
import os
from pathlib import Path
import re
import shutil
import shlex
import signal
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SESSION = ROOT / "home/przvl/xinitrc"


class SessionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="guix-xsession-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "home with spaces"
        self.profile = self.home / ".guix-home/profile/bin"
        self.profile.mkdir(parents=True)
        self.control = Path(self.temp.name) / "control"
        self.control.mkdir()
        self.runtime = Path(self.temp.name) / "runtime"
        self.runtime.mkdir(mode=0o700)
        self.tools = Path(self.temp.name) / "tools"
        self.tools.mkdir()
        for name in ("date", "mv", "id", "stat", "mktemp", "mkdir", "rm", "timeout", "sleep"):
            (self.tools / name).symlink_to(shutil.which(name))
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.tools),
                        XDG_STATE_HOME=str(self.home / ".local/state"),
                        XDG_RUNTIME_DIR=str(self.runtime), DISPLAY=":999",
                        TEST_CONTROL=str(self.control), TEST_HELPERS_FAIL="1",
                        TEST_WM_STATUS="0")
        # Never let a missing-runtime test adopt/clean the real login's
        # /run/user/UID. Hide it from validation, even when running on Guix.
        self.script("stat", '''
for arg do case "$arg" in /run/user/*) exit 1 ;; esac; done
exec ''' + shlex.quote(shutil.which("stat")) + ' "$@"\n')
        for name in ("xsetroot", "xset", "alpinews-monitors"):
            self.script(name, 'echo "simulated setup failure: $0" >&2\nexit 23\n')
        for name in ("picom", "alpinews-hotplug", "alpinews-clipwatch", "xss-lock"):
            self.script(name, '''
if [ "$TEST_HELPERS_FAIL" = 1 ]; then echo "simulated helper failure: $0" >&2; exit 19; fi
printf '%s' "$$" > "$TEST_CONTROL/${0##*/}.pid"
trap 'exit 0' TERM INT HUP
while :; do sleep 0.05; done
''')
        self.script("oxwm", '''
printf '%s' "$$" > "$TEST_CONTROL/oxwm.pid"
printf '%s' "$XDG_RUNTIME_DIR" > "$TEST_CONTROL/runtime"
trap 'exit 0' TERM INT HUP
while [ ! -e "$TEST_CONTROL/exit" ]; do sleep 0.05; done
exit "$TEST_WM_STATUS"
''')

    def script(self, name, body):
        path = self.profile / name
        path.write_text("#!/bin/sh\n" + body)
        path.chmod(0o755)

    def start(self):
        self.stderr = (self.control / "stderr").open("w")
        self.addCleanup(self.stderr.close)
        self.process = subprocess.Popen(["/bin/sh", str(SESSION)], env=self.env,
                                        stdout=self.stderr, stderr=self.stderr,
                                        start_new_session=True)
        self.addCleanup(self.stop)
        deadline = time.monotonic() + 5
        while not (self.control / "runtime").exists():
            if self.process.poll() is not None or time.monotonic() > deadline:
                self.fail("OXWM did not start: " + self.logs())
            time.sleep(0.02)
        time.sleep(0.1)  # Give the failing background helpers time to exit.
        self.assertIsNone(self.process.poll(), self.logs())

    def stop(self):
        try:
            os.killpg(self.process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        self.process.wait(timeout=5)

    def logs(self):
        log = self.home / ".local/state/oxwm/session.log"
        return log.read_text() if log.exists() else (self.control / "stderr").read_text()

    def finish(self, expected=0):
        (self.control / "exit").touch()
        self.assertEqual(self.process.wait(timeout=5), expected, self.logs())

    def assert_children_gone(self):
        for file in self.control.glob("*.pid"):
            with self.assertRaises(ProcessLookupError, msg=str(file)):
                os.kill(int(file.read_text()), 0)

    def test_setup_and_helper_failures_leave_wm_running(self):
        self.start()
        self.finish()
        self.assertIn("failed (status 23); continuing", self.logs())
        self.assertIn("simulated helper failure", self.logs())
        self.assertIn(str(self.profile / "oxwm"), self.logs())
        self.assertIn("OXWM exited (status 0)", self.logs())

    def launch_terminal(self):
        config = (ROOT / "home/przvl/config/oxwm/config.lua").read_text()
        binding = re.search(r'oxwm\.key\.bind\(\{ mod \}, "Return", '
                            r'oxwm\.spawn\("([^"\n]+)"\)\)', config)
        self.assertIsNotNone(binding, "Return must use OXWM's logged command path")
        # Exercise the configured command with the real session PATH and output
        # redirection, without touching the user's X server or launching a WM.
        wm = self.profile / "oxwm"
        wm.write_text(wm.read_text().replace(
            'trap ', '/bin/sh -c ' + shlex.quote(binding.group(1)) + '\ntrap ', 1))
        self.start()
        self.finish()

    def test_terminal_uses_profile_st_and_bash_without_wrapper(self):
        self.script("st", 'printf "%s\\n" "$@" > "$TEST_CONTROL/terminal-args"\n')
        self.launch_terminal()
        self.assertEqual((self.control / "terminal-args").read_text(),
                         "-f\nmonospace:size=14\n-e\nbash\n")
        self.assertFalse((self.home / ".local/bin/st-bash").exists())

    def test_terminal_failure_is_logged_and_wm_survives(self):
        self.script("st", 'echo "terminal startup failed" >&2\nexit 127\n')
        self.launch_terminal()
        self.assertIn("terminal startup failed", self.logs())
        self.assertIn("OXWM exited (status 0)", self.logs())

    def test_wm_failure_status_and_cleanup(self):
        self.env.update(TEST_HELPERS_FAIL="0", TEST_WM_STATUS="42")
        (self.runtime / "alpinews-clipboard").mkdir()
        (self.runtime / "alpinews-clipboard/item").touch()
        (self.runtime / "alpinews-cpu").touch()
        (self.runtime / "unrelated").touch()
        self.start()
        self.finish(42)
        self.assert_children_gone()
        self.assertTrue((self.runtime / "unrelated").exists())
        self.assertFalse((self.runtime / "alpinews-clipboard").exists())
        self.assertFalse((self.runtime / "alpinews-cpu").exists())

    def test_missing_runtime_environment(self):
        self.env.pop("XDG_RUNTIME_DIR")
        self.start()
        selected = Path((self.control / "runtime").read_text())
        self.assertEqual(selected.stat().st_mode & 0o777, 0o700)
        self.finish()
        if selected.name.startswith("oxwm-runtime."):
            self.assertFalse(selected.exists())

    def test_invalid_runtime_is_not_cleaned(self):
        self.runtime.chmod(0o755)
        (self.runtime / "alpinews-cpu").touch()
        self.start()
        self.assertNotEqual((self.control / "runtime").read_text(), str(self.runtime))
        self.finish()
        self.assertTrue((self.runtime / "alpinews-cpu").exists())

    def test_signal_cleans_up_wm_and_helpers(self):
        self.env["TEST_HELPERS_FAIL"] = "0"
        self.start()
        self.process.terminate()
        self.assertEqual(self.process.wait(timeout=5), 143, self.logs())
        self.assert_children_gone()

    def test_logging_failure_does_not_stop_session(self):
        invalid = self.home / "not-a-directory"
        invalid.touch()
        self.env["XDG_STATE_HOME"] = str(invalid)
        self.start()
        self.finish()


if __name__ == "__main__":
    unittest.main()
