# Validation

Checked on 2026-09-26 from the existing NixOS workstation, without activation.

## Codex vendor checksum protection, 2026-09-26

The user reports successful source preparation with the explicit Rust 1.95
manifest on the T490. Its first daemon-backed Home build then failed on Cargo's
checksum for `vendor/autocfg/tests/wrap_ignored`. This is a build failure,
not a source-preparation or toolchain-discovery failure.

At the pinned Guix revision, the relevant GNU phases run in this order:
`unpack`, `bootstrap`, `patch-usr-bin-file`, `patch-source-shebangs`, our
`configure`, `patch-generated-file-shebangs`, then our `build`.
`patch-source-shebangs` scans every regular source file, even non-executable
test fixtures. It changes the autocfg wrapper's `#!/bin/bash` to the Bash
store path. `patch-generated-file-shebangs` scans executable files and rewrites
Makefile `SHELL` assignments. `patch-usr-bin-file` can also rewrite executable
`configure` scripts. None of these phases understands Cargo checksum manifests.

The recipe now moves the vendor directory outside the unpacked source after
`unpack`, then restores it before `build`, accounting for `configure` changing
directory to `codex-rs`. All normal rewriting phases remain enabled for other
sources; the post-install `patch-shebangs` phase is unchanged. Codex installs
native executables, not vendored test wrappers. If a dependency later needs a
script adaptation, it must use an explicit interpreter or a separate build
copy rather than modifying the authenticated vendor tree.

`scripts/check-codex-vendor.scm` checks the prepared archive's original Cargo
file hashes, executes the recipe's actual pre-build phase expressions in a
temporary tree, and compares a recursive hash of the entire vendor directory,
including checksum manifests. Controls check that non-vendored source scripts,
generated scripts, configure commands and Makefile shells still get patched.
The test evaluates only pre-build code; approximate output references in the
unused install phase are not executed. It does not compile or run Codex.

Local results against the clean pinned Guix source, using the Nix-provided
Guile/Guix runtime:

- Reproduced the autocfg wrapper mutation with the original GNU phases on a
  disposable vendor copy. `patch-source-shebangs` changed 658 files with this
  machine's interpreter PATH. The generated-file phase changed three more:
  `bzip2-sys/bzip2-1.0.8/Makefile`, `r-efi-5.3.0/Makefile` and
  `r-efi/Makefile`. The `/usr/bin/file` phase changed no vendored file in this
  archive, but remains covered by the protection and regression controls.
- The fixed recipe's regression check passed: original checksums for all
  1,313 vendored crates verified, the complete vendor tree survived unchanged,
  and the non-vendor rewriting controls passed.
- A negative control removed only the two new protection phases from the
  evaluated phase list. The same test exited with status 1 and
  `Pre-build phases changed the Cargo vendor tree`, confirming it catches
  the original failure mechanism.
- `scripts/check.scm` passed, including Rust/Cargo consistency, the T490
  system/Home service graphs and the shared free-kernel defaults.
- `git diff --check` passed. No shell scripts changed; ShellCheck is not
  applicable to the Scheme recipe and regression script.

The pinned time-machine evaluation, regression command, Codex build, system
build and Home build were attempted here and remain blocked by the missing
`/var/guix/daemon-socket/socket`. A successful daemon-backed Codex/Home rebuild
on the T490 is still required. Existing prepared archives can be reused;
the source pin, lockfile, Rust 1.95 toolchain and both channel pins are unchanged.

## Codex toolchain correction, 2026-09-26

The earlier source preparation and metadata checks below did **not** validate
the documented `rust@1.95.0` package specification in the pinned environment.
The T490 exposed that error: name lookup offers Rust 1.93.0. Inspection of the
clean Guix checkout at `fb556d47e9dfbd246d748f3fc6d7cf9edba6c656` confirms
that `rust-1.95` exists but is hidden from package discovery. The recipe's
Scheme binding was correct; the bootstrap shell command and availability
claim were wrong.

- Reverified the original Codex archive against `sources/releases.json`.
  The workspace declares edition 2024 with no workspace-wide MSRV; upstream's
  toolchain file selects 1.95.0. Locked SQLx 0.9.0 requires Rust 1.94.0 on the
  normal `codex-cli -> codex-state -> sqlx` path. Rust 1.93 is insufficient.
  This establishes a dependency lower bound, not proof that Codex compiles
  with 1.94. We retain upstream's 1.95.0 toolchain.
- Recompared the existing prepared archive with the original release lockfile:
  all 1,313 external dependency entries, checksums and Git revisions match.
- Added assertions to `scripts/check.scm` that preparation and the recipe use
  the identical Rust 1.95.0 package object and both `out` and `cargo` outputs.
  The complete check script passed against the clean pinned Guix and Nonguix
  sources using the local Nix-provided Guile/Guix runtime, including these
  assertions and both service graphs. This is source evaluation, not a
  daemon-backed time-machine check or a compiler execution.
- Python syntax and `git diff --check` passed. No shell scripts changed, so
  ShellCheck is not applicable to this fix. The editor recipe also selects
  the `rust-1.95` Scheme binding directly and requires no change.
- Attempted the preparation command below, pinned evaluation, Codex package
  build, system build and Home build with the locally available Nix-packaged
  Guix client. All stopped at the missing `/var/guix/daemon-socket/socket`.
  Source preparation with Guix's Rust 1.95 and a daemon-backed Codex build remain
  unverified here; the previous archive is not evidence of those checks.

