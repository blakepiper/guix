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
Lua configuration/keybindings, st/Bash, opaque Picom, Firefox/Blix policies,
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
XRender configuration, including its current vsync setting, is preserved.

Home discovers the eDP panel and dock display and mirrors both at 2560×1440:
the internal panel runs at approximately 60 Hz and the external at 144 Hz.
When undocked, it restores 2880×1800 at 120 Hz, falling back to the preferred
mode if needed. The first connected DP/HDMI output is selected automatically.
On first boot, the connectors were eDP-1 and DP-1-4-4.

The attached Gaming Keyboard reports USB ID 1fc9:e8c7. Home applies
`altwin:swap_alt_win` to its physical X keyboard devices at session startup and
on input hotplug, making its Command key Super. The built-in AT keyboard is
untouched. No global/core keyboard map is changed.

Zen exposes `/sys/class/power_supply/BAT0/charge_control_end_threshold`.
The `zen-charge-limit` service and power-supply udev rule set it to 79% using
the shared threshold writer, without ThinkPad module loading. The system must
be reconfigured to install this service. A ceiling does not actively discharge
a battery already above 79%.

## Kernel and firmware

The channel revisions and authenticated introductions stay pinned. Shared
Linux-libre/free firmware defaults are unchanged. Zen explicitly selects:

| Package | Purpose |
| --- | --- |
| Nonguix `linux` (7.2.7 at this pin) | Standard kernel with modern Intel drivers, including Xe and SOF |
| Nonguix `iwlwifi-firmware` | Intel wireless firmware; exact adapter/loaded blob to verify |
| `intel-graphics-firmware` | Intel `i915/` and `xe/` firmware from pinned linux-firmware 20260916 |
| Nonguix `sof-firmware` (2025.12.2) | Intel signed audio DSP firmware and topology, including IPC4 |
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
is the initial audio choice; speaker, headset and microphone routing must be
tested on the actual laptop. No guessed codec/amplifier firmware or quirks are
added. Intel Bluetooth firmware and CPU microcode are not added speculatively;
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
