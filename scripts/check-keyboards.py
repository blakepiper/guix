#!/usr/bin/env python3
"""Check USB-specific keyboard mapping without changing the X server."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class KeyboardTests(unittest.TestCase):
    def test_only_matching_slave_keyboards_are_changed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'workstation').mkdir()
            source = (ROOT / 'hosts/zen/home.scm').read_text()
            (root / 'workstation/keyboard.conf').write_text(
                source.split('#:keyboard-config "')[1].split('"')[0])
            (root / 'xinput').write_text('''#!/bin/sh
if [ "$1" = list ]; then
    echo 'Virtual core keyboard id=3 [master keyboard (2)]'
    echo 'Gaming Keyboard Mouse id=6 [slave  pointer (2)]'
    echo 'Gaming Keyboard id=9 [slave  keyboard (3)]'
    echo 'Gaming Keyboard id=10 [slave  keyboard (3)]'
    echo 'AT Translated Set 2 keyboard id=22 [slave  keyboard (3)]'
else
    case "$2" in
        9|10) echo 'Device Product ID (344): 8137, 59591' ;;
        *) echo 'Device Product ID (344): 1, 1' ;;
    esac
fi
''')
            (root / 'setxkbmap').write_text('''#!/bin/sh
printf '%s\\n' "$*" >> "$TEST_ROOT/calls"
''')
            for name in ('xinput', 'setxkbmap'):
                (root / name).chmod(0o755)
            env = dict(os.environ, XDG_CONFIG_HOME=tmp, TEST_ROOT=tmp,
                       DISPLAY=':999', PATH=tmp + os.pathsep + os.environ['PATH'])
            subprocess.run(['sh', str(ROOT / 'home/przvl/bin/workstation-keyboards')],
                           env=env, check=True)
            self.assertEqual((root / 'calls').read_text().splitlines(), [
                '-device 9 -option  -option altwin:swap_alt_win',
                '-device 10 -option  -option altwin:swap_alt_win'])


if __name__ == '__main__':
    unittest.main()
