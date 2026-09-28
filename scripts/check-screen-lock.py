#!/usr/bin/env python3
"""Test the configured locker on private X and D-Bus servers, never the desktop.

Run with Python, python-dbus, python-pygobject, GLib,
Xvfb, xwininfo and the Home xss-lock in PATH. Requires Guix's privileged i3lock.
No suspend or authentication is attempted; a private session Unlock ends locks.
"""
import os
from pathlib import Path
import re
import select
import shlex
import signal
import subprocess
import tempfile
import time

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

ROOT = Path(__file__).resolve().parents[1]
MANAGER = 'org.freedesktop.login1.Manager'
SESSION = 'org.freedesktop.login1.Session'
SESSION_PATH = '/org/freedesktop/login1/session/test'


def pump(seconds):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        while GLib.MainContext.default().pending():
            GLib.MainContext.default().iteration(False)
        time.sleep(0.005)


def until(predicate):
    deadline = time.monotonic() + 5
    while not predicate():
        assert time.monotonic() < deadline, 'Timed out waiting for locker transition'
        pump(0.01)


class Manager(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, '/org/freedesktop/login1')
        self.inhibitors = []

    @dbus.service.method(MANAGER, in_signature='ssss', out_signature='h')
    def Inhibit(self, what, who, why, mode):
        assert (what, mode) == ('sleep', 'delay')
        reader, writer = os.pipe()
        self.inhibitors.append(reader)
        descriptor = dbus.types.UnixFd(writer)
        os.close(writer)
        return descriptor

    @dbus.service.method(MANAGER, in_signature='u', out_signature='o')
    def GetSessionByPID(self, pid):
        return SESSION_PATH

    @dbus.service.method(MANAGER, in_signature='s', out_signature='o')
    def GetSession(self, session):
        return SESSION_PATH

    @dbus.service.signal(MANAGER, signature='b')
    def PrepareForSleep(self, active):
        pass

    def released(self):
        return bool(select.select([self.inhibitors[-1]], [], [], 0)[0])


class Session(dbus.service.Object):
    @dbus.service.method(SESSION, in_signature='b')
    def SetIdleHint(self, idle):
        pass

    @dbus.service.signal(SESSION)
    def Lock(self):
        pass

    @dbus.service.signal(SESSION)
    def Unlock(self):
        pass


def main():
    # Create our own bus even if the caller has a real session bus in its env.
    with tempfile.TemporaryDirectory(prefix='guix-screen-lock-') as directory:
        bus_process = subprocess.Popen(
            ['dbus-daemon', '--session', '--nofork', '--print-address=1'],
            stdout=subprocess.PIPE, text=True)
        processes = [bus_process]
        manager = None
        name = None
        try:
            address = bus_process.stdout.readline().strip()
            dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
            bus = dbus.bus.BusConnection(address)
            name = dbus.service.BusName('org.freedesktop.login1', bus)
            manager = Manager(bus)
            session = Session(bus, SESSION_PATH)
            reader, writer = os.pipe()
            xserver = subprocess.Popen(
                ['Xvfb', '-displayfd', str(writer), '-screen', '0', '800x600x24',
                 '-nolisten', 'tcp'], pass_fds=[writer])
            processes.append(xserver)
            os.close(writer)
            display = ':' + os.read(reader, 100).decode().strip()
            os.close(reader)
            assert re.fullmatch(r':\d+', display)
            env = dict(os.environ, DISPLAY=display,
                       DBUS_SYSTEM_BUS_ADDRESS=address, DBUS_SESSION_BUS_ADDRESS=address,
                       XDG_SESSION_ID='test',
                       PATH=str(ROOT / 'home/przvl/bin') + ':' + os.environ['PATH'])
            line = next(line.strip() for line in (ROOT / 'home/przvl/xinitrc').read_text().splitlines()
                        if line.strip().startswith('start_helper xss-lock '))
            command = shlex.split(line)[1:]
            separator = command.index('--')
            # Delay the real helper to prove sleep waits for readiness rather than
            # merely for successful process creation. The wrapper execs, so it
            # cannot keep an extra inhibitor descriptor alive.
            delayed = Path(directory) / 'delayed-locker'
            delayed.write_text('#!/bin/sh\nsleep 0.4\nexec ' +
                               shlex.join(command[separator + 1:]) + '\n')
            delayed.chmod(0o700)
            command[separator + 1:] = [str(delayed)]
            with open(Path(directory) / 'locker.log', 'w+') as log:
                locker = subprocess.Popen(command, env=env, stdout=log, stderr=log,
                                          start_new_session=True)
                processes.append(locker)

                def mapped():
                    tree = subprocess.check_output(['xwininfo', '-root', '-tree'],
                                                   env=env, text=True)
                    return '"i3lock"' in tree

                until(lambda: len(manager.inhibitors) == 1)
                for cycle in range(3):
                    manager.PrepareForSleep(True)
                    pump(0.15)
                    assert not manager.released(), 'Sleep released before delayed locker was ready'
                    until(manager.released)
                    assert mapped(), 'Sleep released without a lock window'
                    manager.PrepareForSleep(False)
                    until(lambda: len(manager.inhibitors) == cycle + 2)
                    assert mapped(), 'Resume removed the lock window'
                    session.Unlock()
                    until(lambda: not mapped())
                    pump(0.1)  # Let xss-lock reap its child before the next request.
                session.Lock()
                until(mapped)
                manager.PrepareForSleep(True)
                until(manager.released)
                assert mapped(), 'Sleeping while already locked removed the lock'
                session.Unlock()
                until(lambda: not mapped())
                log.seek(0)
                output = log.read()
                assert output.count('reason=sleep') == 3, output
                assert 'reason=session' in output, output
                assert 'WARNING' not in output and 'abnormally' not in output, output
                print('PASS: delayed readiness, three sleep/resume cycles, manual lock, already-locked sleep')
        finally:
            # Release the name while the private bus is still alive.
            if name is not None:
                del name
            for process in reversed(processes):
                if process.poll() is None:
                    if process is processes[-1] and process is not bus_process and manager is not None:
                        # Only locker was started in its own process group.
                        if os.getpgid(process.pid) == process.pid:
                            os.killpg(process.pid, signal.SIGTERM)
                        else:
                            process.terminate()
                    else:
                        process.terminate()
                    process.wait(timeout=5)
            if manager:
                for descriptor in manager.inhibitors:
                    os.close(descriptor)


if __name__ == '__main__':
    main()
