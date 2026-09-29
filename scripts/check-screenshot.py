#!/usr/bin/env python3
"""Check screenshot selection on private X only.

Requires Xvfb, Picom, scrot, xdotool, xwininfo, xsetroot and xclip in PATH.
Put the built scrot-mirrored bin directory first. Picom's VSync is disabled
only in this virtual-display test: Xvfb lacks physical vblank timing.
"""
import os, subprocess as s, tempfile, time, struct
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

with tempfile.TemporaryDirectory(prefix='screenshot-check-') as d:
    home=Path(d); processes=[]
    r,w=os.pipe()
    x=s.Popen(['Xvfb','-displayfd',str(w),'-screen','0','800x600x24','-nolisten','tcp'],pass_fds=[w]); processes.append(x)
    os.close(w); display=':'+os.read(r,100).decode().strip(); os.close(r)
    env=dict(os.environ,DISPLAY=display,HOME=d)
    try:
        p=s.Popen(['picom','--no-vsync','--config',str(ROOT / 'home/przvl/config/picom.conf')],env=env); processes.append(p)
        time.sleep(.5)
        assert p.poll() is None
        s.run(['xsetroot','-solid','#223344'],env=env,check=True)
        cap=s.Popen([str(ROOT / 'home/przvl/bin/screenshot-region')],env=env); processes.append(cap)
        time.sleep(.3)
        s.run(['xdotool','mousemove','100','100','mousedown','1','mousemove','320','260'],env=env,check=True)
        for x,y in [(450,400),(270,300),(320,260)]:
            s.run(['xdotool','mousemove',str(x),str(y)],env=env,check=True)
            time.sleep(.15)
        time.sleep(.4)
        tree=s.check_output(['xwininfo','-root','-tree'],env=env,text=True)
        assert '"scrot"' in tree, tree
        # A second X client can capture while dragging: the server/compositor
        # remain responsive, unlike the server-grabbing freeze path.
        s.run(['scrot','--overwrite',str(home / 'outline.ppm')],env=env,check=True,timeout=3)
        with (home / 'outline.ppm').open('rb') as image:
            def header():
                line = image.readline()
                while line.startswith(b'#'):
                    line = image.readline()
                return line.strip()
            assert header() == b'P6'
            assert header() == b'800 600'
            assert header() == b'255'
            pixels = image.read()
        def pixel(x, y):
            offset = (y * 800 + x) * 3
            return tuple(pixels[offset:offset + 3])
        for point in [(98, 150), (200, 98), (321, 150), (200, 261)]:
            assert pixel(*point) == (187, 187, 187), ('Missing border', point, pixel(*point))
        for point in [(449, 200), (200, 399), (269, 280)]:
            assert pixel(*point) == (0, 0, 0), ('Selection trail', point, pixel(*point))
        s.run(['xdotool','mouseup','1'],env=env,check=True)
        assert cap.wait(timeout=5)==0
        files=list((home/'Pictures/Screenshots').glob('*.png'))
        assert len(files)==1
        width,height=struct.unpack('>II',files[0].read_bytes()[16:24])
        assert (width,height)==(220,160),(width,height)
        copied=s.check_output(['xclip','-selection','clipboard','-t','image/png','-o'],env=env,timeout=3)
        assert copied==files[0].read_bytes()
        cap=s.Popen([str(ROOT / 'home/przvl/bin/screenshot-region')],env=env); processes.append(cap)
        time.sleep(.3)
        s.run(['xdotool','key','Escape'],env=env,check=True)
        cap.wait(timeout=5)
        assert len(list((home/'Pictures/Screenshots').glob('*.png')))==1
        assert not list((home/'Pictures/Screenshots').glob('.capture.*'))
        print('PASS: four visible borders after resizing, no stale trails, responsive X during drag, 220x160 PNG, clipboard bytes, cancellation cleanup')
    finally:
        for p in reversed(processes):
            if p.poll() is None:
                p.terminate(); p.wait(timeout=5)
