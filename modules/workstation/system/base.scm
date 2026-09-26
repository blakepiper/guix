(define-module (workstation system base)
  #:use-module (gnu)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages bash)
  #:export (base-operating-system))

(define base-operating-system
  (operating-system
    (host-name "unconfigured")
    (timezone "America/New_York")
    (locale "en_US.utf8")
    (keyboard-layout (keyboard-layout "us"))
    (kernel linux-libre)
    ;; %base-firmware consists of free firmware; no Nonguix channel is used.
    (firmware %base-firmware)
    (bootloader (bootloader-configuration
                 (bootloader grub-efi-bootloader)
                 (targets '("/boot/efi"))))
    (file-systems %base-file-systems)
    (users (cons (user-account
                  (name "przvl")
                  (comment "Blake")
                  (group "users")
                  (home-directory "/home/przvl")
                  (shell (file-append bash "/bin/bash"))
                  (supplementary-groups '("wheel" "netdev" "audio" "video")))
                 %base-user-accounts))
    (packages (append (specifications->packages
                       '("git" "curl" "nss-certs" "glibc-locales"))
                      %base-packages))))
