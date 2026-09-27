# Validation

## Complete automatically resolved Codex runtime, 2026-09-26

The previous recipe selected the CLI-only archive. Help/onboarding worked, but
it omitted `codex-code-mode-host`, which `install-context` resolves beside the
physical executable (or in package resources). This explains the real T490's
failure to execute code. The old smoke checks never exercised that path.

The official installer instead uses `codex-package-<target>.tar.gz`. One latest
release response now selects that complete bundle with its versioned URL and
GitHub SHA-256 digest; no separately resolved components can drift. Every Home
build/reconfigure still refreshes automatically and fails on missing/invalid
release metadata. The checked-in record remains an offline reference only.

The live resolution for this validation returned `rust-v0.157.1`:

- Asset: `codex-package-x86_64-unknown-linux-musl.tar.gz`.
- SHA-256: `0e211868c9fd73cb49ad35ac675b5eafdf6b9f453df8a493df980c59a590fe5f`,
  independently verified after downloading the official archive.
- Layout: `bin/codex`, `bin/codex-code-mode-host`, `codex-package.json`,
  `codex-path/rg`, `codex-resources/bwrap`, `codex-resources/zsh/bin/zsh`, and
  the complete `codex-resources/voice/` helper, libraries, plugins and notices.
- CLI, code-mode host, rg and bwrap are static x86-64 PIEs. Zsh, voice host and
  voice libraries need dynamic linking. The build relocates interpreters and
  adds Guix glibc/ncurses library paths, retaining upstream relative paths.
  There are 28 dynamic ELF files in this release. Upstream voice inventory
  hashes describe the original archive, before Guix's loader relocation.

The package keeps that layout intact. Guix's wrapper moves the real CLI only
to `bin/.codex-real`, so executable-relative discovery still finds its sibling
host and parent metadata. Existing standalone mode and explicit remote options
are preserved. No daemon copy or separate app-server archive is provisioned;
`codex exec` and `codex app-server` are built into the CLI.

`scripts/check-codex-runtime.py` runs during every package build. It validates
the manifest version/target/layout, executable companions, voice inventory,
dynamic library resolution, CLI version/help and companion startup. It then
sends a code-mode tool call through a local mock Responses server and asserts
the real host evaluated JavaScript. It clears inherited credentials/config,
uses disposable state, and leaves the host out of PATH to test layout discovery.
No external API, login or model invocation is needed.

Local validation exercised the actual Scheme builder with development-machine
tools and all runtime checks passed. The resulting wrapper also passed
ShellCheck. The complete runtime passed again in a bubblewrap filesystem with
no `/bin`, `/usr` or `/lib64`, using only store paths, temporary state and proc/dev.
Negative checks reject a missing code-mode host and mismatched package version.
All 17 resolver tests and wrapper-routing regressions passed, as did complete
System/Home evaluation with the exact local pinned Guix/Nonguix sources.
This is not a daemon-backed Guix build: the normal repository check, package and
Home build commands were attempted but time-machine cannot connect to the absent
`/var/guix/daemon-socket/socket`. Actual audio hardware operation was not tested.

Activation is Home-only: reconfigure Home and restart Codex.

## Home shell tools, 2026-09-26

Home now includes the pinned channel's OpenSSH, fastfetch-minimal 2.66.0 and
blesh 0.4.0-devel3. OpenSSH supplies `ssh-keygen`; fastfetch-minimal supplies
`fastfetch` without the full variant's optional graphical/ZFS dependencies.
Bash sources ble.sh from an immutable store reference after its usual rc
settings, only for interactive, non-dumb terminals and only once.

- Complete pinned-source System/Home evaluation and package assertions pass.
- Built the exact upstream ble.sh tag for a disposable pseudo-terminal test:
  Bash loaded it with autosuggestions enabled, and Right Arrow accepted and
  executed a history suggestion. Noninteractive and dumb-terminal guards pass.
  This uses the development machine's Bash, not a Guix daemon-backed build.
- ShellCheck passes on the extracted Bash fragment with SC1091 excluded for
  the externally supplied ble.sh library; `git diff --check` passes.
- Repository-wrapper evaluation, package builds and Home build were attempted
  but time-machine cannot connect to the absent Guix daemon socket.

