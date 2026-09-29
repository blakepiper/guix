(define-module (workstation packages editor)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix build-system cargo)
  #:use-module (guix import crate)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages node)
  #:use-module (workstation files)
  #:export (tree-sitter-cli))

(define tree-sitter-cli
  (package
    (name "tree-sitter-cli")
    (version "0.26.1")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/tree-sitter/tree-sitter/tar.gz/refs/tags/v0.26.1")
       (file-name (string-append "tree-sitter-" version ".tar.gz"))
       (sha256 (base16-string->bytevector
                "c547e2e054ca7220e5b30b18ddf67aec4144cf9288ef5c8ef707c98dbe4951eb"))))
    (build-system cargo-build-system)
    (arguments
     (list
      #:rust rust-1.95
      #:install-source? #f
      #:parallel-build? #f
      #:cargo-build-flags ''("--release" "-p" "tree-sitter-cli")
      #:cargo-install-paths ''("crates/cli")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'configure 'limit-install-jobs
            (lambda _ (setenv "CARGO_BUILD_JOBS" "2")))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              ;; Upstream's full suite downloads unpinned grammar fixtures.
              (when tests? (invoke "target/release/tree-sitter" "--version")))))))
    ;; QuickJS's Rust binding generates bindings with libclang at build time.
    ;; cargo-build-system configures LIBCLANG_PATH for this input.
    (native-inputs (list clang))
    ;; This lockfile contains only registry sources (no Git workspaces).
    ;; Guix imports their published hashes without network access at evaluation.
    (inputs
     (cons node-lts
           (cargo-inputs-from-lockfile
            (local-file-file (repository-file "sources/tree-sitter/Cargo.lock")))))
    (home-page "https://tree-sitter.github.io/tree-sitter/")
    (synopsis "Tree-sitter CLI compatible with the pinned Neovim plugins")
    (description "Source-built Tree-sitter 0.26.1 CLI, the minimum supported by
the pinned nvim-treesitter configuration.  Dependencies are imported from
the upstream release lockfile and fetched as hash-checked source inputs.")
    (license license:expat)))
