;; Run from the repository root; see README.md. No daemon or compilation is
;; needed once the pinned Guix runtime and source archive are available.
(use-modules (guix packages) (guix gexp) (guix utils) (guix hash)
             (guix base16) (gcrypt hash) (json)
             (guix build utils) (guix build gnu-build-system)
             (workstation packages codex)
             (srfi srfi-1) (ice-9 match) (ice-9 textual-ports))

(define archive
  (canonicalize-path "sources/codex-0.157.1-vendored.tar.gz"))

;; Only the install phase references store outputs. Its approximate output
;; expressions are never executed: exercise the recipe's real pre-build phases
;; without lowering a derivation or replacing its phase list with a test copy.
(define phases
  (let ((builder (make-fresh-user-module)))
    ;; Keep host-side (guix packages)'s `replace' syntax out of the builder.
    (for-each (lambda (name) (module-use! builder (resolve-interface name)))
              '((guix build utils) (guix build gnu-build-system)))
    (eval (gexp->approximate-sexp
           (let loop ((args (package-arguments codex-source)))
             (if (eq? (car args) #:phases)
                 (cadr args)
                 (loop (cddr args)))))
          builder)))

(define (require condition message)
  (unless condition (error message)))

(define (write-fixture file text)
  (call-with-output-file file (lambda (port) (display text port))))

(define (digest file)
  (bytevector->base16-string (file-sha256 file)))

(call-with-temporary-directory
 (lambda (directory)
   (with-directory-excursion directory
     (invoke "tar" "xf" archive)
     (with-directory-excursion "codex-source"
       ;; Check Cargo's original per-file digests, not regenerated checksums.
       (let ((checksums (find-files "codex-rs/vendor" "^\\.cargo-checksum\\.json$")))
         (require (pair? checksums) "No vendored Cargo checksums found")
         (for-each
          (lambda (file)
            (let ((data (call-with-input-file file json->scm)))
              (for-each
               (match-lambda
                 ((name . expected)
                  (require (string=? expected
                                     (digest (string-append (dirname file) "/" name)))
                           (string-append "Cargo checksum mismatch: " file ": " name))))
               (assoc-ref data "files"))))
          checksums)
         (format #t "Verified original checksums for ~a vendored crates.~%"
                 (length checksums)))
       (let ((before (file-hash* "codex-rs/vendor" #:recursive? #t)))
         ;; Controls outside vendor prove we retain necessary GNU rewriting.
         (mkdir-p "codex-rs/phase-probe")
         (write-fixture "source-probe" "#!/bin/sh\nexit 0\n")
         (write-fixture "codex-rs/phase-probe/configure"
                        "#!/bin/sh\n/usr/bin/file --version\n")
         (chmod "codex-rs/phase-probe/configure" #o755)
         (write-fixture "codex-rs/phase-probe/Makefile" "SHELL = /bin/sh\n")
         (let ((source-before (digest "source-probe"))
               (configure-before (digest "codex-rs/phase-probe/configure"))
               (makefile-before (digest "codex-rs/phase-probe/Makefile"))
               (generated-before #f))
           (for-each
            (match-lambda
              ((name . phase)
               (format #t "Exercising recipe phase: ~a~%" name)
               ;; configure only uses these paths to set environment variables;
               ;; this test neither invokes Cargo nor links native libraries.
               (phase #:inputs '(("openssl" . "/unused-test-input")
                                 ("clang" . "/unused-test-input")))
               (when (eq? name 'configure)
                 (write-fixture "generated-probe" "#!/bin/sh\nexit 0\n")
                 (chmod "generated-probe" #o755)
                 (set! generated-before (digest "generated-probe")))))
            (take-while (lambda (entry) (not (eq? (car entry) 'build)))
                        (cdr (memq (assq 'unpack phases) phases))))
           ;; The real configure phase has entered codex-rs.
           (require (equal? before (file-hash* "vendor" #:recursive? #t))
                    "Pre-build phases changed the Cargo vendor tree")
           (require (not (string=? source-before (digest "../source-probe")))
                    "Source shebang handling was lost")
           (require (not (string=? configure-before (digest "phase-probe/configure")))
                    "Configure script handling was lost")
           (require (not (string-contains
                          (call-with-input-file "phase-probe/configure" get-string-all)
                          "/usr/bin/file"))
                    "Configure /usr/bin/file handling was lost")
           (require (not (string=? makefile-before (digest "phase-probe/Makefile")))
                    "Makefile shell handling was lost")
           (require (and generated-before
                         (not (string=? generated-before (digest "generated-probe"))))
                    "Generated shebang handling was lost")
           (require (eq? (assoc-ref phases 'patch-shebangs)
                         (assoc-ref %standard-phases 'patch-shebangs))
                    "Installed-output shebang handling was changed")
           (display "Codex vendor bytes and checksum files survived all pre-build phases.\n")))))))
