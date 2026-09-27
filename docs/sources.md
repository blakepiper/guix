# Sources and port decisions

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
  This uses the official Linux x86_64 musl executable instead of a local
  compilation. The initial release API lists asset ID `589592614`, named
  `codex-x86_64-unknown-linux-musl.tar.gz`; its download URL and independently
  verified SHA-256 are retained in `sources/releases.json` as the reference.
  The archive contains one static PIE executable. Upstream's README explicitly
  documents renaming that executable to `codex`. The package uses Guix's
  trivial build system to unpack it and wrap PATH with bubblewrap and ripgrep.
  Upstream's `install-context` and `linux-sandbox` modules support these tools
  on PATH without adjacent resource directories; `codex exec` is built in.
  Version 0.157.1's default interactive startup nevertheless tries to provision
  a daemon and fails without complete package metadata. The launcher defaults
  to upstream's supported `--no-daemon` mode (preserving explicit `--remote`
  options), which successfully opens onboarding with disposable state. No
  synthetic daemon package, updater, configuration or credentials are installed.
- Guix `fb556d47e9dfbd246d748f3fc6d7cf9edba6c656`:
  <https://codeberg.org/guix/guix>. `channels.scm` retains the official channel
  introduction for authenticated updates. Its Zig and Rust definitions remain
  relevant to OXWM and the separate Tree-sitter editor recipe, respectively.

Imported upstream code retains its upstream license; this repository does not
claim authorship of those patches or configurations. No sibling repository was
modified. No installer or existing system configuration was activated.

Intentional changes from AlpineWS: GNU userland and libc, Shepherd system
services, Elogind session/power management, Guix Home PipeWire services, Picom,
LibreWolf, the official Codex binary, and packaged st. CPU microcode remains omitted.
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
