# Zen: finishing the fresh Guix installation

`zen` is the ASUS Zenbook S 14 UX5406SA: Core Ultra 7 258V (Lunar Lake),
Intel Arc 140V integrated graphics, 32 GB RAM, UEFI, and a 2880×1800 120 Hz
OLED panel. The usual external monitor is 2560×1440, up to 144 Hz. These are
user-provided specifications; device IDs and behavior still need verification.
There is no Ethernet port; installation currently works over Wi-Fi with the
Nonguix-capable installer.

## Shared workstation, explicit host differences

Both hosts inherit `base-operating-system`, the `przvl` account, and
`desktop-services`: console login/startx, Xorg, root-managed X socket permissions,
elogind, NetworkManager, screen locking and brightness permissions. Both Home
entrypoints call `make-workstation-home`. They share OXWM's pinned source build,
Lua configuration/keybindings, st/Bash, opaque Picom, Firefox privacy policies,
Xfe, Neovim/nvimide, latest stable Codex runtime packaging, PipeWire, clipboard,
screenshots, status/control helpers and the robust logged X session. Home
updates retain the existing Firefox cache-only and Codex release resolution.

T490 keeps its storage, Intel Wi-Fi-only firmware addition, 79% ThinkPad charge
ceiling, device-specific input configuration, and 1080p/60 external mirroring.
Zen adds a 79% battery charge ceiling and a USB-ID-specific external keyboard
swap; it loads no ThinkPad modules or services.
The shared desktop constructor accepts Xorg modules/drivers as parameters;
its defaults retain the T490 configuration. No hostname branches are used.

