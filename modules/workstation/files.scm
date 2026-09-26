(define-module (workstation files)
  #:use-module (guix gexp)
  #:export (repository-file))

;; Resolve relative to this module, never to the invoking shell's directory.
(define %root
  (dirname (dirname (dirname (canonicalize-path (search-path %load-path "workstation/files.scm"))))))

(define* (repository-file path #:key (recursive? #f))
  (local-file (string-append %root "/" path) #:recursive? recursive?))
