# Sources and port decisions

Read-only local references inspected on 2026-09-26:

- AlpineWS `c5805aa0f17a160b72bb9d97c45f988728e230cc`:
  <https://github.com/blakepiper/alpinews>. The display, brightness, status,
  screenshot and clipboard helpers and MIT-licensed `clipwatch.c` are copied
  locally so this repository does not require a sibling checkout at build time.
- Blix `cb7c59f55dd072fae7936ca05b5a3cab088313d4`:
  <https://github.com/blakepiper/blix>. OXWM Lua configuration, microphone keysym
  patch, mirrored-monitor patch, host organization and historical hardware facts.
  Browser launcher, font, battery variable and helper names are adapted here.
- OXWM `v0.13.0`, commit `fc4ada9ac4ee8e34ace203290a2b14d10e4671cc`:
  <https://github.com/tonybanters/oxwm/tree/v0.13.0>. MIT license. Source tarball
  checksum is recorded in both `sources/releases.json` and the recipe. Zig's
  Lua download is replaced with Guix's pinned Lua 5.4.8 source input.
- Codex `rust-v0.157.1`:
  <https://github.com/openai/codex/releases/tag/rust-v0.157.1>. Apache-2.0 license.
  Source tarball hash is in `sources/releases.json`. Source vendoring uses Cargo's
  checksum verification and exact Git revisions. The CLI dependency graph does
  not include V8; the separate code-mode host is not built. The package layout
  follows upstream's `codex-rs/install-context` and the daemon's requirements.
  The workspace declares edition 2024 but no workspace-wide `rust-version`.
  Its `rust-toolchain.toml` selects 1.95.0. The locked SQLx 0.9.0 crates
  declare `rust-version = "1.94.0"`; `codex-cli -> codex-state -> sqlx` is
  a normal dependency path, so Rust 1.93 cannot build this lockfile.
  1.94 is a declared dependency lower bound, not a verified minimum for all
  Codex source code; this port uses upstream's selected 1.95.0.
- Guix `fb556d47e9dfbd246d748f3fc6d7cf9edba6c656`:
  <https://codeberg.org/guix/guix>. `channels.scm` retains the official channel
  introduction for authenticated updates. Recent Zig and Rust definitions are
  needed by the source builds.
  At this exact revision, `gnu/packages/rust.scm` defines `rust-1.95` with
  compiler and Cargo outputs, inherited `hidden?` metadata, and a source
  bootstrap through Rust 1.94.1. The discoverable `rust` package instead
  inherits 1.93.0 and removes `hidden?`. Thus `rust@1.95.0` cannot resolve,
  although the Scheme binding works. `scripts/codex-manifest.scm` selects the
  binding directly, as the Codex recipe already did. Neither channel pin
  needs changing; the T490's kernel, firmware and Nonguix compatibility are
  unaffected. No external Rust installer or new toolchain recipe is needed.

Imported upstream code retains its upstream license; this repository does not
claim authorship of those patches or configurations. No sibling repository was
modified. No installer or existing system configuration was activated.

Intentional changes from AlpineWS: GNU userland and libc, Shepherd system
services, Elogind session/power management, Guix Home PipeWire services, Picom,
LibreWolf, source-built Codex, and packaged st. CPU microcode remains omitted.
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