Zen requests Xorg's built-in modesetting driver and loads libinput only.
The [Xorg driver documentation](https://cgit.freedesktop.org/xorg/xserver/tree/hw/xfree86/drivers/modesetting/modesetting.man)
describes its KMS/glamor support. No legacy Intel DDX, force-probe kernel
arguments, custom modelines or global DPI overrides are added. Picom's existing
XRender backend is preserved, with VSync enabled to prevent screen tearing.

Home discovers the eDP panel and dock display and mirrors both at 1920×1080:
the internal panel runs at approximately 60 Hz and the external at 120 Hz.
When undocked, it uses 1920×1200 at approximately 60 Hz for readability
(50% larger than native), falling back to the preferred mode if needed. The first connected DP/HDMI output is selected automatically.
On first boot, the connectors were eDP-1 and DP-1-4-4. After each layout
change, the monitor helper refits the wallpaper to the new display geometry.

The attached Gaming Keyboard reports USB ID 1fc9:e8c7. Home applies
`altwin:swap_alt_win` to its physical X keyboard devices at session startup and
on input hotplug, making its Command key Super. The built-in AT keyboard is
untouched. No global/core keyboard map is changed.

The Logitech G502 HERO (USB 046d:c08b) and ASUF1208 touchpad (2808:0218)
use natural scrolling. The touchpad also enables tapping and clickfinger:
one finger left-clicks, two fingers right-click, and three fingers middle-click,
for both taps and physical presses. Home reapplies these at login and reconnect.

Zen exposes `/sys/class/power_supply/BAT0/charge_control_end_threshold`.
The `zen-charge-limit` service, system activation and power-supply udev rule
set it to 79% at boot, every reconfigure, and device add/change events using
the shared threshold writer, without ThinkPad module loading. The system must
be reconfigured to install this service. A ceiling does not actively discharge
a battery already above 79%.

Zen uses a 14-point OXWM bar font and 125% Firefox interface/content scaling
on top of these display modes. Home supplies the bar font separately from the
shared Lua configuration and overlays the Firefox preference on the unchanged
Privacy policies. Firefox reads the policy at startup; the bar font is read when
OXWM starts. These size overrides do not change T490.

## Kernel and firmware

The channel revisions and authenticated introductions stay pinned. Shared
Linux-libre/free firmware defaults are unchanged. Zen explicitly selects:

| Package | Purpose |
| --- | --- |
| Nonguix `linux` (7.2.7 at this pin) | Standard kernel with modern Intel drivers, including Xe and SOF |
| Nonguix `iwlwifi-firmware` | Intel wireless firmware; exact adapter/loaded blob to verify |
| `intel-graphics-firmware` | Intel `i915/` and `xe/` firmware from pinned linux-firmware 20260916 |
| Nonguix `sof-firmware` (2025.12.2) | Intel signed audio DSP firmware and topology, including IPC4 |
| `zen-audio-firmware` | Cirrus CS42L43 codec and CS35L56 amplifier firmware for subsystem 1043:1e13 |
| `%base-firmware` | Same free base firmware as the shared default |

The [Linux Xe firmware table](https://linux.googlesource.com/linux/kernel/git/torvalds/linux/+/2b414a95b8f7307d42173ba9e580d6d3e2bcbfce/drivers/gpu/drm/xe/xe_uc_fw.c)
selects Lunar Lake firmware under `xe/`; Intel display firmware also uses
`i915/`. The pinned Nonguix `i915-firmware` package selects only `i915/`.
Our small derived recipe expands that selection to both directories while
retaining the authenticated channel's source version/hash and installer.
It downloads the upstream source archive but installs only Intel graphics
firmware, not AMD/NVIDIA firmware. A full `linux-firmware` installation is
unnecessary for these known devices and would include unwanted vendors.

[SOF lists Lunar Lake's ACE 2.0 DSP and IPC4 support](https://thesofproject.github.io/latest/platforms/index.html).
The pinned SOF recipe installs Intel firmware/topology directories only. This
boots successfully on Zen, but the first audio diagnosis found no ALSA card:
`cs42l43.bin` was missing and `sof_sdw` remained deferred. Zen now also selects
`zen-audio-firmware` from the same pinned linux-firmware source, including the
CS42L43 image and only the CS35L56 tuning for its verified subsystem 1043:1e13.
The user explicitly authorized this Cirrus exception. Speaker, headset and
microphone operation must be checked after activation and a fresh boot.
Intel Bluetooth firmware and CPU microcode are not added speculatively;
Bluetooth can be addressed after USB IDs and missing-firmware logs are known.
No hibernation/resume configuration or swap sizing policy is introduced.

## Collect after first boot

Keep the installer USB available: an installed Linux-libre generation may lose
the Wi-Fi support that worked in the Nonguix installer. Retain working network
access until the new kernel/firmware generation is built and booted. If the
installed system has no network, use the working installer to collect the
installed configuration from the mounted root and arrange the initial update;
do not assume an Ethernet fallback exists.

Run these on Zen (read-only), and send their output plus `/etc/config.scm`:

```sh
cat /etc/config.scm
lsblk -f
findmnt -o SOURCE,TARGET,FSTYPE,OPTIONS
sudo swapon --show --output NAME,TYPE,SIZE,UUID
sudo blkid
```

The required facts are the root UUID and filesystem type; EFI UUID, FAT type
and actual mount point; each swap UUID or swap-file path (or confirmed no swap);
and any LUKS/LVM/Btrfs mappings, subvolumes, mount options and dependencies.
Keep the installer's complete storage records, not just UUID strings. Check
that the existing account is `przvl` and the EFI bootloader target is correct.
No encryption keys or passwords are needed.

For device identification and firmware diagnostics:

```sh
# Use this if lspci/lsusb are not already installed:
./scripts/guix shell pciutils usbutils -- sh -c 'lspci -nnk; lsusb'
uname -r
nmcli device status
sudo dmesg > zen-dmesg.txt
# Later, inside the first working X session, with and without the monitor:
xrandr --query
```

Still to verify: actual PCI/USB Wi-Fi and Bluetooth IDs, Xe binding and loaded
firmware, audio DSP/codec/amplifier support, sound/microphone/headset routing,
OLED connector/modes/refresh and brightness, external connector/cable modes,
input devices and keyboard function keys, readable HiDPI text, battery sysfs
behavior, suspend/resume and lid handling, graphics stability/tearing, and screen
locking. No ASUS charge policy is assumed. Hardware testing has not occurred.

## Storage guard and applying the configuration

`hosts/zen/hardware.scm` now records the installed layout shown in the user's
first-boot photo on 2026-09-27. The installer configuration agrees with `lsblk`,
`findmnt`, `swapon` and `blkid`:

| Mount/use | Partition | Type | UUID |
| --- | --- | --- | --- |
| `/` | `/dev/nvme0n1p3` | ext4 | `6af180c9-1413-43fe-a3ff-bc31a80220e9` |
| `/boot/efi` | `/dev/nvme0n1p1` | vfat | `F29A-1C24` |
| Existing 3.7 GiB swap | `/dev/nvme0n1p2` | swap | `b637087d-0c1a-493f-8ebb-f342576ee654` |

There are no encrypted/LVM mappings. The `/gnu/store` bind mount is managed by
Guix, not an additional partition. Swap size and behavior are preserved; no
hibernation configuration is added. These UUIDs belong only to this Zen
installation. The guard still rejects missing root/EFI or unspecified storage
lists, and checks now evaluate the real system rather than a storage fixture.

Pull the updated records, build, and then apply on **Zen**:

```sh
cd ~/guix
git pull --ff-only
./scripts/guix repl -L modules scripts/check.scm
./scripts/guix system build -L modules hosts/zen/system.scm
# Only after that build succeeds:
sudo ./scripts/guix system reconfigure -L modules hosts/zen/system.scm
sudo reboot
```

The reboot loads the Nonguix kernel and firmware; keep the previous generation.
After boot, verify `uname -r`, `nmcli device status` and the firmware logs. Connect
using `nmcli --ask device wifi connect "YOUR_SSID"` if needed. Then as `przvl`:

```sh
cd ~/guix
# One-time cache authorization if not already authorized:
sudo guix archive --authorize < sources/nonguix-signing-key.pub
./scripts/guix home build -L modules hosts/zen/home.scm
./scripts/guix home reconfigure -L modules hosts/zen/home.scm
```

Log out and back in to start the Home environment and user services, then run
`startx`. The Home build is independent of the storage guard and may be checked
before the system is ready. Initial graphics/Wi-Fi still require the suitable
kernel/firmware generation. Always use `scripts/guix` so browser and Codex release
resolution stays outside evaluation/activation.

No system or Home activation is performed when preparing this repository.
T490 needs no system reconfiguration for the Zen addition. To install the shared
monitor helper change on T490, run
`./scripts/guix home reconfigure -L modules hosts/t490/home.scm`, then exit X,
log out/back in and run `startx`; its display policy is unchanged.

## Firefox touchpad gestures

Zen's Home environment exports `MOZ_USE_XINPUT2=1` for Firefox on X11.
Two-finger horizontal swipes navigate browser history; pinch gestures zoom
in and out. Firefox handles these natively, including horizontal scrolling
inside scrollable page content. Its default pinch and swipe preferences are
retained, along with the privacy policies and Zen's display scale.

After Home reconfiguration, log out and back in (or reboot after the audio
system update) so the X session and newly started Firefox inherit the setting.
For a test in the existing session, fully quit Firefox and launch it with
`MOZ_USE_XINPUT2=1 firefox`. Opening another window while Firefox is already
running will reuse the old process and its environment.

## Lid-close locking and resume diagnosis

Elogind suspends on an undocked lid close. The X session starts xss-lock with
`--transfer-sleep-lock`: i3lock holds the delay inhibitor until its lock window
is mapped. The original command released the inhibitor on process launch,
allowing sleep to race the locker. Elogind's five-second inhibitor limit still
applies; this handshake cannot guarantee locking if X or the locker is stuck.

The `workstation-lock-screen` helper logs timestamped launches and whether they
came from sleep or a session lock to `~/.local/state/oxwm/session.log`. It execs
`/run/privileged/bin/i3lock` so the privileged PAM path and inhibitor ownership
are preserved. Home reconfiguration installs the change; restart the X session
after saving work to replace the already-running xss-lock process.

On 2026-09-28, the saved log showed suspend at 09:33:11, resume at 13:57:22,
and an orderly power-button shutdown at 13:58:21. The machine remained responsive
below the desktop. Three xss-lock inhibitor timeouts were recorded, but the
available logs do not identify the cause of those timeouts or the frozen desktop.
No GPU hang was recorded during that resume. Do not treat the readiness fix as
proof that the physical resume problem is resolved.

After restarting X, first test `workstation-lock` and unlock normally. Then test
an undocked lid close/resume with work saved. If the desktop freezes, try
Ctrl+Alt+F2 and log in on the console. Before shutting down, capture:

```sh
ps -eo pid,ppid,stat,wchan:30,args > ~/zen-frozen-processes.log
sudo cat /var/log/messages > ~/zen-frozen-messages.log
cp ~/.local/state/oxwm/session.log ~/zen-frozen-session.log
cp ~/.local/share/xorg/Xorg.0.log ~/zen-frozen-xorg.log
```

These preserve the locker/compositor state and sleep timeline for diagnosis.

### Recurrence on 2026-09-29

The saved logs show a lid close at 09:54:42, another xss-lock inhibitor timeout
at 09:54:47, and s2idle resume at 09:55:19 as the Thunderbolt dock appeared.
Wi-Fi reconnected; lid opening and dock removal were processed. The power key
initiated an orderly shutdown at 09:56:13. No GPU hang, panic or OOM kill was
recorded in this interval. USB-C/UCSI errors also occurred, but the logs do not
establish the cause of the unresponsive desktop. The timeout preceded docking;
the earlier locker handoff change did not eliminate it.

The lock helper now starts an independent metadata observer. It closes its copy
of the sleep inhibitor before launching any subprocess, while the main helper
still execs privileged i3lock. After two seconds, and again after a further
15 seconds (which can span suspend), it records process states, bounded X
queries and visible i3lock window IDs if the locker is still running. Reports
are private files in `~/.local/state/oxwm/lock.log` and `lock.previous.log`.
There are no screenshots, window-title dumps, keystrokes or password logging.
This is automatic evidence collection, not a demonstrated freeze fix or a
watchdog that kills the lock. Home reconfiguration installs it; the running
xss-lock resolves the helper on its next launch, so no X restart is needed.