The corrected bootstrap command selects explicit package objects:

```sh
./scripts/guix shell -m scripts/codex-manifest.scm -- \
  python3 scripts/prepare-codex.py
```

Run this on the T490, then the evaluation and package/Home build commands in
the README. Both authenticated channel pins are unchanged. The user reports
that the existing T490 system has built and activated, Linux 7.2.7 is booted,
and Intel Wi-Fi works; the older hardware-test limitations below describe
this development workstation, not that subsequent T490 result.

## Earlier development checks

- T490 System and Home Scheme configuration evaluation and service graph folding
  passed against the pinned Guix source revision
  `fb556d47e9dfbd246d748f3fc6d7cf9edba6c656`, using the local Nix-provided
  Guile/Guix runtime for its dependencies. This is not a daemon-backed
  `guix time-machine` build. Evaluation selected LibreWolf 155.0.1-1.
- Pinned OXWM 0.13.0 tarball hash, both Blix patches, and the offline Lua source
  substitution used by the recipe.
- Patched OXWM compiled with Zig 0.16.0 in a temporary Nix build environment;
  `zig build test -j2` passed. This is source/build-script evidence, not a Guix
  derivation build.
- The built OXWM accepted the repository Lua config with `--validate` and started
  in an isolated Xvfb display, loaded the config, and registered 66 bindings.
- Picom started in the isolated Xvfb display using the repository configuration,
  with no config errors. Windows are configured opaque in both focus states.
- `scripts/prepare-codex.py` completed; the upstream archive hash was verified.
  Cargo vendoring succeeded with the corrected local workspace versions and
  `--locked`. All **1,313 external dependency entries**, including checksums and
  Git revisions, matched the original upstream lockfile exactly.
- Cargo metadata resolved offline with `--frozen`. The CLI's non-development
  dependency graph does not contain the optional V8 runtime.
- Whitespace checks passed for all new files. ShellCheck passed for the session,
  helpers and wrapper. Python source was
  parsed and executed during source preparation.

Prepared local Codex source archive:

```
ba4a29bf846ccf3a3edd50cb082dabc624bcacabb975313ca4b7d2ead2f52ad3  codex-0.157.1-vendored.tar.gz
```

**Still required on a machine with the Guix daemon:** Guix builds of the custom
packages, system and Home closure. The attempted system build here stopped
because `/var/guix/daemon-socket/socket` does not exist. Codex has not been compiled
or runtime-tested here. No full closure, installer image, boot, battery, suspend,
network, sound or physical T490 graphics test is claimed.

Before installation, verify the actual storage identities in
`hosts/t490/hardware.scm`. Follow the build and hardware checks in the README.

## Blix editor import, 2026-09-26

- Compared all ten imported Blix Neovim files byte-for-byte against the clean
  local checkout. The only additional Lua file is `lua/plugins/guix.lua`.
- Ran the real LazyVim configuration in a disposable HOME with a private copy
  of the existing plugin/parser cache. Seafoam, the writable state lockfile,
  disabled Mason integration, and Blink's Lua matcher passed their checks.
- Ran the actual `nvimide` launcher with a project directory containing spaces:
  the directory was selected correctly, arguments reached Neovim, the explorer
  and exactly two terminal panes opened, and focus stayed in the editor.
- Ordinary `nvim` started without the IDE layout. Both runs reported no Neovim
  errors. These checks used local Neovim 0.12.5, not a built Guix Home profile;
  a fresh network bootstrap and the Guix-packaged language server remain untested.
- The updated T490 Home/system definitions and service graphs evaluated against
  the pinned Guix source revision, including all new editor package names.
- Checked the imported plugin's CLI minimum: it requires Tree-sitter 0.26.1,
  whereas the pinned Guix package is 0.25.3. Added a compatible source recipe
  and copied the upstream release lockfile unchanged. Its Guix build reaches
  the same missing-daemon limitation as Home.
- Tree-sitter CLI 0.26.1 compiled from that release with `cargo build --locked`
  in a temporary Nix development environment, then generated and compiled a
  small grammar successfully. Its QuickJS binding requires libclang, which is
  included in the Guix recipe. This does not replace the pending Guix build.
- The required time-machine command exposed an unnecessary `use-modules` form
  in the channel file. Removed it for Guix's isolated channel evaluator; the
  authenticated channel pin is unchanged. Time-machine and the Home build then
  reached the existing missing-daemon limitation.
- ShellCheck and whitespace checks passed. No live editor configuration or
  sibling repository was modified, and no configuration was activated.

## T490 Wi-Fi exception, 2026-09-26

- Evaluated the T490 system and Home definitions and folded both service graphs
  against the pinned Guix source and Nonguix source at
  `2a16e08d40b913e593c7c9ea29bc82b96f117e24`, using the local Nix Guile/Guix
  runtime. The evaluation exited successfully.
- Added and passed assertions that the T490 selects Nonguix Linux plus exactly
  `iwlwifi-firmware` and the free base firmware, while shared defaults still
  select Linux-libre and the unchanged free firmware list.
- The repository's time-machine evaluation and system build both stopped at
  the inaccessible `/var/guix/daemon-socket/socket`. Channel expressions parsed,
  but daemon-backed channel authentication, builds and activation remain untested.
- `git diff --check` passed. No scripts or application recipes changed; no
  system was activated. Physical Wi-Fi, boot and suspend testing remain pending
  on the T490 after reconfiguration and reboot.
