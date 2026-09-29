![Guix logo](docs/images/guix-logo.png)

# Guix workstation

One shared Guix System and Guix Home configuration for two laptops: a Lenovo
ThinkPad T490 (`t490`) and an ASUS Zenbook S 14 (`zen`). Both use the `przvl`
account and the same OXWM desktop, with storage, firmware, displays and input
settings kept in each host's configuration.

Log in on a console and run `startx`. The desktop includes Xorg, OXWM, opaque
Picom, st with Bash and ble.sh, Firefox, Xfe, Neovim/LazyVim and PipeWire.
NetworkManager manages connections and DNS; Shepherd manages system services
and elogind handles seats and power actions. There is no display manager or
automatic login.

## Hosts

These are configurations for the two recorded installations, not generic
hardware profiles. Their filesystem and swap UUIDs belong to those machines.

| | ThinkPad T490 | Zenbook S 14 |
| --- | --- | --- |
| Host directory | [`hosts/t490/`](hosts/t490/) | [`hosts/zen/`](hosts/zen/) |
| System entrypoint | [`system.scm`](hosts/t490/system.scm) | [`system.scm`](hosts/zen/system.scm) |
| Home entrypoint | [`home.scm`](hosts/t490/home.scm) | [`home.scm`](hosts/zen/home.scm) |
| Kernel | Nonguix Linux | Nonguix Linux |
| Added firmware | Intel Wi-Fi | Intel Wi-Fi, i915/Xe graphics and SOF audio |
| Display policy | eDP-1/HDMI-2 mirroring at 1920×1080, 60 Hz | Automatic connectors; 1920×1080 mirroring at 60 Hz internal / 120 Hz external; 1920×1200 at 60 Hz undocked |
| Desktop sizing | Shared defaults | 14-point bar font and 125% Firefox scaling |
| Battery ceiling | 79%, ThinkPad service | 79%, generic sysfs service |
| Setup guide | [T490 installation](docs/t490.md) | [Zen installation and hardware notes](docs/zen.md) |

Zen uses Xorg's modesetting driver. Its Home helpers reapply the external
keyboard's Alt/Super swap and mouse/touchpad settings when devices reconnect.
T490 declares its input settings through Xorg. Display modes fall back when
unavailable; configured behavior still needs verification on the hardware.

Shared system defaults remain Linux-libre and free firmware. The standard
Linux kernel and firmware above are explicit host exceptions from the pinned,
authenticated Nonguix channel. Neither host adds AMD/NVIDIA firmware, a full
linux-firmware bundle, CPU microcode or Intel Bluetooth firmware.

## Update and switch

The full update sequence is **refresh pins → reconfigure system and Home →
reboot when needed → share the pins with the other laptop**. If
`./scripts/update` has already succeeded, continue at step 2.

Run commands from the checkout on the host being updated. Use `sudo` for system
reconfiguration and your normal `przvl` account for Home. **Always use
`./scripts/guix`**: it selects this repository's channels and resolves Firefox
and Codex before Home evaluation.

Before the first Home build or reconfiguration on either machine, authorize
the checked-in Nonguix substitute signing key if it is not already authorized:

```sh
cd ~/guix
sudo guix archive --authorize < sources/nonguix-signing-key.pub
```

This trusts the key for substitutes generally, not just Firefox. Substitute
signatures and channel source authentication are separate. The wrapper supplies
the Firefox cache URL even before the first system reconfiguration.

### 1. Refresh the channel pins

Run as your normal user, starting from a checkout with any previous local work
saved before pulling:

```sh
cd ~/guix && \
  git pull --ff-only && \
  ./scripts/update
```

After it succeeds, review the selected revisions:

```sh
git diff -- channels.scm
```

`./scripts/update` fetches the latest revisions on the configured Guix/Nonguix
branches, authenticates them, and evaluates both hosts before saving the pins
in `channels.scm`. Fetch, authentication or evaluation failures preserve the
existing pins. It rejects backward or divergent updates and unexpected channel
metadata/dependencies, and refuses to overwrite a concurrent edit to the file.
If the pins are already current, their file contents stay unchanged.

