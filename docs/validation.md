# Validation

Checked on 2026-09-26 from the existing NixOS workstation, without activation.

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
