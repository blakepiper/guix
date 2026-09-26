(define-module (workstation packages codex)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages virtualization)
  #:use-module (gnu packages rust-apps)
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
       (file-name (string-append "codex-" version "-x86_64-linux-musl.tar.gz"))
       (sha256
        (base16-string->bytevector
         (assoc-ref codex-release "sha256")))))
    ;; No implicit GNU compiler inputs or source-rewriting phases.
    (build-system trivial-build-system)
    (arguments
     '(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((out (assoc-ref %outputs "out"))
                (bin (string-append out "/bin"))
                (program (string-append bin "/codex")))
           (setenv "PATH" (string-append (assoc-ref %build-inputs "gzip") "/bin"))
           (invoke (string-append (assoc-ref %build-inputs "tar") "/bin/tar")
                   "xzf" (assoc-ref %build-inputs "source"))
           (mkdir-p bin)
           ;; The official archive contains exactly this static PIE executable.
           (copy-file "codex-x86_64-unknown-linux-musl" program)
           (chmod program #o555)
           ;; Standalone Codex finds these tools on PATH. Do not fabricate a
           ;; managed-daemon package or replace upstream's binary contents.
           (wrap-program program
             #:sh (string-append (assoc-ref %build-inputs "bash-minimal") "/bin/bash")
             `("PATH" prefix
               (,(string-append (assoc-ref %build-inputs "bubblewrap") "/bin")
                ,(string-append (assoc-ref %build-inputs "ripgrep") "/bin"))))
           ;; This release otherwise tries to provision a managed daemon from
           ;; package metadata absent from the official single-binary archive.
           ;; Keep explicit standalone/remote options intact and stop scanning
           ;; at the argument separator (a prompt may look like an option).
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
           ;; Offline smoke checks use disposable state, never user credentials.
           (setenv "HOME" (getcwd))
           (setenv "CODEX_HOME" (string-append (getcwd) "/test-codex-home"))
           (mkdir-p (getenv "CODEX_HOME"))
           (invoke program "--version")
           (invoke program "--help")
           (invoke program "--no-daemon" "--version")
           (invoke program "exec" "--help")))))
    (native-inputs (list tar gzip))
    (inputs (list bash-minimal bubblewrap ripgrep))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/openai/codex")
    (synopsis "Official standalone Codex CLI for Linux x86-64")
    (description "Install OpenAI's versioned, checksum-pinned musl release of
Codex CLI without compiling it.  The executable is statically linked; a Guix
wrapper supplies bubblewrap and ripgrep and selects standalone mode, while
preserving user configuration and authentication.  Hosted model services are
separate from the client.")
    (license license:asl2.0)))
