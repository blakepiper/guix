(use-modules (gnu)
             (gnu packages xorg)
             ((nongnu packages linux) #:prefix nongnu:)
             (workstation packages firmware)
             (workstation system base)
             (workstation system desktop))

;; Keep composition evaluable without inventing an installable storage layout.
;; system.scm is the guarded entrypoint for builds/reconfiguration.
(define (make-zen-operating-system file-systems swap-devices mapped-devices)
  (operating-system
    (inherit base-operating-system)
    (host-name "zen")
    (kernel nongnu:linux)
    (firmware (append (list nongnu:iwlwifi-firmware
                            intel-graphics-firmware
                            nongnu:sof-firmware)
                      %base-firmware))
    (kernel-loadable-modules '())
    (file-systems file-systems)
    (swap-devices swap-devices)
    (mapped-devices mapped-devices)
    ;; Modesetting is built into Xorg. No legacy Intel DDX or device IDs.
    (services (desktop-services #:xorg-modules (list xf86-input-libinput)
                                #:xorg-drivers '("modesetting")))))
