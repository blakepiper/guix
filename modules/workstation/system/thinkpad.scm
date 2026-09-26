(define-module (workstation system thinkpad)
  #:use-module (gnu)
  #:use-module (gnu services shepherd)
  #:use-module (gnu services linux)
  #:export (thinkpad-services))

(define (thinkpad-services limit)
  (unless (and (integer? limit) (<= 1 limit 100))
    (error "Invalid battery charge threshold" limit))
  (let ((apply-limit
         (program-file
          "thinkpad-charge-limit"
          #~(begin
              (use-modules (ice-9 ftw))
              (define (write-if-needed file value)
                (when (file-exists? file)
                  (unless (= (call-with-input-file file read) value)
                    (call-with-output-file file
                      (lambda (port) (format port "~a\n" value))))
                  (unless (= (call-with-input-file file read) value)
                    (error "Battery firmware rejected threshold" file))))
              (for-each
               (lambda (name)
                 (let* ((base (string-append "/sys/class/power_supply/" name))
                        (start (string-append base "/charge_control_start_threshold"))
                        (end (string-append base "/charge_control_end_threshold")))
                   (when (file-exists? end)
                     (when (and (file-exists? start)
                                (>= (call-with-input-file start read) #$limit))
                       (write-if-needed start (- #$limit 1)))
                     (write-if-needed end #$limit))))
               (scandir "/sys/class/power_supply"
                        (lambda (name) (string-prefix? "BAT" name))))))))
    (list
     (simple-service 'thinkpad-modules kernel-module-loader-service-type
                     '("thinkpad_acpi" "kvm-intel"))
     (simple-service
      'thinkpad-charge-limit shepherd-root-service-type
      (list (shepherd-service
             (provision '(thinkpad-charge-limit))
             (requirement '(udev kernel-module-loader))
             (one-shot? #t)
             (start #~(lambda _ (zero? (system* #$apply-limit))))
             (documentation "Apply the ThinkPad charge ceiling."))))
     (udev-rules-service
      'thinkpad-charge-limit
      (file->udev-rule
       "90-thinkpad-charge.rules"
       (mixed-text-file "90-thinkpad-charge.rules"
                  "ACTION==\"add|change\", SUBSYSTEM==\"power_supply\", "
                  "RUN+=\"" apply-limit "\"\n"))))))
