# Validation

## Latest stable Codex on Home commands, 2026-09-26

The user's follow-up replaces the fixed Home version policy: each
`./scripts/guix home build` and `./scripts/guix home reconfigure` first queries
OpenAI's latest stable release API using the pinned Guix runtime. It passes a
private temporary version/URL/SHA-256 snapshot to package evaluation. Guix
verifies the actual artifact against that digest; no mutable URL enters the
derivation, and no tracked files or channel pins are rewritten. Refresh errors
abort the Home command. Temporary metadata is removed on success or failure.

The live lookup returned 0.157.1 and the same SHA-256 independently verified
below. A new release therefore needs no recipe edit; today this policy change
does not change the executable. Offline checks/direct package evaluation use
the checked-in reference when no per-command snapshot is supplied. Existing
Home generations are not updated in place.

Validation on the development machine:

- Live refresh succeeded using the pinned Guix source and local Nix-provided
  Guile/Guix runtime, without a daemon. The resolved digest matches the
  independently hashed official artifact from the initial migration below.
- All 16 offline release tests passed: stable-version selection, required
  musl asset/digest, rejection of drafts/prereleases and unexpected URLs,
  snapshot precedence, and refusal to fall back from invalid metadata.
- The shell routing regression passed for both Home commands, arguments with
  spaces, refresh/build failures and temporary-file cleanup. A system build
  was passed through without refresh. These use a mock Guix command and never
  activate Home.
- Complete T490 Home/system evaluation and service-graph checks passed against
  the pinned sources with the live release snapshot. This is evaluation, not
  a daemon-backed build. The existing binary/launcher implementation is unchanged.
- ShellCheck passed for both shell scripts, and `git diff --check` passed.
- The repository time-machine check and Codex/system/Home builds were attempted
  again, but stopped at the missing `/var/guix/daemon-socket/socket`. No Guix
  derivation build or activation is claimed. The T490 remains the integration test.

## Initial official Codex musl migration, 2026-09-26

The initial binary migration installed the official binary at the user's
request, following unsuccessful source builds on the real T490. Earlier
source-build debugging details remain in Git history, not active instructions.

- Release: `openai/codex`, `rust-v0.157.1`; the GitHub release API lists asset
  `589592614`, `codex-x86_64-unknown-linux-musl.tar.gz`, size 107,868,387 bytes.
- Download URL:
  <https://github.com/openai/codex/releases/download/rust-v0.157.1/codex-x86_64-unknown-linux-musl.tar.gz>.
- Independently computed SHA-256 matches the API's asset digest:
  `e98c1e8e028e8137fa2d2415c82ec58e7b3701a627e3554aace5b3ca31454af2`.
  GitHub reports this release as not immutable; the version-specific URL plus
  fixed hash makes any replacement fail verification rather than silently
  change the package.
- Archive inspection found exactly one executable:
  `codex-x86_64-unknown-linux-musl`, 285,340,072 bytes, mode 0755.
- `file` reports ELF x86-64 static PIE. `readelf` shows no `PT_INTERP` and no
  `DT_NEEDED` entries. No FHS dynamic loader, patchelf, or shared-library shim
  is needed for the upstream executable.
- Unmodified binary `--version`, `--help` and `exec --help` execute on this
  NixOS development machine. Tests use a disposable HOME/CODEX_HOME and no
  account data. They do not establish authenticated API access or T490 boot.
- Inspected the exact release's README, `install-context`, CLI dispatch,
  TUI server selection and Linux sandbox launcher. The single binary supports
  standalone CLI/exec use without a sibling `codex-exec` or package metadata.
  It can use system bubblewrap and ripgrep on PATH; the Guix wrapper supplies
  those. An actual interactive test exposed that default startup tries to
  provision a daemon and fails without a complete upstream package. Repeating
  with `--no-daemon` reached the normal sign-in screen. The launcher therefore
  defaults to that supported standalone mode, preserving explicit `--remote`
  options. Managed-daemon provisioning/local agents overview are not supported
  by this standalone layout. We do not invent daemon metadata or resources.

The recipe uses a trivial unpack/copy/wrap builder with only tar/gzip as native
inputs. Offline version/help checks run during packaging. There is no local
source archive or bootstrap prerequisite, no compiler input, and no activation
installer. The separate Tree-sitter editor recipe still uses its pinned Rust
compiler; it was not changed.

Current development-machine validation:

- `scripts/check.scm` passed against the exact pinned Guix and Nonguix sources
  with the Nix-provided Guile/Guix runtime. This evaluates the binary package,
  release URL/hash/input assertions, complete T490 Home and system definitions,
  and both service graphs. The obsolete preparation files/archive were absent.
- The raw executable also passed version and exec-help checks in a bubblewrap
  namespace without `/lib`, `/lib64`, `/nix/store` or a shell, confirming it
  does not depend on the host's FHS compatibility loader.
- Executed the actual recipe's unpack/copy/wrap/smoke-check builder with local
  Nix tool paths substituted for Guix inputs. All checks passed; the installed
  hidden executable is byte-for-byte identical to the extracted upstream file.
  This exercises the builder, not a Guix derivation or its exact helper versions.
- The resulting launcher reached interactive sign-in without an explicit
  `--no-daemon` argument. Explicit standalone and remote options were preserved.
  With an otherwise empty PATH, `codex sandbox` ran a shell command and found
  the wrapper's bubblewrap/ripgrep. This used local bubblewrap 0.12.0; the
  channel's 0.11.0 still needs the T490 integration test. No sign-in was attempted.
- ShellCheck passed for the generated launcher, and `git diff --check` passed.
  Repository searches found no remaining Codex preparation/vendor/toolchain
  instructions. Rust requirements remaining in the editor recipe are unrelated.
- The repository's time-machine check and Codex/system/Home builds were
  attempted, but all stop at the missing `/var/guix/daemon-socket/socket`.
  No daemon-backed Guix build or Home activation occurred on this machine.

The user reports that the actual T490 system is already activated with Linux
7.2.7 and working Intel Wi-Fi. Its final integration check for this change is:

```sh
./scripts/guix home build -L modules hosts/t490/home.scm
# Only after the build succeeds:
./scripts/guix home reconfigure -L modules hosts/t490/home.scm
```

No Codex preparation command is required. Other Home applications retain their
own existing build requirements.

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
- Whitespace and ShellCheck checks passed for the original session helpers
  and wrapper. Those files are unchanged by the Codex binary migration.

**Still required on a machine with the Guix daemon:** Guix builds of the custom
packages, system and Home closure. The attempted system build here stopped
because `/var/guix/daemon-socket/socket` does not exist. No full closure, installer image, boot, battery, suspend,
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
