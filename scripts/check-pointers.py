#!/usr/bin/env python3
"""Verify that natural scrolling only affects the configured USB mouse."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PointerTests(unittest.TestCase):
    def test_mouse_only_and_missing_scroll_property(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'alpinews').mkdir()
            source = (ROOT / 'hosts/zen/home.scm').read_text()
            (root / 'alpinews/pointer.conf').write_text(
                source.split('#:pointer-config "')[1].split('"')[0])
            (root / 'xinput').write_text('''#!/bin/sh
case "$1" in
    list)
        echo 'Virtual core pointer id=2 [master pointer (3)]'
        echo 'Logitech G502 HERO Gaming Mouse id=11 [slave  pointer (2)]'
        echo 'Logitech G502 HERO Gaming Mouse Keyboard id=12 [slave  pointer (2)]'
        echo 'ASUF Touchpad id=16 [slave  pointer (2)]'
        echo 'Logitech G502 HERO Gaming Mouse Keyboard id=24 [slave  keyboard (3)]' ;;
    list-props)
        case "$2" in
            11|12) echo 'Device Product ID (344): 1133, 49291' ;;
            *) echo 'Device Product ID (344): 10248, 536' ;;
        esac
        [ "$2" = 12 ] || echo 'libinput Natural Scrolling Enabled (314): 0' ;;
    set-prop) printf '%s\\n' "$*" >> "$TEST_ROOT/calls" ;;
esac
''')
            (root / 'xinput').chmod(0o755)
            env = dict(os.environ, XDG_CONFIG_HOME=tmp, TEST_ROOT=tmp,
                       DISPLAY=':999', PATH=tmp + os.pathsep + os.environ['PATH'])
            subprocess.run(['sh', str(ROOT / 'home/przvl/bin/alpinews-pointers')],
                           env=env, check=True)
            self.assertEqual((root / 'calls').read_text().splitlines(),
                             ['set-prop 11 libinput Natural Scrolling Enabled 1'])


if __name__ == '__main__':
    unittest.main()
