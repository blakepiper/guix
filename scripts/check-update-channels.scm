;; Exercise the real resolver/serialization with Guix's network/store boundary
;; mocked. Authentication itself is provided by Guix, not reimplemented here.
(use-modules (guix channels) (guix store) (guix tests)
             (ice-9 textual-ports) (ice-9 pretty-print)
             (srfi srfi-1) (srfi srfi-64))

(define previous (primitive-load "channels.scm"))
(define new-commit (make-string 40 #\a))
(define work (mkdtemp "/tmp/guix-update-check.XXXXXX"))
(define source (string-append work "/previous.scm"))
(define destination (string-append work "/candidate.scm"))
(define arguments (command-line))
(define (contents file) (call-with-input-file file get-string-all))
(define (write-channels entries)
  (call-with-output-file source
    (lambda (port) (pretty-print `(list ,@(map channel->code entries)) port))))

(define (run-resolver mode)
  (call-with-output-file destination (lambda (port) (display "untouched" port)))
  (mock ((guix store) call-with-store (lambda (proc) (proc #f)))
    (mock ((guix channels) latest-channel-instances
           (lambda* (store channels #:key current-channels authenticate?
                           verify-certificate? validate-pull)
             (unless (and authenticate? verify-certificate?
                          (eq? validate-pull ensure-forward-channel-update)
                          (equal? (map channel->code current-channels)
                                  (map channel->code previous))
                          (every (lambda (c) (not (channel-commit c))) channels))
               (error "Resolution must authenticate forward updates from the old pins"))
             (when (eq? mode 'authentication-failure)
               (error "Simulated authentication failure"))
             (for-each
              (lambda (c)
                (validate-pull c (channel-commit (car previous)) new-commit
                               (if (eq? mode 'backward) 'descendant 'ancestor)))
              channels)
             (let ((resolved
                    (map (lambda (entry)
                           ((@@ (guix channels) channel-instance)
                            (if (eq? mode 'changed-metadata)
                                (channel (inherit entry) (url "https://example.org/changed"))
                                entry)
                            (if (eq? mode 'unchanged)
                                (channel-commit
                                 (find (lambda (old)
                                         (eq? (channel-name old) (channel-name entry)))
                                       previous))
                                new-commit)
                            "/unused-checkout"))
                         channels)))
               (if (eq? mode 'extra-channel)
                   (cons (checkout->channel-instance "/unused" #:name 'unexpected)
                         resolved)
                   resolved))))
      (dynamic-wind
        (lambda ()
          (set-program-arguments (list "update-channels.scm" source destination)))
        (lambda () (primitive-load "scripts/update-channels.scm"))
        (lambda () (set-program-arguments arguments))))))

(dynamic-wind
  (lambda () (copy-file "channels.scm" source))
  (lambda ()
    (test-begin "channel-update")
    (run-resolver 'forward)
    (let ((updated (primitive-load destination)))
      (test-equal "new commits are pinned" (list new-commit new-commit)
        (map channel-commit updated))
      (test-equal "URLs, branches and introductions survive serialization"
        (map (lambda (c) (channel->code (channel (inherit c) (commit #f)))) previous)
        (map (lambda (c) (channel->code (channel (inherit c) (commit #f)))) updated)))
    (run-resolver 'unchanged)
    (test-equal "unchanged pins retain exact source text" (contents source)
      (contents destination))
    (for-each
     (lambda (mode)
       (test-error (symbol->string mode) #t (run-resolver mode))
       (test-equal "failed resolution never writes candidate pins" "untouched"
         (contents destination)))
     '(authentication-failure backward changed-metadata extra-channel))
    (write-channels (map (lambda (c) (channel (inherit c) (introduction #f))) previous))
    (test-error "reject channels without trust anchors" #t (run-resolver 'forward))
    (write-channels (map (lambda (c) (channel (inherit c) (commit #f))) previous))
    (test-error "reject unpinned starting channels" #t (run-resolver 'forward))
    (let ((runner (test-runner-current)))
      (test-end "channel-update")
      (unless (zero? (test-runner-fail-count runner))
        (error "Channel update regression checks failed"))))
  (lambda ()
    (delete-file source)
    (when (file-exists? destination) (delete-file destination))
    (rmdir work)))
