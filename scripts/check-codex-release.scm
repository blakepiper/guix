;; Offline regression checks for automatic release selection.
(use-modules (workstation codex-release) (json) (srfi srfi-1) (srfi srfi-64))

(let* ((asset `(("name" . ,%codex-asset)
                ("state" . "uploaded")
                ("browser_download_url" .
                 "https://github.com/openai/codex/releases/download/rust-v99.1.2/codex-x86_64-unknown-linux-musl.tar.gz")
                ("digest" . ,(string-append "sha256:" (make-string 64 #\a)))))
       (release `(("tag_name" . "rust-v99.1.2")
                  ("draft" . #f) ("prerelease" . #f)
                  ("assets" . ,(vector asset)))))
  (define (replace-field data key value)
    (acons key value (alist-delete key data)))
  (define (with-asset key value)
    (replace-field release "assets" (vector (replace-field asset key value))))
  (test-begin "codex-release")
  (test-equal "new stable versions need no recipe edit" "99.1.2"
    (assoc-ref (github->codex-release release) "version"))
  (test-equal "preserve upstream digest" (make-string 64 #\a)
    (assoc-ref (github->codex-release release) "sha256"))
  (test-error "reject prereleases" #t
    (github->codex-release (replace-field release "prerelease" #t)))
  (test-error "reject drafts" #t
    (github->codex-release (replace-field release "draft" #t)))
  (test-error "require explicit stable status" #t
    (github->codex-release (alist-delete "prerelease" release)))
  (test-error "reject non-CLI release tags" #t
    (github->codex-release (replace-field release "tag_name" "sdk-v99.1.2")))
  (test-error "require musl asset" #t
    (github->codex-release (replace-field release "assets" #())))
  (test-error "reject duplicate assets" #t
    (github->codex-release (replace-field release "assets" (vector asset asset))))
  (test-error "require complete upload" #t
    (github->codex-release (with-asset "state" "starter")))
  (test-error "require digest" #t
    (github->codex-release (with-asset "digest" #f)))
  (test-error "reject malformed digest" #t
    (github->codex-release (with-asset "digest" "sha256:abc")))
  (test-error "reject moving download URLs" #t
    (github->codex-release
     (with-asset "browser_download_url"
                 "https://github.com/openai/codex/releases/latest/download/codex-x86_64-unknown-linux-musl.tar.gz")))
  (test-error "reject unofficial download URLs" #t
    (github->codex-release
     (with-asset "browser_download_url" "https://example.org/codex.tar.gz")))
  (test-error "reject mismatched release version" #t
    (github->codex-release (replace-field release "tag_name" "rust-v99.1.3")))
  (let* ((file (string-append (or (getenv "TMPDIR") "/tmp")
                              "/codex-release-test.XXXXXX"))
         (port (mkstemp! file))
         (previous (getenv "GUIX_CODEX_RELEASE_FILE")))
    (scm->json (github->codex-release release) port)
    (close-port port)
    (dynamic-wind
      (lambda () (setenv "GUIX_CODEX_RELEASE_FILE" file))
      (lambda ()
        (test-equal "snapshot overrides checked-in version" "99.1.2"
          (assoc-ref (read-codex-release) "version"))
        (call-with-output-file file (lambda (output) (display "{}" output)))
        (test-error "bad snapshot must not fall back to reference" #t
          (read-codex-release)))
      (lambda ()
        (if previous (setenv "GUIX_CODEX_RELEASE_FILE" previous)
            (unsetenv "GUIX_CODEX_RELEASE_FILE"))
        (delete-file file))))
  (let ((runner (test-runner-current)))
    (test-end "codex-release")
    (unless (zero? (test-runner-fail-count runner))
      (error "Codex release regression checks failed"))))
