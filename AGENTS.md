# Guix workstation conventions

- Keep host facts in `hosts/<name>/`; shared Scheme modules belong under
  `modules/workstation/`. Use `-L modules`, not `-L .`, so Guix's package
  discovery does not evaluate host entrypoints as package modules.
- Keep Linux-libre and free firmware as the shared defaults. The user authorized
  explicit host exceptions from the pinned, authenticated Nonguix channel:
  T490 uses standard Linux and iwlwifi-firmware; Zen uses standard Linux,
  iwlwifi-firmware, Intel i915/Xe graphics firmware, Intel SOF audio firmware,
  and Cirrus CS42L43/CS35L56 audio firmware for its subsystem 1043:1e13.
  Keep these choices host-specific; do not add AMD/NVIDIA firmware, expand to
  other hosts/nonfree packages, or introduce other prebuilt application binaries.
- Keep OXWM as a pinned source build. Codex is the user-authorized exception:
  Home build/reconfigure resolves the latest official stable Linux x86_64 musl
  release, then builds with its versioned URL and fixed SHA-256. Keep that
  resolution outside package evaluation and activation; do not use installers.
- Firefox Home updates must resolve the newest successful stable x86_64 Firefox
  available in the Nonguix cache before package evaluation. Fetch its signed
  store output and runtime closure with local builds and offloading disabled;
  abort on failure. Never fall back to a Firefox source build or a fixed Home
  version. Keep the Blix policies; keep other channels/packages pinned. The
  checked-in Firefox record is for offline evaluation only. Use scripts/guix.
- Picom must keep all windows opaque. Do not add transparency, fading or
  shadows without an explicit request.
- Preserve unrelated changes. Do not partition disks, activate the system, or
  reboot merely because configuration files changed. When requested work is
  complete, the relevant checks pass, and the change is ready, commit and push
  only the task-related changes. Leave unrelated working-tree changes untouched.
- Run `./scripts/guix repl -L modules scripts/check.scm`, the relevant package,
  system and Home builds, ShellCheck for changed scripts, and `git diff --check`.
  Report unavailable checks accurately; evaluation is not a build or boot test.
- Keep dependencies on sibling repositories out of runtime/build paths. Record
  copied sources and port decisions in `docs/sources.md`.
