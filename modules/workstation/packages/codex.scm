(define-module (workstation packages codex)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages python)
  #:use-module (workstation files)
  #:use-module (workstation codex-release))

(define-public codex-release (read-codex-release))

(define-public codex
  (package
    (name "codex")
    (version (assoc-ref codex-release "version"))
    (source
     (origin
       (method url-fetch)
       (uri (assoc-ref codex-release "url"))
       (file-name (string-append "codex-package-" version "-x86_64-linux-musl.tar.gz"))
       (sha256
        (base16-string->bytevector
         (assoc-ref codex-release "sha256")))))
    ;; The installer bundle contains every companion from this same release.
    ;; No Rust build, source rewriting, installer or activation-time downloads.
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((out (assoc-ref %outputs "out"))
                (program (string-append out "/bin/codex"))
                (python (string-append (assoc-ref %build-inputs "python") "/bin/python3"))
                (check (assoc-ref %build-inputs "runtime-check")))
           (setenv "PATH" (string-append (assoc-ref %build-inputs "gzip") "/bin"))
           (mkdir-p out)
           (invoke (string-append (assoc-ref %build-inputs "tar") "/bin/tar")
                   "xzf" (assoc-ref %build-inputs "source") "-C" out)
           ;; Preserve upstream layout and binaries. Even this musl bundle ships
           ;; GNU-linked Zsh/voice resources: relocate their loader/RUNPATH to
           ;; Guix, and verify the entire dynamic dependency closure.
           (invoke python check out ,version "--relocate"
                   (string-append (assoc-ref %build-inputs "patchelf") "/bin/patchelf")
                   (assoc-ref %build-inputs "glibc")
                   (assoc-ref %build-inputs "ncurses-with-tinfo"))
           ;; .codex-real stays in bin beside the host; physical executable
           ;; discovery still finds the unmodified upstream package metadata.
           (wrap-program program
             #:sh (string-append (assoc-ref %build-inputs "bash-minimal") "/bin/bash")
             (list "PATH" 'prefix (list (string-append out "/codex-path"))))
           ;; Retain this workstation's standalone default and remote override.
           ;; Do not provision a mutable daemon copy outside the Guix generation.
           (substitute* program
             (("exec -a")
              (string-append
               "standalone=(--no-daemon)\n"
               "for arg do\n"
               "  case \"$arg\" in\n"
               "    --) break ;;\n"
               "    --no-daemon|--remote|--remote=*) standalone=(); break ;;\n"
               "  esac\n"
               "done\n"
               "set -- \"${standalone[@]}\" \"$@\"\n"
               "exec -a")))
           ;; Offline, isolated state plus a loopback mock API. This must really
           ;; execute code through the discovered host, not just print --help.
           (invoke python check out ,version)))))
    (native-inputs
     `(("tar" ,tar)
       ("gzip" ,gzip)
       ("patchelf" ,patchelf)
       ("python" ,python-minimal)
       ("runtime-check" ,(repository-file "scripts/check-codex-runtime.py"))))
    (inputs (list bash-minimal glibc ncurses/tinfo))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/openai/codex")
    (synopsis "Official complete Codex runtime for Linux x86-64")
    (description "Install the complete official Codex runtime bundle for one
resolved stable release, verified by Guix with SHA-256.  The CLI, code-mode
host, search and sandbox tools, Zsh and voice resources retain their upstream
layout.  Dynamic helpers use Guix libraries; the launcher selects standalone
mode and preserves user configuration and authentication.")
    (license license:asl2.0)))
