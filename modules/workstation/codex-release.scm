(define-module (workstation codex-release)
  #:use-module (guix gexp)
  #:use-module (workstation files)
  #:use-module (json)
  #:use-module (ice-9 regex)
  #:use-module (srfi srfi-1)
  #:export (%codex-asset validate-codex-release github->codex-release
            read-codex-release))

;; Use the installer's complete runtime bundle. Its one digest covers the CLI,
;; code-mode host and all bundled resources from the same release. The similarly
;; named codex-x86_64 archive contains only the CLI and is not sufficient.
(define %codex-asset "codex-package-x86_64-unknown-linux-musl.tar.gz")

(define (matches? pattern value)
  (and (string? value) (string-match pattern value)))

(define (validate-codex-release release)
  (let ((version (assoc-ref release "version"))
        (tag (assoc-ref release "tag"))
        (url (assoc-ref release "url"))
        (hash (assoc-ref release "sha256")))
    (unless (and (matches? "^[0-9]+\\.[0-9]+\\.[0-9]+$" version)
                 (equal? tag (string-append "rust-v" version))
                 (equal? (assoc-ref release "asset") %codex-asset)
                 (equal? url (string-append
                              "https://github.com/openai/codex/releases/download/"
                              tag "/" %codex-asset))
                 (matches? "^[0-9a-f]{64}$" hash))
      (error "Invalid official stable Codex release metadata"))
    release))

(define (github->codex-release release)
  ;; Reject prereleases, missing digests/assets and unexpected download URLs;
  ;; never silently use an older release when the latest cannot be packaged.
  (let* ((tag (assoc-ref release "tag_name"))
         (assets (assoc-ref release "assets")))
    (unless (and (assoc "draft" release) (assoc "prerelease" release)
                 (eq? #f (assoc-ref release "draft"))
                 (eq? #f (assoc-ref release "prerelease"))
                 (matches? "^rust-v[0-9]+\\.[0-9]+\\.[0-9]+$" tag)
                 (vector? assets))
      (error "Latest upstream release is not a stable Codex CLI release"))
    (let* ((matching (filter (lambda (asset)
                               (equal? (assoc-ref asset "name") %codex-asset))
                             (vector->list assets)))
           (asset (and (= 1 (length matching)) (car matching)))
           (digest (and asset (assoc-ref asset "digest"))))
      (unless (and asset (equal? (assoc-ref asset "state") "uploaded")
                   (matches? "^sha256:[0-9a-f]{64}$" digest))
        (error "Latest Codex release lacks the complete musl runtime package with a SHA-256 digest"))
      (validate-codex-release
       `(("version" . ,(substring tag 6))
         ("tag" . ,tag)
         ("asset" . ,%codex-asset)
         ("url" . ,(assoc-ref asset "browser_download_url"))
         ("sha256" . ,(substring digest 7)))))))

(define (read-codex-release)
  ;; Home commands supply a private, per-invocation snapshot. Other commands
  ;; can evaluate offline using the checked-in reference release.
  (validate-codex-release
   (if (getenv "GUIX_CODEX_RELEASE_FILE")
       (call-with-input-file (getenv "GUIX_CODEX_RELEASE_FILE") json->scm)
       (assoc-ref (call-with-input-file
                      (local-file-file (repository-file "sources/releases.json"))
                    json->scm)
                  "codex"))))
