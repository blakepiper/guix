#!/usr/bin/env python3
"""Verify scrolling and two-finger clicks target only configured devices."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PointerTests(unittest.TestCase):
    def test_selected_pointers_and_missing_scroll_property(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'workstation').mkdir()
            source = (ROOT / 'hosts/zen/home.scm').read_text()
            (root / 'workstation/pointer.conf').write_text(
                source.split('#:pointer-config "')[1].split('"')[0])
            (root / 'xinput').write_text('''#!/bin/sh
case "$1" in
    list)
        echo 'Virtual core pointer id=2 [master pointer (3)]'
        echo 'Logitech G502 HERO Gaming Mouse id=11 [slave  pointer (2)]'
        echo 'Logitech G502 HERO Gaming Mouse Keyboard id=12 [slave  pointer (2)]'
        echo 'Unrelated Mouse id=17 [slave  pointer (2)]'
        echo 'ASUF Mouse id=15 [slave  pointer (2)]'
        echo 'ASUF Touchpad id=16 [slave  pointer (2)]'
        echo 'Logitech G502 HERO Gaming Mouse Keyboard id=24 [slave  keyboard (3)]' ;;
    list-props)
        case "$2" in
            11|12) echo 'Device Product ID (344): 1133, 49291' ;;
            15|16) echo 'Device Product ID (344): 10248, 536' ;;
            *) echo 'Device Product ID (344): 1, 2' ;;
        esac
        if [ "$2" = 16 ] || [ "$2" = 17 ]; then
            echo 'libinput Tapping Enabled (354): 0'
            echo 'libinput Tapping Button Mapping Enabled (360): 0, 1'
            echo 'libinput Click Method Enabled (365): 1, 0'
            echo 'libinput Clickfinger Button Mapping Enabled (367): 0, 1'
        fi
        [ "$2" = 12 ] || echo 'libinput Natural Scrolling Enabled (314): 0' ;;
    set-prop) printf '%s\\n' "$*" >> "$TEST_ROOT/calls" ;;
esac
''')
            (root / 'xinput').chmod(0o755)
            env = dict(os.environ, XDG_CONFIG_HOME=tmp, TEST_ROOT=tmp,
                       DISPLAY=':999', PATH=tmp + os.pathsep + os.environ['PATH'])
            subprocess.run(['sh', str(ROOT / 'home/przvl/bin/workstation-pointers')],
                           env=env, check=True)
            self.assertEqual((root / 'calls').read_text().splitlines(),
                             ['set-prop 11 libinput Natural Scrolling Enabled 1',
                              'set-prop 15 libinput Natural Scrolling Enabled 1',
                              'set-prop 16 libinput Natural Scrolling Enabled 1',
                              'set-prop 16 libinput Tapping Enabled 1',
                              'set-prop 16 libinput Tapping Button Mapping Enabled 1 0',
                              'set-prop 16 libinput Click Method Enabled 0 1',
                              'set-prop 16 libinput Clickfinger Button Mapping Enabled 1 0'])


if __name__ == '__main__':
    unittest.main()