This step needs network access and may download or build Guix's tooling, but
it **does not switch the running system or Home environment**. Its evaluation
uses the offline Firefox/Codex records. It does not build either host's complete
environment, update your personal Guix profile, commit, or push.

### 2. Build and switch system and Home

Once the refresh succeeds, run the pair of commands for the laptop you are on.
There is no need to run `./scripts/update` again before switching.

#### T490

On the installed T490:

```sh
cd ~/guix && \
  sudo ./scripts/guix system reconfigure -L modules hosts/t490/system.scm && \
  ./scripts/guix home reconfigure -L modules hosts/t490/home.scm
```

#### Zen

On the installed Zenbook:

```sh
cd ~/guix && \
  sudo ./scripts/guix system reconfigure -L modules hosts/zen/system.scm && \
  ./scripts/guix home reconfigure -L modules hosts/zen/home.scm
```

`system reconfigure` builds and activates the declared OS and selects the new
boot generation. `home reconfigure` builds and activates user applications,
configuration and services, including freshly resolved Firefox and Codex.
**Both are needed for a full workstation update.** For a Home-only change, run
just your host's Home command, without `sudo`.

A separate build step is optional: each reconfigure builds its environment
before activating it. To inspect a build before switching, replace
`reconfigure` with `build` and omit `sudo`, then run reconfigure when ready.
Home reconfigure resolves Firefox/Codex again, so their releases may have
advanced since a previous Home build.

The command chains stop on failure. System and Home are separate generations:
if Home fails after the system succeeds, the system change remains applied.
Fix the reported error and rerun the Home command.

### 3. Restart into the updated environment

After both reconfigurations succeed, reboot when ready to load a changed kernel
and boot-time firmware and start a fresh session:

```sh
sudo reboot
```

After boot, log in as `przvl` and run `startx`. For Home/session changes alone,
you can instead exit OXWM, log out of the console, log back in and run `startx`.
Restart applications to use their updated versions. None of the update commands
reboots automatically.

### 4. Share the pins with the other laptop

The refreshed `channels.scm` is a local working-tree change until you commit
and push it. After reviewing the diff and validating the update, record it:

```sh
git add channels.scm
git commit -m "Update Guix and Nonguix channel pins"
git push
```

