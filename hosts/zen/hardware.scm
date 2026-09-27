(use-modules (gnu))

;; UNCONFIGURED: copy the complete storage records from Zen's /etc/config.scm
;; after comparing lsblk -f, findmnt and swapon --show.  See docs/zen.md.
;; #f is deliberate: never substitute example UUIDs, T490 disks or guessed labels.
;; Include %base-file-systems in the verified file-system list. Preserve any
;; mapped devices/encryption dependencies. An empty swap list is valid ONLY
;; if the installed configuration really has no swap; do not infer it from RAM.
(define zen-file-systems #f)
(define zen-swap-devices #f)
(define zen-mapped-devices #f)

(define (require-zen-storage!)
  (unless (and (list? zen-file-systems)
               (list? zen-swap-devices)
               (list? zen-mapped-devices)
               (member "/" (map file-system-mount-point zen-file-systems))
               (member "/boot/efi" (map file-system-mount-point zen-file-systems)))
    (error "Zen storage is unconfigured: supply verified root, EFI, swap and mapped-device records from Zen's /etc/config.scm; see docs/zen.md")))