Activate with Home reconfiguration and open a new terminal. No system update,
X session restart, generated SSH key, SSH server or shell-startup download is
part of this change. The existing aliases and Bash history behavior remain.

## OXWM terminal launch, 2026-09-26

The repository had a concrete deployment bug: `repository-file` defaults to
`#:recursive? #f`, as does `local-file`. The pinned Guix `guix/gexp.scm`
documentation and `nix/libstore/local-store.cc` import implementation show that
flat imports create non-executable files (0444 after store normalization).
The Git executable bit alone does not survive this import. Consequently,
`st-bash` can exist on the X session's PATH but cannot be executed. Pinned
OXWM 0.13.0 uses `execvp` for `spawn_terminal()` and exits silently on failure.
LibreWolf comes from a package profile with executable permissions intact.

The wrapper's `/bin/sh` shebang was valid on Guix System; it did not hardcode
`/bin/bash`. The session already explicitly includes `.local/bin` and the
Home/system profiles. Home installs st, and its Bash service adds interactive
Bash to the profile. The fix removes the unnecessary wrapper and uses
`oxwm.spawn("exec st -e bash")`. OXWM logs this command, and shell/st stderr
inherits the existing session log. Bash gets an interactive terminal normally,
without a login-shell override or changes to the user's shell configuration.

The remaining desktop helpers had the same flat-import bug, including commands
used by screenshot, clipboard, lock, control-menu and brightness bindings.
Their Home imports, and `.xinitrc`, now preserve executable permissions with
`#:recursive? #t`. Their contents and bindings are unchanged. Other spawn
commands resolve to declared packages; no Alpine/Nix executable path was found.

Validation:

- Reproduced the silent failure with the actual patched OXWM 0.13.0 under a
  disposable Xvfb server: the old binding and a mode-0444 wrapper on PATH opened
  no terminal. An executable copy of the same wrapper worked.
- The new binding, with no wrapper, opened real st and interactive Bash via
  simulated Super+Return. Verified a test Bash rc file, an alias invoked by
  typed input, terminal exit and continued OXWM operation. The development
  machine's st/Bash were used, with an isolated rc-file adapter to avoid
  reading the real user's configuration. This is not a Guix package build.
- Eight `scripts/check-xsession.py` tests pass, including command arguments,
  launching without a wrapper, and terminal failure reaching the session log
  while OXWM remains running. Real OXWM accepts the updated Lua config.
- `scripts/check.scm` checks st, the Bash service's resulting profile, removal
  of the wrapper, and both source executability and recursive import for every
  desktop helper. It also checks `.xinitrc` import mode; the earlier check only
  inspected permissions in the checkout and missed the store-import bug.
  The complete checks pass using the local exact pinned Guix/Nonguix source
  evaluator, including both T490 System and Home service graphs and the sixteen
  existing Codex metadata tests. This evaluation does not require a daemon.
- ShellCheck passes for `.xinitrc` and reports no warning/error-severity issues
  in the helpers. Its existing SC2012 informational notices in clipboard-history
  remain unchanged. `git diff --check` passes.
- The normal repository check and st/Bash/OXWM, System and Home builds cannot
  get through time-machine on this machine: `/var/guix/daemon-socket/socket`
  is absent. No daemon-backed build or T490 activation is claimed.

Only Home reconfiguration is required. Exit the existing OXWM session with
Super+Shift+Q and run `startx` to load the changed binding.

## Console X11 session startup, 2026-09-26

The user reports the T490 System and Home are activated, OXWM and its managed
Lua configuration are present, and validation succeeds. Xorg starts but exits
cleanly when its client script terminates. Repository investigation found:

- The pinned `startx-command-service-type` installs a wrapper that invokes
  `xinit -- Xorg ...`; xinit selects the executable `~/.xinitrc`. This bypasses
  display-manager session wrappers, including their `.xsession-errors` setup.
  Home already deploys the executable repository file correctly.
- The old `.xinitrc` used `set -eu` around foreground `xsetroot`, `xset` and
  `alpinews-monitors` calls before installing its cleanup trap. Any nonzero
  result, including a missing command or RandR mode/rate failure,
  could terminate the X client before OXWM ran. It only prepended `.local/bin`,
  assuming the current console shell had already sourced the Home environment.
  The exact failing command on the T490 cannot be established from its clean
  Xorg shutdown alone; this fix does not assume an OXWM fault.
