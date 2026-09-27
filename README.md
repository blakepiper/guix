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
| `modules/workstation/packages/` | Package recipes for OXWM, Codex, clipboard listener and editor tooling |
| `hosts/t490/system.scm` | T490 composition and input hardware settings |
| `hosts/t490/hardware.scm` | Filesystems and swap, to verify on the actual laptop |
| `hosts/t490/home.scm` | Host display settings |
| `home/przvl/` | Desktop configuration and session helpers |
| `sources/` | Release pins, patches and copied source inputs |
| `scripts/` | Pinned Guix invocation, Codex release refresh and checks |

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

## Application packages

OXWM 0.13.0 remains a pinned source build using the channel's Zig 0.16. Its
recipe replaces the Lua download with a pinned Guix source input and limits
build parallelism to two jobs.

Codex tracks OpenAI's **latest stable release** of
`codex-x86_64-unknown-linux-musl.tar.gz`. Every invocation of
`./scripts/guix home build` or `./scripts/guix home reconfigure` checks
[OpenAI's latest-release API](https://api.github.com/repos/openai/codex/releases/latest)
before evaluating Home. It snapshots the release's version-specific asset URL
and SHA-256 for that command, then Guix verifies the download and installs a
`codex` launcher in the Home profile. There is no Codex compilation or source
preparation command, and no network installer during activation.

The latest-release check requires network access. If it fails, or the latest
release lacks the musl asset or checksum, the Home command stops rather than
silently using an older release. The temporary snapshot is removed afterward;
tracked files stay unchanged. `home build` only builds; `home reconfigure`
activates the resulting generation. Existing generations retain their exact
Codex version and remain available for rollback.

The launcher supplies Guix's bubblewrap and ripgrep on PATH for sandboxing and
search and defaults to upstream's `--no-daemon` mode. Without that option,
0.157.1 tries to provision a background daemon from package metadata absent
from the single-binary archive. Local interactive use and `codex exec` need
no adjacent resources or separate exec binary in standalone mode. Explicit
`--remote` options are passed through without adding `--no-daemon`.
Managed-daemon provisioning and its local agents overview require a complete
upstream package and are not provisioned by this recipe.
The launcher preserves `HOME`, `CODEX_HOME`, authentication and configuration.
No credentials are included. Update Codex through these Guix Home commands,
rather than running Codex's own installer/updater.

Guix/Nonguix and other application pins are unchanged. `sources/releases.json`
retains Codex 0.157.1 as an offline reference for checks and direct package
evaluation; the two Home commands always override it with a fresh upstream
lookup. Calling `guix` directly bypasses this repository wrapper and its refresh.
Each resolved build still uses a fixed URL/hash, so changed asset bytes fail
verification. No recipe edit or repository update is needed for new stable
Codex releases with the same supported distribution layout.

## Check and build

```sh
./scripts/guix repl -L modules scripts/check.scm
./scripts/check-guix-wrapper.sh
./scripts/guix build -L modules -e '(@ (workstation packages oxwm) oxwm-source)'
./scripts/guix build -L modules -e '(@ (workstation packages codex) codex)'
./scripts/guix system build -L modules hosts/t490/system.scm
./scripts/guix home build -L modules hosts/t490/home.scm
git diff --check
```

Evaluation is not a successful build or a hardware test. See
[validation notes](docs/validation.md) for what has actually been checked.

## X11 session startup

Console login followed by `startx` starts the Home-managed `.xinitrc`. It adds
the Guix Home/system profiles to PATH and waits for OXWM. Display setup and
background helpers are optional: failures are logged, and cleanup runs when
OXWM exits. Session output goes to `~/.local/state/oxwm/session.log` (or under
`$XDG_STATE_HOME`), with one previous session retained. There is no dependency
on `~/.xsession-errors` or a display manager.

`Super+Enter` runs `st -e bash` directly through OXWM's logged command launcher.
Home supplies st and interactive Bash; no terminal wrapper is needed. Launch
commands and their inherited stderr go to the session log. Home imports the
desktop helper scripts with executable permissions preserved in the store.
After a terminal/configuration change, run
`./scripts/guix home reconfigure -L modules hosts/t490/home.scm`, exit OXWM
with `Super+Shift+Q`, then run `startx` again. No system reconfigure is needed
for this terminal fix.

Home also provides `ssh-keygen` and the other OpenSSH tools, plus `fastfetch`
from Guix's lightweight `fastfetch-minimal` package. Run `fastfetch` whenever
you want a system summary; it does not run automatically at shell startup.
Interactive Bash loads Guix's ble.sh for syntax highlighting and inline
history/completion suggestions. Press Right at the end of the line to accept
a suggestion. Noninteractive shells and `TERM=dumb` skip ble.sh. After Home
reconfiguration, open a new terminal to load it. SSH keys remain user-managed;
this configuration does not generate keys or enable an SSH server.

The system uses Shepherd and standalone elogind, not systemd. `loginctl` is
elogind's command for locking, suspend and power actions; it is intentional.
The privileged i3lock installed by Guix lives at `/run/privileged/bin/i3lock`.
Elogind normally supplies `/run/user/UID`; if that runtime environment is
missing, the X session uses private temporary helper state and logs a warning.
A fresh console login is still needed for normal Guix Home user services.

Existing installations need this one-time system update to create
`/tmp/.X11-unix` as root at boot and repair existing ownership to `root:root`
with mode 1777. Home cannot manage that root-owned system directory:

```sh
sudo ./scripts/guix system reconfigure -L modules hosts/t490/system.scm
./scripts/guix home reconfigure -L modules hosts/t490/home.scm
# Log out of the console, log back in, then:
startx
```

No reboot or manual socket-directory repair is needed. Later session-script
changes need only Home reconfiguration. Developers can run the isolated shell
regressions with `python3 scripts/check-xsession.py`; no X server is required.

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
No reinstall is required. Home setup is separate from this system-only change.

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
