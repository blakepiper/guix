;; Invoked automatically by scripts/guix before Home build/reconfigure.
(use-modules (guix http-client) (json) (workstation codex-release))

(catch #t
  (lambda ()
    (let* ((destination (or (getenv "GUIX_CODEX_RELEASE_FILE")
                            (error "Missing per-command Codex release file")))
           ;; No response cache: every Home invocation checks upstream again.
           (port (http-fetch "https://api.github.com/repos/openai/codex/releases/latest"
                             #:timeout 30))
           (release (github->codex-release (json->scm port))))
      (close-port port)
      (call-with-output-file destination
        (lambda (output) (scm->json release output) (newline output)))
      (format #t "Using latest stable Codex ~a: ~a (SHA-256 ~a).~%"
              (assoc-ref release "version") (assoc-ref release "asset")
              (assoc-ref release "sha256"))))
  (lambda (key . args)
    (format (current-error-port)
            "Cannot refresh latest stable Codex; Home command aborted: ~s ~s~%"
            key args)
    (exit 1)))
