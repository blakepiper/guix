# Guix workstation

GNU-first Guix System and Guix Home configuration, initially for Blake's ThinkPad
T490. AlpineWS supplies the desktop conventions; Blix supplies the separation of
shared modules, user configuration, and machine-specific facts.

The desktop uses Xorg, OXWM, **Picom with fully opaque windows**, st, LibreWolf,
Xfe, Neovim and PipeWire. Log in on a console and run `startx`. There is no display
manager, automatic login, or proprietary browser DRM. The T490 has an explicit
Intel Wi-Fi exception described below.
GNU libc, GNU command-line tools, Bash and Shepherd replace Alpine's musl,
BusyBox and OpenRC. Elogind manages seats, power actions and suspend inhibition.

## Organization

| Path | Responsibility |
| --- | --- |
| `channels.scm` | Pinned authenticated Guix and Nonguix channels |
| `modules/workstation/system/` | Shared OS, desktop services, reusable ThinkPad battery service |
| `modules/workstation/home/` | Shared user applications and Guix Home services |
| `modules/workstation/packages/` | Source recipes for OXWM, Codex, clipboard listener and editor tooling |
| `hosts/t490/system.scm` | T490 composition and input hardware settings |
| `hosts/t490/hardware.scm` | Filesystems and swap, to verify on the actual laptop |
| `hosts/t490/home.scm` | Host display settings |
| `home/przvl/` | Desktop configuration and session helpers |
| `sources/` | Release pins, patches and ignored generated source archive |
| `scripts/` | Pinned Guix invocation, preparation and evaluation |

To add a host, create `hosts/NAME/{system,hardware,home}.scm` and compose the same
shared modules. Keep disk identities, display connectors, battery behavior and
input-device exceptions in the host files. Do not copy the T490's hardware facts
or add hostname tests to shared modules.

## Freedom and hardware

Shared defaults select Linux-libre and Guix's free base firmware. The T490 alone
uses Nonguix's standard Linux and adds `iwlwifi-firmware` for its built-in Intel
wireless adapter, an explicit nonfree exception requested for this host. This
package contains firmware for multiple Intel Wi-Fi models, not one device blob.
Adding the channel does not change other hosts' kernel or firmware defaults.