Skip that commit if there is no pin change. Before sharing new pins, use the
[build commands](#checks-and-builds) to check both hosts; evaluation alone does
not establish that either host builds or boots.

On the other laptop, run `git pull --ff-only` from `~/guix`, then follow steps 2
and 3 for that host. **Skip `./scripts/update` there to use the same shared
channel revisions**; running it again may select newer ones. Firefox and Codex
still resolve independently at each Home build/reconfigure.

### Which versions get installed?

A channel is a Git repository of Guix package recipes and related system code.
[`channels.scm`](channels.scm) records exact Guix and Nonguix commits, and the
wrapper runs `guix time-machine` against them. Reconfiguration uses those
versions; it does not automatically advance the whole OS to upstream's latest.

| Component | Update policy |
| --- | --- |
| OS and channel-provided packages | Versions at the commits in `channels.scm` |
| OXWM and other local source recipes | Explicit versions and hashes in `modules/workstation/packages/` |
| Firefox | Newest successful stable x86_64 release available among the cache's latest 100 Firefox builds |
| Codex | Latest official stable Linux x86_64 musl runtime at each Home build/reconfigure |
| Neovim plugins and Firefox extensions | Their own user-level update mechanisms, outside Guix generations |

`git pull` retrieves configuration changes and any channel pins committed to
this repository. A separate `guix pull` updates your user's Guix; it does not
change the wrapper's pins. `guix upgrade` updates an imperative package profile,
not the declared system or Home environment.

Refreshing the channel pins is comparable to updating Nix inputs in a lockfile
before rebuilding and switching. Local source recipes still need their own
version/hash updates.

### Rollback

Keep a working previous generation. If a new system will not boot, select an
older generation from the bootloader menu. To select the previous system for
boot or independently restore the previous Home generation:

```sh
# System rollback; reboot afterward to run the previous system fully.
sudo ./scripts/guix system roll-back

# Home rollback; start a fresh login session afterward.
./scripts/guix home roll-back
```

Roll back whichever environment needs recovery. These commands do not restore
personal files, application data or the Git checkout. Never use `system init`
as an update command.

## First-time setup

Start with the appropriate [T490](docs/t490.md) or [Zen](docs/zen.md) guide.
Before applying a system configuration, compare its `hardware.scm` with the
installed `/etc/config.scm`, `lsblk -f` and mounted filesystems. Preserve actual
storage identities and any encrypted-device mappings. This repository does not
partition or format disks.

Build the matching system before activating it. Apply Home as `przvl`, then
log out and back in before running `startx`. The Zen system entrypoint rejects
incomplete storage records. Neither host's recorded UUIDs should be reused for
a different installation.

## Using the desktop

| Shortcut | Action |
| --- | --- |
| `Super+Enter` | Open st with Bash, 14-point font |
| `Super+B` | Open Firefox |
| `Super+F` | Open Xfe with a dark color palette |
| `Super+L` | Lock the screen |
| `Super+Shift+Space` | Open the power menu |
| `Super+Shift+Q` | Exit OXWM |

Picom uses XRender with fully opaque windows, no fading and no shadows.
Xfe's FOX color palette is managed in `home/przvl/config/xfe/xferc`, independently
of GTK themes. Restart Xfe after Home reconfiguration to load the colors.
Radicle's `rad`, `git-remote-rad` and `radicle-node` commands come from the pinned
Guix `radicle` package in Home. Installation does not create a Radicle identity
or start a node automatically.
PipeWire runs through Guix Home. Interactive Bash loads ble.sh for highlighting
and history/completion suggestions; press Right at the end of the line to
accept a suggestion.

Run `nvimide [directory] [files…]` for the IDE layout with its explorer
and two terminal panes, or `nvim` for normal startup.
Both editor modes use the `minimal` theme: st's black
background and light gray text, colored syntax, grayscale panels, and muted
diagnostic and Git accents. Embedded terminals use st's ANSI palette.
The copied LazyVim
configuration uses Guix's language server and build tools, disables Mason binary
downloads, and uses Blink's Lua fuzzy matcher. Lazy.nvim downloads plugin sources
and Tree-sitter compiles missing parsers; their writable state is outside the
Guix store.

Use `gammastep -O 2500` for a warmer screen and `gammastep -x` to reset it.
`fastfetch` displays a system summary. OpenSSH client tools, including
`ssh-keygen`, are installed; keys remain user-managed and no SSH server is
configured here.

## Browser and Codex updates

Firefox keeps the privacy policies: strict tracking protection, Global Privacy
Control, blocked AI features and sponsored content, and managed uBlock Origin,
Dark Reader and Enhancer for YouTube extensions. Inspect `about:policies` for
the active policy set. The existing browser profile remains user-managed;
proprietary browser DRM is not enabled.

Before Home evaluation, the wrapper checks Mozilla's published stable release
histories and fetches the selected Firefox store output and runtime closure
from the signed Nonguix cache. Local compilation and offloading are disabled;
missing metadata, untrusted signatures or unavailable downloads abort the Home
command. There is no Firefox source-build fallback. Nonguix's unbranded stable
browser can display “Nightly”; selection is based on published release versions,
not that label.

Codex resolution snapshots the latest stable release's versioned URL and SHA-256
for the complete official musl runtime bundle. Guix verifies and packages it;
there is no network installer during activation. Resolution failures stop the
Home command. The launcher defaults to `--no-daemon`, passes explicit `--remote`
options through, and preserves existing authentication and configuration. No
credentials are included in this repository.

Both lookups require network access and happen on **every** Home build and
reconfigure, so a later reconfigure can resolve newer releases than an earlier
build. Existing generations retain their resolved versions. The checked-in
Firefox and Codex release records support offline evaluation only; they are
not fallback versions for Home updates. Use the Home wrapper to update these
applications.

## Checks and builds

From the repository root, evaluate both hosts and exercise the wrapper:

```sh
./scripts/guix repl -L modules scripts/check.scm
./scripts/check-guix-wrapper.sh
./scripts/check-update.sh
./scripts/guix repl scripts/check-update-channels.scm
git diff --check
```

Build each host without activating it:

```sh
./scripts/guix system build -L modules hosts/t490/system.scm
./scripts/guix home build -L modules hosts/t490/home.scm
./scripts/guix system build -L modules hosts/zen/system.scm
./scripts/guix home build -L modules hosts/zen/home.scm
```

For local package and session-helper changes, run the relevant checks:

```sh
./scripts/guix build -L modules -e '(@ (workstation packages oxwm) oxwm-source)'
./scripts/guix build -L modules -e '(@ (workstation packages codex) codex)'
./scripts/guix shell python shellcheck -- sh -c \
  'python3 scripts/check-monitors.py &&
   python3 scripts/check-xsession.py &&
   python3 scripts/check-keyboards.py &&
   python3 scripts/check-pointers.py &&
   shellcheck home/przvl/bin/workstation-monitors'
```

Run ShellCheck on any other changed shell scripts as well. Use `-L modules`,
not `-L .`, so package discovery does not evaluate host entrypoints as package
modules. Evaluation is not a build or boot test; the dated
[validation record](docs/validation.md) distinguishes checks, builds and remaining
hardware verification.

On Guix System with the Home tools and privileged i3lock installed, test locking
on a private X server and private D-Bus without locking or suspending the desktop:

```sh
./scripts/guix shell python python-dbus python-pygobject glib xorg-server dbus xwininfo -- \
  python3 scripts/check-screen-lock.py
```

## Troubleshooting and reference

| Need | Where to look |
| --- | --- |
| X session or application startup failures | `~/.local/state/oxwm/session.log`, or `$XDG_STATE_HOME/oxwm/session.log` |
| Connectivity works but DNS fails | [NetworkManager DNS ownership and migration](docs/networking.md) |
| T490 installation and Wi-Fi setup | [T490 guide](docs/t490.md) |
| Zen storage, firmware and peripherals | [Zen guide](docs/zen.md) |
| What has actually been tested | [Validation record](docs/validation.md) |
| Imported sources and implementation decisions | [Sources and port decisions](docs/sources.md) |

The X session retains one previous log. Display and background-helper failures
are logged without ending OXWM. If an older installation has X socket ownership
problems, apply the host's system configuration: the shared system service
creates and repairs `/tmp/.X11-unix`. Home alone cannot repair that root-owned
directory.

## Repository layout

| Path | Responsibility |
| --- | --- |
| `channels.scm` | Authenticated Guix and Nonguix revision pins |
| `hosts/<name>/` | System/Home composition, installed storage and hardware policy |
| `modules/workstation/system/` | Shared OS, desktop and battery services |
| `modules/workstation/home/` | Shared applications and user services |
| `modules/workstation/packages/` | Local package recipes and adaptations |
| `home/przvl/` | Desktop configuration and session helpers |
| `scripts/` | Pinned Guix wrapper, channel updater, release resolvers and checks |
| `sources/` | Release reference records, signing key, patches and copied inputs |
| `docs/` | Host guides, troubleshooting, provenance and validation |

To add a host, compose the shared modules through
`hosts/NAME/{system,hardware,home}.scm`. Keep disk identities, display settings,
battery behavior and input exceptions in that directory. Shared modules accept
host parameters; they should not branch on hostname.

Desktop helpers, Firefox policies and the editor configuration are maintained
in this repository. Copied inputs are local; builds and runtime do not require
sibling checkouts. See
[sources and attribution](docs/sources.md).
