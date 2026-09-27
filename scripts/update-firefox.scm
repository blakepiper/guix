;; Metadata only: downloads and signature verification are handled by Guix.
(use-modules (guix http-client) (json) (ice-9 textual-ports)
             (srfi srfi-34) (srfi srfi-1)
             (workstation firefox-release))

(define (release-history file)
  (let* ((port (http-fetch
                (string-append "https://product-details.mozilla.org/1.0/" file)
                #:timeout 30))
         (history (json->scm port)))
    (close-port port)
    (unless (and (list? history) (pair? history)
                 (every (lambda (entry)
                          (and (pair? entry) (string? (car entry))
                               (string? (cdr entry))))
                        history))
      (error "Invalid Mozilla stable release history" file))
    (map car history)))

(catch #t
  (lambda ()
    (let* ((destination (or (getenv "GUIX_FIREFOX_RELEASE_FILE")
                            (error "Missing per-command Firefox release file")))
           (stable-versions
            (append (release-history "firefox_history_major_releases.json")
                    (release-history "firefox_history_stability_releases.json")))
           (port (http-fetch
                  "https://cuirass.nonguix.org/api/latestbuilds?job=firefox.x86_64-linux&system=x86_64-linux&nr=100" #:timeout 30))
           (candidates (firefox-candidates (json->scm port) stable-versions)))
      (close-port port)
      (let loop ((remaining candidates))
        (when (null? remaining)
          (error "No cached stable Firefox among the latest 100 builds"))
        (let* ((release (car remaining))
               (path (assoc-ref release "path"))
               (url (string-append "https://substitutes.nonguix.org/"
                                   (substring (basename path) 0 32) ".narinfo"))
               (metadata
                (guard (condition
                        ((and (http-get-error? condition)
                              (= 404 (http-get-error-code condition))) #f))
                    (let* ((input (http-fetch url #:timeout 30))
                           (text (get-string-all input)))
                      (close-port input)
                      text))))
          (if (not metadata)
              (loop (cdr remaining))
              (begin
                (unless (string-contains metadata (string-append "StorePath: " path "\n"))
                  (error "Cache returned metadata for a different Firefox"))
                (call-with-output-file destination
                  (lambda (output) (scm->json release output) (newline output)))
                ;; Separate file avoids interpreting metadata as shell code.
                (call-with-output-file (string-append destination ".path")
                  (lambda (output) (display path output) (newline output)))
                (format #t "Using newest cached stable Firefox ~a: ~a~%"
                        (assoc-ref release "version") path)))))))
  (lambda (key . args)
    (format (current-error-port)
            "Cannot resolve cached Firefox; Home command aborted: ~s ~s~%" key args)
    (exit 1)))