The exception adds no full `linux-firmware` bundle, CPU microcode, Bluetooth
firmware or GPU firmware. Bluetooth, video acceleration and other firmware-dependent
functions still need testing. Picom uses XRender to avoid requiring working
accelerated OpenGL. See the
[Nonguix instructions](https://github.com/nonguix/nonguix#installation).

The T490 still has proprietary platform firmware; installing Guix cannot make
that hardware fully free. Omitting microcode also forgoes OS-delivered CPU fixes.
See the [GNU Guix hardware considerations](https://guix.gnu.org/manual/en/html_node/Hardware-Considerations.html).

Codex's Apache-2.0 CLI is free software. Its hosted model service is a separate
compromise with [GNU's position on service-based computing](https://www.gnu.org/philosophy/who-does-that-server-really-serve.html).
No login credentials or hosted provider configuration are included here.
LibreWolf is installed with its defaults, without imported Firefox policies.

## Source builds

As checked on 2026-09-26, the latest stable tags are
[OXWM v0.13.0](https://github.com/tonybanters/oxwm/tree/v0.13.0) and
[Codex rust-v0.157.1](https://github.com/openai/codex/releases/tag/rust-v0.157.1).
The recipes build their source, with substitutes disabled for these two outputs.
Normal Guix packages supply their compilers and libraries; their substitutes
remain available. The channel provides Zig 0.16. Its discoverable `rust` is
1.93.0, but it also defines the hidden `rust-1.95` package used by Codex.
The preparation manifest selects that package and its Cargo output directly,
matching the build recipe and upstream's Rust 1.95.0 toolchain pin. Rust 1.93
is insufficient: the locked SQLx 0.9.0 dependency requires at least 1.94.

Prepare Codex's locked sources before building Home:

```sh
cd ~/guix
./scripts/guix shell -m scripts/codex-manifest.scm -- \
  python3 scripts/prepare-codex.py
```

The script verifies the upstream tarball SHA-256, adjusts only local workspace
versions left stale by upstream release tagging, and runs `cargo vendor --locked`.
The resulting ignored archive contains sources, not compiled binaries. Keep it
with your installation media if installing offline. Vendored sources need about
2 GB unpacked; Rust builds need substantially more space and RAM. Both recipes
limit build parallelism to two jobs for the laptop.

Guix imports that archive into its content-addressed store and builds with
`cargo --frozen` in the offline sandbox. The recipe temporarily moves the vendor
directory outside the source tree during GNU source-rewriting phases, then
restores it before Cargo runs. This preserves Cargo's original checksums while
retaining shebang handling for other sources and installed files. Existing
prepared archives do not need regeneration for this recipe change.
The optional V8 code-mode host is not
included; ordinary CLI/exec binaries and the daemon package layout are included.
Do not enable features requiring that optional host until a source recipe exists.

Tags and hashes never refresh at activation time. For updates, check upstream's
stable tags, review the new source and build requirements, update
`sources/releases.json` and the matching Scheme recipes, regenerate the archive,
and rerun the checks and builds. Do not replace pins with moving `latest` URLs.

## Check and build

```sh
./scripts/guix repl -L modules scripts/check.scm
./scripts/guix shell bash coreutils file tar gzip -- \
  ./scripts/guix repl -L modules scripts/check-codex-vendor.scm
./scripts/guix build -L modules -e '(@ (workstation packages oxwm) oxwm-source)'
./scripts/guix build -L modules -e '(@ (workstation packages codex) codex-source)'
./scripts/guix system build -L modules hosts/t490/system.scm
./scripts/guix home build -L modules hosts/t490/home.scm
git diff --check
```

Evaluation is not a successful build or a hardware test. See
[validation notes](docs/validation.md) for what has actually been checked.
The vendor regression check unpacks a temporary copy of the prepared archive
(allow about 2 GB), verifies Cargo's recorded file checksums, and runs the
recipe's pre-build phases. It checks that vendor bytes remain unchanged and
that non-vendored source/generated scripts still receive shebang fixes. It
does not compile Codex or replace the daemon-backed package/Home builds.

## Install on the T490

Back up the laptop first. Boot an official Guix installer in UEFI mode using a
working network connection. This repository does not partition or format disks.
Follow the [Guix installation manual](https://guix.gnu.org/manual/en/html_node/System-Installation.html)
to prepare and mount your intended filesystems at `/mnt` and `/mnt/boot/efi`.

Before initialization, verify `lsblk -f` against `hosts/t490/hardware.scm`.
The configuration expects an ext4 root labelled `guix-root` and a FAT EFI system
partition labelled `GUIX_EFI`. These are an explicit installation layout, not
detected facts. Replace them with verified UUIDs if retaining existing volumes.
Do not reuse Blix's historical UUIDs blindly. Swap and disk encryption are not
configured; add verified storage mappings if you want them before installation.

With the checkout and source archive available, from its directory:

```sh
# As root in the installer, after verifying the mounted target:
./scripts/guix system init -L modules hosts/t490/system.scm /mnt
```

Follow the installer's password/account completion steps before rebooting. On
first boot set the `przvl` password from the root console if not already set:
`passwd przvl`. Then log in as `przvl` and apply Home:

```sh
cd ~/guix
./scripts/guix home reconfigure -L modules hosts/t490/home.scm
# Log out and back in so the Guix Home environment and user services are active.
startx
```

### Finishing an official installer installation

Finish installing over Ethernet and boot the installed system. Selecting
Linux-libre in the installer is fine; reconfiguration can change the kernel later.
Clone or update this repository, then **adapt `hosts/t490/hardware.scm` to the
actual filesystems, swap and any encrypted-device mappings in the installer's
generated `/etc/config.scm`**. Verify with `lsblk -f`; the example labels in this
repository must not replace your actual storage identities. Also check the user
account and EFI mount point before applying this configuration.

From the checkout, while still connected by Ethernet:

```sh
./scripts/guix system build -L modules hosts/t490/system.scm
sudo ./scripts/guix system reconfigure -L modules hosts/t490/system.scm
sudo reboot
```

Boot the new generation, then check `nmcli device status` and
`nmcli device wifi list`. Connect with
`nmcli --ask device wifi connect "YOUR_SSID"`. The kernel changes after reboot;
the running installer is unaffected. Keep Ethernet until Wi-Fi is verified.
No reinstall is required. Home setup and Codex source preparation are separate
from this system-only change.

Subsequent system changes use:

```sh
sudo ./scripts/guix system reconfigure -L modules hosts/t490/system.scm
```

Use the Home reconfigure command above for user configuration. Retain the previous
boot generation. Never run `system init` as an update command.

Test display/mirroring, audio, microphone, brightness, screen lock, lid suspend
and resume on the laptop. `cat /sys/class/power_supply/BAT*/charge_control_end_threshold`
should show `79` after boot and power events. No forced discharge is requested.
Missing firmware support means this threshold is not guaranteed.

## Desktop notes

Super+Enter opens st, Super+B opens LibreWolf, Super+F opens Xfe, Super+L locks,
Super+Shift+Space opens the power menu, and Super+Shift+Q exits X. The OXWM
palette, dwindle layout, nine tags, gaps, screenshots and clipboard history come
from AlpineWS/Blix. Picom starts and stops with X; it has no transparency,
shadows or fading. PipeWire runs as Guix Home services for the login session.

Neovim uses the complete current local Blix configuration: LazyVim, the Seafoam
theme, Snacks explorer, and the plugin lockfile. Run `nvimide [directory] [files…]`
to open Blix's explorer and two terminal panes. Ordinary `nvim` retains its normal
startup. The launcher and configuration are copied into this repository; a
sibling Blix checkout is not needed on the T490.

The separate `lua/plugins/guix.lua` adaptation disables Mason binary downloads
and uses Guix's `lua-language-server`. Blink uses its Lua fuzzy matcher. Lua
formatting falls back to the language server because the pinned official Guix
channel has no StyLua package; `shfmt` is installed for shell formatting. The
upstream configuration and lockfile otherwise remain unchanged. Lazy.nvim still
downloads plugin source on first launch and checks for updates, and Tree-sitter
compiles missing parsers using the installed CLI and GCC. Tree-sitter
CLI 0.26.1 is built from source by a local recipe because Blix's pinned plugin
requires it and the channel's CLI is only 0.25.3. These user-level
plugin updates are separate from Guix generations. Blix already keeps Lazy's
working lockfile in the writable state directory, so the read-only Guix store
does not prevent updates. Optional Lazygit shortcuts require a separately
packaged Lazygit; it is absent from the pinned official channel.

This port still uses packaged st. Alpine's Zig wrappers, ble.sh nightly installer
and Firefox customization are not carried over. Attribution is in
[sources](docs/sources.md).