- Asynchronous helper failures do not propagate through POSIX `set -e`.
  Waiting only for OXWM is retained. Its exit status is now logged and preserved;
  helper and transient-state cleanup also runs on session termination signals.
- `alpinews-monitors` retains its existing layout policy and its own failure
  status. The session gives foreground setup a ten-second timeout plus a
  two-second kill grace and treats errors as optional. Hotplug still uses
  eudev's `udevadm`; clipboard events use the Home-packaged listener. Picom's
  opaque configuration is unchanged.
- The Guix Home profile supplies OXWM, X utilities, Picom, xss-lock, i3lock,
  eudev and the clipboard listener; `.local/bin` supplies the deployed helpers.
  System `%base-packages` supplies Coreutils (including timeout), awk, grep,
  findutils and the shell. Elogind's service provides `loginctl`. The privileged
  i3lock path `/run/privileged/bin/i3lock` is correct at the channel pin and
  remains required for PAM locking; its absence is logged, not silently
  replaced by an unprivileged binary.
- `${XDG_RUNTIME_DIR:?}` in the old exit trap could fail during cleanup.
  The new script validates ownership/mode, prefers the existing elogind runtime,
  and otherwise makes a private session-only fallback. It never removes the
  elogind runtime directory itself or cleans an unvalidated caller-supplied path.
- This desktop composition uses `%base-services`, omitting the standard
  `%desktop-services` X socket-directory service. Rootless Xorg can consequently
  create a user-owned `/tmp/.X11-unix`. Added Guix's root Shepherd service for
  boot plus activation repair of existing ownership/mode. The standard service
  alone only creates/chmods, so would not fix a previously user-owned directory.
  Repair preserves sockets and rejects a symlink instead of following it.
- No active repository startup command invokes `systemctl` or a systemd user
  manager. Guix uses Shepherd; standalone elogind intentionally implements the
  login1 interface and compatibility paths such as `/run/systemd`. Those names
  in upstream Guix/elogind do not mean systemd runs as init. Nothing switches
  the workstation to systemd or changes the existing login/power design.

Local validation:

- Reproduced the original script exiting with status 23 before OXWM when a
  foreground setup command failed, even with the helper available on PATH.
- Six isolated session regressions passed: setup/background failures, finding
  OXWM only in the Home profile, nonzero WM exit and helper cleanup, missing or
  unsafe runtime environment, termination signals, and unwritable logging.
- In a disposable Xvfb display, the real previously built patched OXWM 0.13.0
  loaded this repository's Lua configuration, claimed the EWMH WM property,
  and stayed running alongside real Picom while injected background helpers
  failed. Session termination cleaned up. DPMS warnings were captured; this
  host's xset returned zero for them, so the warnings alone are not evidence of
  the fatal T490 command. This uses local Nix-provided X tools, not Guix Xorg
  or a physical GPU/VT. No actual lock, suspend or power action was triggered.
- Complete T490 Home/system evaluation and service graph checks passed against
  the pinned Guix/Nonguix sources using the local Nix Guile/Guix runtime, including
  assertions for session packages, executable `.xinitrc` deployment and socket
  services. The actual socket activation expression passed tests for creation,
  existing-directory repair without deleting contents, and symlink rejection;
  only privileged `chown` was intercepted and checked for UID/GID 0.
- ShellCheck passed for the changed session script and `git diff --check` passed.
  The time-machine check and OXWM/system/Home builds were attempted but stopped
  at the missing `/var/guix/daemon-socket/socket`. No daemon-backed Guix build,
  real root activation, physical T490 session or reboot was performed here.

Applying the socket fix requires one system reconfigure, followed by Home
reconfigure, console logout/login and `startx` as shown in the README. No reboot
or further diagnostic commands are required from the user.

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

## Initial official Codex musl migration, 2026-09-26 (superseded)

The CLI-only layout below was incomplete: version/help/onboarding did not
exercise code mode. The complete-runtime fix above replaces this recipe and
its original runtime assumptions.

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
  initial CLI/exec startup without a sibling `codex-exec`; this did not prove
  tool execution worked without the code-mode host and package resources.
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
