(define-module (workstation packages codex)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages rust)
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
          (replace 'build
            (lambda _
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
    (native-inputs (list rust-1.95 (list rust-1.95 "cargo") pkg-config cmake-minimal clang))
    (inputs (list openssl sqlite zlib (list zstd "lib") libcap bubblewrap ripgrep))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/openai/codex")
    (synopsis "Codex CLI compiled from the pinned release and locked sources")
    (description "Local source build of the Codex CLI and exec command.  Hosted
model services are separate from the free software client.  The optional V8
code-mode host is not included in this CLI build.")
    (license license:asl2.0)))
