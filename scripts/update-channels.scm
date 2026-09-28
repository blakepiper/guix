;; Called by scripts/update under the repository's existing pinned Guix.
(use-modules (guix channels) (guix store)
             (ice-9 match) (ice-9 pretty-print) (ice-9 regex)
             (srfi srfi-1))

(define (channel-names channels)
  (sort (map channel-name channels)
        (lambda (a b) (string<? (symbol->string a) (symbol->string b)))))

(define (without-commit entry)
  (channel (inherit entry) (commit #f)))

(match (command-line)
  ((_ source destination)
   (let ((previous (primitive-load source)))
     (unless (and (list? previous) (every channel? previous)
                  (equal? (channel-names previous) '(guix nonguix))
                  (every (lambda (entry)
                           (and (channel-introduction entry)
                                (string? (channel-commit entry))
                                (string-match "^[0-9a-f]{40}$"
                                              (channel-commit entry))))
                         previous))
       (error "Expected pinned, introduced Guix and Nonguix channels"))
     (with-store store
       (let* ((instances
               (latest-channel-instances
                store (map without-commit previous)
                #:current-channels previous
                #:authenticate? #t
                #:verify-certificate? #t
                #:validate-pull ensure-forward-channel-update))
              (resolved (map channel-instance-channel instances)))
         ;; A dependency must not silently add a channel or change its trust
         ;; anchor, URL or branch. Such changes need a deliberate repo edit.
         (unless (equal? (channel-names previous) (channel-names resolved))
           (error "Channel dependencies changed; review them before updating"))
         (let ((updated
                (map
                 (lambda (entry)
                   (let* ((instance
                           (find (lambda (instance)
                                   (eq? (channel-name entry)
                                        (channel-name
                                         (channel-instance-channel instance))))
                                 instances))
                          (resolved (channel-instance-channel instance)))
                     (unless (equal? (channel->code (without-commit entry))
                                     (channel->code (without-commit resolved)))
                       (error "Channel metadata changed" (channel-name entry)))
                     (format #t "~a: ~a -> ~a~%" (channel-name entry)
                             (channel-commit entry)
                             (channel-instance-commit instance))
                     (channel (inherit entry)
                              (commit (channel-instance-commit instance)))))
                 previous)))
           (if (equal? (map channel->code previous) (map channel->code updated))
               ;; Avoid a formatting-only diff when there are no new commits.
               (copy-file source destination)
               (call-with-output-file destination
                 (lambda (port)
                   (display ";; Authenticated channel pins; refresh with ./scripts/update.\n"
                            port)
                   (pretty-print `(list ,@(map channel->code updated)) port)))))))))
  (_ (error "Usage: update-channels.scm SOURCE DESTINATION")))
