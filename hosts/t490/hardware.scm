(use-modules (gnu))

;; Historical UUIDs in Blix describe an older NixOS install. Never assume they
;; survived Alpine's installer. Use these labels on the intended Guix volumes,
;; or replace these fields with UUIDs verified on the T490 before installing.
(define t490-file-systems
  (cons* (file-system
           (mount-point "/")
           (device (file-system-label "guix-root"))
           (type "ext4"))
         (file-system
           (mount-point "/boot/efi")
           (device (file-system-label "GUIX_EFI"))
           (type "vfat"))
         %base-file-systems))

;; Opt in only after identifying a real swap partition; no hibernation default.
(define t490-swap-devices '())
