(define-module (workstation packages browser)
  #:use-module (guix packages)
  #:use-module (guix build-system trivial)
  #:use-module ((nongnu packages mozilla) #:prefix mozilla:)
  #:use-module (workstation firefox-release)
  #:use-module (workstation files))

(define firefox-release (read-firefox-release))

(define-public firefox-blix
  (package
    (inherit mozilla:firefox)
    (name "firefox-blix")
    (version (assoc-ref firefox-release "version"))
    (supported-systems '("x86_64-linux"))
    (source #f)
    ;; Consume only the resolved store output; no Firefox source derivation.
    ;; Policies belong in the physical application directory; a dotfile or a symlink to the
    ;; original executable would not reliably select this distribution policy.
    (build-system trivial-build-system)
    (arguments
     '(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils) (ice-9 regex) (ice-9 textual-ports))
         (let* ((base (assoc-ref %build-inputs "firefox"))
                (out (assoc-ref %outputs "out"))
                (wrapper (string-append out "/lib/firefox/firefox"))
                (launcher (string-append out "/bin/firefox")))
           (copy-recursively base out #:follow-symlinks? #f)
           ;; The channel wraps lib/firefox/firefox; its .firefox-real must be
           ;; a physical copy here so Gecko reads this directory's policies.
           (unless (and (file-exists? (string-append out "/lib/firefox/.firefox-real"))
                        (not (symbolic-link? (string-append out "/lib/firefox/.firefox-real")))
                        (string=? (call-with-input-file wrapper
                                    (lambda (port) (get-string-n port 2))) "#!"))
             (error "Unexpected Firefox layout; review policy installation"))
           (chmod wrapper #o755)
           (substitute* wrapper (((regexp-quote base)) out))
           (delete-file launcher)
           (symlink "../lib/firefox/firefox" launcher)
           (for-each
            (lambda (desktop)
              (chmod desktop #o644)
              (substitute* desktop (((regexp-quote base)) out)))
            (find-files (string-append out "/share/applications") "\\.desktop$"))
           (let ((policy (string-append out "/lib/firefox/distribution/policies.json")))
             (mkdir-p (dirname policy))
             (when (file-exists? policy) (delete-file policy))
             (copy-file (assoc-ref %build-inputs "policies") policy))))))
    (native-inputs '())
    (inputs
     `(("firefox" ,(cached-firefox (assoc-ref firefox-release "path")))
       ("policies" ,(repository-file "home/przvl/config/firefox/policies.json"))))
    (synopsis "Firefox with the Blix privacy policies")
    (description "Firefox from the Nonguix binary cache with the workstation's
Blix enterprise policies: strict tracking protection, Global Privacy Control,
blocked AI features and sponsored content, plus managed privacy extensions.
The policy layer reuses the existing Firefox package without recompiling it.")))
