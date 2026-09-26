(define-module (workstation packages codex)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages sqlite)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages virtualization)
  #:use-module (gnu packages rust-apps)
  #:use-module (workstation files))

(define-public codex-source
  (package
    (name "codex-source")
    (version "0.157.1")
    ;; scripts/prepare-codex.py verifies the upstream archive and vendors the
    ;; exact dependency sources before Guix starts its network-isolated build.
    (source (repository-file "sources/codex-0.157.1-vendored.tar.gz"))
    (build-system gnu-build-system)
    (arguments
     (list
      #:substitutable? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'protect-cargo-vendor
            (lambda _
              ;; GNU's source/generated shebang and /usr/bin/file patchers
              ;; recurse through the source tree. Cargo authenticates these
              ;; files against .cargo-checksum.json, including test fixtures.
              ;; Keep the vendor tree outside their traversal, without a
              ;; symlink, while retaining normal patching of our own sources.
              (rename-file "codex-rs/vendor" "../codex-cargo-vendor")))
          (replace 'configure
            (lambda* (#:key inputs #:allow-other-keys)
              (chdir "codex-rs")
              (setenv "HOME" (getcwd))
              (setenv "CARGO_HOME" (string-append (getcwd) "/.cargo-home"))
              (setenv "CARGO_NET_OFFLINE" "true")
              (setenv "OPENSSL_NO_VENDOR" "1")
              (setenv "OPENSSL_DIR" (assoc-ref inputs "openssl"))
              (setenv "LIBSQLITE3_SYS_USE_PKG_CONFIG" "1")
              (setenv "ZSTD_SYS_USE_PKG_CONFIG" "1")
              (setenv "LIBCLANG_PATH" (string-append (assoc-ref inputs "clang") "/lib"))))
          (add-before 'build 'restore-cargo-vendor
            (lambda _
              ;; configure has changed directory to codex-rs. Restore the
              ;; exact bytes only after all pre-build GNU rewriting phases.
              (rename-file "../../codex-cargo-vendor" "vendor")))
          (replace 'build
            (lambda _
              ;; cc-rs defaults to cc/c++ on this target. Check the complete
              ;; native compile/archive/link path before the long Rust build;
              ;; this deliberately runs in the derivation's isolated PATH.
              (for-each (lambda (tool)
                          (unless (which tool)
                            (error "Missing native toolchain executable" tool)))
                        '("cc" "c++" "ar" "as" "ld" "ranlib"))
              (mkdir "native-toolchain-check")
              (with-directory-excursion "native-toolchain-check"
                (call-with-output-file "probe.c"
                  (lambda (port)
                    (display "#include <stdlib.h>\nint native_answer(int n) { return abs(n); }\n" port)))
                (call-with-output-file "probe.cc"
                  (lambda (port)
                    (display "#include <iostream>\nextern \"C\" int native_answer(int);\nint main() { std::cout << native_answer(-42); return native_answer(-42) == 42 ? 0 : 1; }\n" port)))
                (invoke "cc" "-c" "probe.c" "-o" "probe.o")
                (invoke "ar" "rcs" "libprobe.a" "probe.o")
                (invoke "ranlib" "libprobe.a")
                (invoke "c++" "probe.cc" "-L." "-lprobe" "-o" "probe")
                (invoke "./probe"))
              (invoke "cargo" "build" "--frozen" "--release" "-j2"
                      "-p" "codex-cli" "--bin" "codex"
                      "-p" "codex-exec" "--bin" "codex-exec")))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              ;; The full integration suite requires network, namespaces and
              ;; live API credentials. Exercise the built offline CLI here.
              (when tests?
                (invoke "target/release/codex" "--version")
                (invoke "target/release/codex" "--help"))))
          (replace 'install
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((bin (string-append #$output "/bin"))
                    (resources (string-append #$output "/codex-resources"))
                    (path (string-append #$output "/codex-path")))
                (install-file "target/release/codex" bin)
                (install-file "target/release/codex-exec" bin)
                ;; Real files: the daemon rejects outward-pointing symlinks
                ;; when it copies the release layout to its managed directory.
                (install-file (search-input-file inputs "/bin/bwrap") resources)
                (install-file (search-input-file inputs "/bin/rg") path)
                (call-with-output-file (string-append #$output "/codex-package.json")
                  (lambda (port)
                    (display "{\"layoutVersion\":1,\"version\":\"0.157.1\",\"target\":\"x86_64-unknown-linux-gnu\",\"variant\":\"codex\",\"entrypoint\":\"bin/codex\",\"resourcesDir\":\"codex-resources\",\"pathDir\":\"codex-path\"}\n" port)))
                (install-file "../LICENSE" (string-append #$output "/share/licenses/codex"))))))))
    ;; Match scripts/codex-manifest.scm and upstream rust-toolchain.toml.
    ;; This binding exists at our channel pin but is hidden from name lookup.
    ;; GNU's implicit GCC has gcc/g++ but no cc alias. gcc-toolchain supplies
    ;; cc, C++, libc and Binutils with Guix's linker wrapper. Keep clang for
    ;; bindgen's LIBCLANG_PATH, rather than switching the native compiler.
    (native-inputs (list rust-1.95 (list rust-1.95 "cargo") gcc-toolchain
                         pkg-config cmake-minimal clang))
    (inputs (list openssl sqlite zlib (list zstd "lib") libcap bubblewrap ripgrep))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/openai/codex")
    (synopsis "Codex CLI compiled from the pinned release and locked sources")
    (description "Local source build of the Codex CLI and exec command.  Hosted
model services are separate from the free software client.  The optional V8
code-mode host is not included in this CLI build.")
    (license license:asl2.0)))
