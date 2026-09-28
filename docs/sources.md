# Sources and port decisions

## Wallpaper, 2026-09-26

`home/przvl/config/wallpaper/night.png` is an unchanged copy of the user's
`~/Downloads/night.png` (SHA-256
`0940dbb5460c0e3d6d3d6896c24d46056dc0547f56b8b5267df8b76660871eb3`).
Guix Home installs it under `~/.config/wallpaper/` so X session startup does
not depend on the Downloads directory.

## Firefox stable-release verification, 2026-09-26

Home resolution now intersects successful Nonguix Firefox builds with Mozilla's
published [major release history](https://product-details.mozilla.org/1.0/firefox_history_major_releases.json)
and [stability release history](https://product-details.mozilla.org/1.0/firefox_history_stability_releases.json).
A numeric package version alone is insufficient. Both histories are fetched
before package evaluation; failure aborts the Home command. Version selection
remains dynamic and downloads still come exclusively from the signed Nonguix
cache, with no Firefox source-build fallback. Blix policies are unchanged.

The installed 156.0 package is built from release sources. The pinned Nonguix
`nongnu/packages/mozilla.scm` uses `--enable-release` and
`--disable-official-branding`; the cached application's `CodeName=Nightly` and
default update channel are therefore not evidence of a nightly source version.
The cache's upstream branding is retained rather than relabeling the binary.

## Guix terminal launch, 2026-09-26

The inherited `st-bash` wrapper is removed. OXWM's Return binding now launches
`st -e bash` with `oxwm.spawn`, which accepts arguments and logs the command.
The pinned OXWM 0.13.0 `src/wm/actions.zig` terminal-specific action instead
executes one filename through PATH and silently exits on exec failure.
Guix's pinned `guix/gexp.scm` documents that flat `local-file` imports discard
executable permissions; the desktop helpers and `.xinitrc` now use recursive
imports to preserve them. Bash is supplied by `home-bash-service-type`.

Read-only local references inspected on 2026-09-26:

- AlpineWS `c5805aa0f17a160b72bb9d97c45f988728e230cc`:
  <https://github.com/blakepiper/alpinews>. The display, brightness, status,
  screenshot and clipboard helpers and MIT-licensed `clipwatch.c` are copied
  locally so this repository does not require a sibling checkout at build time.
  The X session now explicitly includes Guix profile paths, logs client output,
  treats display/helper failures as nonfatal, and waits only for OXWM's lifetime.
  Transient helper state uses elogind's runtime directory or a private session
  fallback. Guix's privileged i3lock path and elogind's `loginctl` are retained;
  there is no systemd user-manager command or dependency in these scripts.
- Blix `cb7c59f55dd072fae7936ca05b5a3cab088313d4`:
  <https://github.com/blakepiper/blix>. OXWM Lua configuration, microphone keysym
  patch, mirrored-monitor patch, host organization and historical hardware facts.
  Browser launcher, font, battery variable and helper names are adapted here.
- OXWM `v0.13.0`, commit `fc4ada9ac4ee8e34ace203290a2b14d10e4671cc`:
  <https://github.com/tonybanters/oxwm/tree/v0.13.0>. MIT license. Source tarball
  checksum is recorded in both `sources/releases.json` and the recipe. Zig's
  Lua download is replaced with Guix's pinned Lua 5.4.8 source input.
- Codex official stable musl releases (initially inspected at `rust-v0.157.1`):
  <https://github.com/openai/codex/releases/tag/rust-v0.157.1>. Apache-2.0 license.
  At the user's request, each repository-wrapped Home build/reconfigure now
  resolves the latest stable release through OpenAI's GitHub API. A private
  per-invocation JSON snapshot supplies the versioned URL and SHA-256 to the
  recipe; evaluation and activation do not query upstream. The checked-in
  metadata remains an offline reference for other commands, not a Home pin.
  The recipe now uses the complete `codex-package-x86_64-unknown-linux-musl.tar.gz`
  bundle used by the [official installer](https://github.com/openai/codex/blob/rust-v0.157.1/scripts/install/install.sh),
  not the similarly named CLI-only archive. The bundle contains the code-mode
  host, rg, bwrap, Zsh, voice helper/libraries and metadata from one release.
  [Package layout](https://github.com/openai/codex/blob/rust-v0.157.1/scripts/codex_package/layout.py)
  and [runtime discovery](https://github.com/openai/codex/blob/rust-v0.157.1/codex-rs/install-context/src/lib.rs)
  require preserving the physical `bin/` directory, adjacent host and package
  root resources. The existing standalone/remote wrapper behavior is retained.
  Dynamic bundled helpers are relocated using Guix glibc and ncurses/tinfo;
  static binaries are unchanged. The offline mock Responses check follows the
  protocol exercised by upstream `scripts/codex_package/smoke_tests/`, without
  importing its SDK or introducing sibling-repository runtime dependencies.
- Guix `fb556d47e9dfbd246d748f3fc6d7cf9edba6c656`:
  <https://codeberg.org/guix/guix>. `channels.scm` retains the official channel
  introduction for authenticated updates. Its Zig and Rust definitions remain
  relevant to OXWM and the separate Tree-sitter editor recipe, respectively.

Imported upstream code retains its upstream license; this repository does not
claim authorship of those patches or configurations. No sibling repository was
modified. No installer or existing system configuration was activated.

Intentional changes from AlpineWS: GNU userland and libc, Shepherd system
services, Elogind session/power management, Guix Home PipeWire services, Picom,
the official Codex binary, and packaged st. LibreWolf was subsequently replaced
by the user's Blix Firefox policies, as described below. CPU microcode remains omitted.
Intel Wi-Fi firmware was subsequently enabled only for the T490 at the user's
request. Input permissions are managed through Elogind
and udev rather than Alpine's broad input-group setup.

## Blix editor import

The complete `home/przvl/config/nvim/` tree and the behavior of the `nvimide`
launcher in `home/przvl/programs/neovim.nix` were imported from the current clean
local Blix checkout at `cb7c59f55dd072fae7936ca05b5a3cab088313d4` on 2026-09-26.
This is the latest configuration present in that checkout, not an assertion
about un-fetched remote changes. All ten original configuration files are
copied byte-for-byte, including the Seafoam theme, lockfile, and IDE layout.

The only added Lua file is `lua/plugins/guix.lua`: Mason is disabled in favor of
Guix-managed language servers; Blink uses Lua rather than a downloaded native
binary; Lua formatting uses the language server fallback because this channel
does not package StyLua. `nvimide` preserves directory selection, argument
forwarding, and `BLIX_NVIMIDE=1`, expressed in POSIX shell. Editor dependencies
and installation are isolated in `modules/workstation/home/editor.scm`.

Blix's pinned nvim-treesitter requires Tree-sitter CLI 0.26.1 or newer; the
official channel currently provides 0.25.3. The local editor package builds
upstream `tree-sitter/tree-sitter` tag `v0.26.1` with SHA-256
`c547e2e054ca7220e5b30b18ddf67aec4144cf9288ef5c8ef707c98dbe4951eb`.
`sources/tree-sitter/Cargo.lock` is copied unchanged from that archive; Guix
imports the registry dependency sources and hashes from it. This is a source
build, without an npm-distributed executable or changes to Blix's plugin pins.

## Blix Firefox policies, 2026-09-26

`home/przvl/config/firefox/policies.json` is the JSON translation of
`home/przvl/programs/browser.nix` from the clean Blix checkout
`cb7c59f55dd072fae7936ca05b5a3cab088313d4`. Its policy object was compared with
both the evaluated Nix declaration and the installed Blix Firefox policy file;
all fields match. The Mozilla Add-ons URLs retain Blix's automatic extension
updates. No Nix store path or sibling repository is used by the Guix package.

`firefox-blix` copies the pinned Nonguix Firefox package, preserves its Guix
library wrapper and installs the policy beside the physical Firefox executable.
It rewrites launcher/desktop references to the new output, avoiding a full
Firefox source rebuild for a policy change. Mozilla's
[policy documentation](https://mozilla.github.io/policy-templates/) specifies
`distribution/policies.json` in the installation directory on Linux. A Home
dotfile alone is insufficient, and `browser.policies.alternatePath` is restricted
to automation/Nightly. System configuration and browser profile contents are
not involved in this packaging change.

## T490 Wi-Fi exception, 2026-09-26

Nonguix is pinned at `2a16e08d40b913e593c7c9ea29bc82b96f117e24` from
<https://gitlab.com/nonguix/nonguix>. Its channel introduction is
`897c1a470da759236cc11798f4e0a5f7d4d59fbc`, with signing fingerprint
`2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5`, as documented in
[the upstream README](https://github.com/nonguix/nonguix).

Only `hosts/t490/system.scm` selects its `linux` kernel and `iwlwifi-firmware`.
The shared base retains Linux-libre and `%base-firmware`; no microcode initrd,
full firmware bundle, additional substitute server or signing key is configured.
Channel introduction authentication remains enabled in the time-machine path.

## Cached Firefox selection, 2026-09-26

Firefox Home updates now resolve Nonguix Cuirass's latest 100
`firefox.x86_64-linux` builds from
<https://cuirass.nonguix.org/api/latestbuilds?job=firefox.x86_64-linux&system=x86_64-linux&nr=100>.
The resolver filters successful stable Firefox builds, sorts by numeric version
(newer rebuild first on ties), and selects the first output still advertised by
<https://substitutes.nonguix.org>. It does not evaluate downloaded Scheme or
change the pinned Guix/Nonguix channels. Network failures abort; only a missing
narinfo (HTTP 404) allows trying the next candidate.

The checked-in signing key comes from
<https://substitutes.nonguix.org/signing-key.pub> and matches the key in
<https://github.com/nonguix/nonguix#substitutes-for-nonguix>. Guix, not the
metadata resolver, authenticates the downloaded substitute and its closure.
The key authorizes substitutes generally, not just Firefox. Home prefetch uses
`--max-jobs=0 --no-offload` and a temporary GC root. The policy package takes the
resolved store path directly, so Firefox's source derivation/toolchain is not
part of its build graph. Other Home packages may still build normally.

The initial offline reference is Firefox 156.0, output
`/gnu/store/ybk9mpvi5aw47hr1bwpf1bqnqjv2x3ml-firefox-156.0`, from
<https://cuirass.nonguix.org/build/1002769/details>. Home build/reconfigure always
refreshes the per-command record; it does not use this reference as an update
pin. The existing Blix policy builder remains in place. No sibling repository
is used at build time or runtime, and no Mozilla upstream binary is introduced.

## OXWM equal split and gapless tiling, 2026-09-27

The pinned OXWM 0.13.0 source initializes the master factor to 0.55 for both
monitors and per-tag state. `sources/oxwm/0003-equal-split.patch` changes both
defaults to 0.50, so the first two dwindle windows divide the working width
equally on every tag. OXWM's Lua `set_master_factor` produces a key action,
not an initial configuration value. The Home Lua config disables inner and
outer gaps and keeps a two-pixel border so the focused window is outlined.
The status bar remains visible; windows tile flush against it and the screen
edges.

## Zen host, 2026-09-27

Zen composes the working T490's shared workstation modules without copying its
storage, input IDs or ThinkPad battery services. Hardware specifications come
from the user; storage and actual device IDs remain unverified. The monitor
helper gains an opt-in native-panel policy with the existing T490 default kept.
See [the Zen guide](zen.md) for upstream hardware references and firmware choices.

`modules/workstation/packages/firmware.scm` adapts the WHENCE selection phase
from the pinned Nonguix `nongnu/packages/linux.scm` (`select-firmware` and
`i915-firmware`, channel commit `2a16e08d40b913e593c7c9ea29bc82b96f117e24`).
It inherits the recipe/source checksum and expands the allowed paths to
`i915/` and `xe/`; no sibling repository is used. This is a firmware subset,
not a full linux-firmware installation. Zen's explicit host exception adds
Intel graphics and Intel SOF audio alongside Intel wireless; it does not alter
T490's earlier exception or shared free defaults.

## Zen first-boot peripherals and charge ceiling, 2026-09-27

Live xrandr confirmed eDP-1 (2880×1800 at 120 Hz, 2560×1440 at 59.99 Hz)
and DP-1-4-4 (2560×1440 at 144 Hz). The local AlpineWS-derived monitor helper
now accepts a separate external refresh rate and restores the native panel
mode after unplugging. Zen opts into 1440p mirroring.

Live XInput confirmed the attached Gaming Keyboard's 1fc9:e8c7 USB ID.
A repository-local helper applies the existing T490 Alt/Super option to only
that device's slave keyboards, through Home startup and input hotplug.
The built-in keyboard retains its normal Win/Super map. No new sources copied.

Zen's BAT0 exposes the standard charge_control_end_threshold attribute.
The existing T490 threshold writer is extracted into a shared battery module;
Zen selects 79% without importing ThinkPad module-loading behavior.

## Zen mouse and charge-limit persistence, 2026-09-27

Live XInput identified the attached Logitech G502 HERO as USB 046d:c08b.
A local Home helper enables its libinput natural-scrolling property at login
and input hotplug, without modifying other pointer devices. The existing
shared battery service now reapplies its ceiling during system activation as
well as boot and power-supply events, so reconfiguration cannot skip the
writer merely because the one-shot service is unchanged. No sources copied.

Zen's ASUF1208 touchpad was subsequently verified as XInput product 2808:0218
and explicitly enabled for natural scrolling too. The helper matches both
host-selected product IDs and leaves unrelated pointer devices unchanged.

## Zen readable desktop modes, 2026-09-27

After first-boot use, the native panel desktop was too small. Zen now selects
1920×1200 at approximately 60 Hz standalone and 1920×1080 when mirrored
(internal approximately 60 Hz, external 120 Hz). These modes were advertised
by the live panel and the earlier dock display query. This enlarges the entire
existing desktop without per-application overrides; it trades native pixel
resolution and the standalone 120 Hz mode for readability. T490 is unchanged.

## Zen bar and Firefox readability, 2026-09-27

Zen selects a 14-point bar font through a Home-managed file read by the shared
OXWM Lua configuration. Firefox receives a host-specific policy overlay with
`layout.css.devPixelsPerPx` set to "1.25". Mozilla's preference definition in
[StaticPrefList.yaml](https://github.com/mozilla-firefox/firefox/blob/main/modules/libpref/init/StaticPrefList.yaml)
describes the device-pixel/CSS-pixel scale. All Blix policies and the cached,
signed Firefox resolution/build path are retained; no new binary source is
introduced. T490 retains the original bar font and Firefox preferences.

## Zen touchpad right-click, 2026-09-27

Live XInput showed tapping disabled and button-area clicking selected on the
ASUF1208 touchpad. Zen now opts into tapping and clickfinger with explicit
left/right/middle mappings for one/two/three fingers. The existing Home input
helper applies these only to the selected product's tapping-capable interface,
leaving its composite mouse interface and other devices untouched. Property
semantics follow the installed xf86-input-libinput 1.5.0 driver and its
[manual](https://man.archlinux.org/man/libinput.4.en). No sources copied.

## Wallpaper after display changes, 2026-09-27

The AlpineWS-derived monitor helper now reruns feh after successful layout
changes, including mirror, standalone and preferred-mode fallback paths.
Previously only session startup painted the wallpaper, leaving an oversized
root pixmap after reducing resolution or undocking. The original image and
aspect-preserving fill mode are retained; no image asset was edited.

## Zen Cirrus audio firmware, 2026-09-27

Live PCI/sysfs reports ASUS UX5406SA, audio subsystem 1043:1e13, one CS42L43
codec and four CS35L56 SoundWire amplifiers. The user supplied kernel logs
showing `cs42l43.bin` failing with ENOENT while SOF 2.14.1.1 boots successfully.

`zen-audio-firmware` in `modules/workstation/packages/firmware.scm` inherits
linux-firmware 20260916 from authenticated Nonguix commit
`2a16e08d40b913e593c7c9ea29bc82b96f117e24`, retaining its source checksum
and compressed installer. Its WHENCE selection keeps `cs42l43.bin`, the four
`cirrus/cs35l56-b0-dsp1-misc-10431e13-ampN.bin` files, their upstream firmware
symlink and its `cirrus/cs35l56/CS35L56_Rev3.11.16.wmfw` target. It installs
LICENSE.cirrus. No sibling repository or other model's tuning is used.

The [upstream Cirrus driver documentation](https://docs.kernel.org/sound/codecs/cs35l56.html)
explains subsystem-specific amplifier tuning and required WHENCE symlinks.
The user approved this additional nonfree firmware exception for Zen only.
Shared free defaults, T490, kernel/channel pins and Intel SOF remain unchanged.
