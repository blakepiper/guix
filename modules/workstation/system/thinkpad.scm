(define-module (workstation system thinkpad)
  #:use-module (gnu)
  #:use-module (gnu services linux)
  #:use-module (workstation system battery)
  #:export (thinkpad-services))

(define (thinkpad-services limit)
  (cons (simple-service 'thinkpad-modules kernel-module-loader-service-type
                        '("thinkpad_acpi" "kvm-intel"))
        (battery-charge-services limit 'thinkpad-charge-limit
                                 '(udev kernel-module-loader))))
