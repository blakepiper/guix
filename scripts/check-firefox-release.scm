(use-modules (workstation firefox-release) (srfi srfi-1)
             (guix gexp) (guix store))

(define (fixture version status system job)
  (let ((path (string-append
               "/gnu/store/ybk9mpvi5aw47hr1bwpf1bqnqjv2x3ml-firefox-" version)))
    `(("job" . ,job) ("jobset" . "nonguix") ("system" . ,system)
      ("buildstatus" . ,status) ("finished" . 1)
      ("nixname" . ,(string-append "firefox-" version))
      ("buildoutputs" . (("out" . (("path" . ,path))))))))

(let ((candidates
       (firefox-candidates
        (vector (fixture "99.0" 0 "x86_64-linux" "firefox.x86_64-linux")
                (fixture "157.0" 1 "x86_64-linux" "firefox.x86_64-linux")
                (fixture "158.0" 0 "aarch64-linux" "firefox.aarch64-linux")
                (fixture "159.0" 0 "x86_64-linux" "firefox-esr.x86_64-linux")
                (fixture "160.0b1" 0 "x86_64-linux" "firefox.x86_64-linux")
                (fixture "161.0a1" 0 "x86_64-linux" "firefox.x86_64-linux")
                (fixture "162.0" 0 "x86_64-linux" "firefox.x86_64-linux")
                (fixture "156.0.1" 0 "x86_64-linux" "firefox.x86_64-linux")
                (fixture "156.0" 0 "x86_64-linux" "firefox.x86_64-linux"))
        '("99.0" "156.0" "156.0.1" "157.0" "158.0" "159.0"))))
  (unless (equal? (map (lambda (release) (assoc-ref release "version")) candidates)
                  '("156.0.1" "156.0" "99.0"))
    (error "Firefox selection must exclude failed/foreign/ESR/beta/nightly/unreleased builds")))

(unless (null? (firefox-candidates
                (vector (fixture "156.0" 0 "x86_64-linux" "firefox.x86_64-linux"))
                '()))
  (error "Missing stable history must not allow a candidate"))

(for-each
 (lambda (release)
   (when (catch #t (lambda () (validate-firefox-release release) #t)
                (lambda _ #f))
     (error "Invalid Firefox metadata accepted" release)))
 '((("version" . "156.0") ("path" . "/tmp/firefox"))
   (("version" . "157.0")
    ("path" . "/gnu/store/ybk9mpvi5aw47hr1bwpf1bqnqjv2x3ml-firefox-156.0"))))
;; A disconnected store catches accidental daemon calls or re-imports. The
;; file-like input must lower to the exact signed output, never a derivation.
(let* ((port (open-input-string ""))
       (store (port->connection port #:built-in-builders '()))
       (path (assoc-ref (read-firefox-release) "path")))
  (unless (equal? path (run-with-store store (lower-object (cached-firefox path))))
    (error "Cached Firefox must lower directly to its store path"))
  (close-port port))
(display "Firefox cache selection, metadata and store-reference checks passed.\n")
