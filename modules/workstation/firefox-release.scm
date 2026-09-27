(define-module (workstation firefox-release)
  #:use-module (guix gexp)
  #:use-module (guix monads)
  #:use-module (guix store)
  #:use-module (guix utils)
  #:use-module (workstation files)
  #:use-module (json)
  #:use-module (ice-9 regex)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:export (validate-firefox-release firefox-candidates read-firefox-release
            cached-firefox cached-firefox? cached-firefox-path))

;; A store reference, not a local-file import (which would rehash/copy the
;; directory) or a package (which would retain a source-build derivation).
(define-record-type <cached-firefox>
  (cached-firefox path)
  cached-firefox?
  (path cached-firefox-path))

(define-gexp-compiler (cached-firefox-compiler (firefox <cached-firefox>) system target)
  (with-monad %store-monad
    (return (cached-firefox-path firefox))))

(define (validate-firefox-release release)
  (let ((version (assoc-ref release "version"))
        (path (assoc-ref release "path")))
    (unless (and (string? version)
                 (string-match "^[0-9]+(\\.[0-9]+)+$" version)
                 (string? path)
                 (string-match "^/gnu/store/[0-9abcdfghijklmnpqrsvwxyz]{32}-firefox-[0-9.]+$" path)
                 (string-suffix? (string-append "-firefox-" version) path))
      (error "Invalid cached stable Firefox release" release))
    release))

(define (firefox-candidates builds stable-versions)
  ;; The API is ordered newest build first; stable sort keeps that order for
  ;; rebuilds of the same version. ESR, other systems and failed jobs cannot win.
  (stable-sort
   (filter-map
    (lambda (build)
      (and (equal? (assoc-ref build "job") "firefox.x86_64-linux")
           (equal? (assoc-ref build "jobset") "nonguix")
           (equal? (assoc-ref build "system") "x86_64-linux")
           (equal? (assoc-ref build "buildstatus") 0)
           (equal? (assoc-ref build "finished") 1)
           (let ((name (assoc-ref build "nixname")))
             (and (string? name)
                  (string-match "^firefox-[0-9]+(\\.[0-9]+)+$" name)
                  ;; A numeric version alone does not prove a stable release.
                  (member (substring name 8) stable-versions)
                  (validate-firefox-release
                   `(("version" . ,(substring name 8))
                     ("path" . ,(assoc-ref
                                 (assoc-ref (assoc-ref build "buildoutputs") "out")
                                 "path"))))))))
    (vector->list builds))
   (lambda (a b) (version>? (assoc-ref a "version") (assoc-ref b "version")))))

(define (read-firefox-release)
  ;; No network or mutable resolution during package evaluation/activation.
  (validate-firefox-release
   (call-with-input-file
       (or (getenv "GUIX_FIREFOX_RELEASE_FILE")
           (local-file-file (repository-file "sources/firefox.json")))
     json->scm)))
