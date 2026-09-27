(use-modules (gnu))

;; From Zen's installed /etc/config.scm, cross-checked against lsblk -f,
;; findmnt, swapon and blkid in the user's first-boot photo (2026-09-27).
;; These are Zen's disks, never defaults for another machine.
(define zen-file-systems
  (cons* (file-system
           (mount-point "/")
           (device (uuid "6af180c9-1413-43fe-a3ff-bc31a80220e9" 'ext4))
           (type "ext4"))
         (file-system
           (mount-point "/boot/efi")
           (device (uuid "F29A-1C24" 'fat32))
           (type "vfat"))
         %base-file-systems))

;; Preserve the installer's existing 3.7 GiB swap partition, /dev/nvme0n1p2.
;; No hibernation or resume policy is added.
(define zen-swap-devices
  (list (swap-space
          (target (uuid "b637087d-0c1a-493f-8ebb-f342576ee654")))))

;; The installer uses plain partitions, without encrypted/LVM mappings.
(define zen-mapped-devices '())

(define (require-zen-storage!)
  (unless (and (list? zen-file-systems)
               (list? zen-swap-devices)
               (list? zen-mapped-devices)
               (member "/" (map file-system-mount-point zen-file-systems))
               (member "/boot/efi" (map file-system-mount-point zen-file-systems)))
    (error "Zen storage is unconfigured: supply verified root, EFI, swap and mapped-device records from Zen's /etc/config.scm; see docs/zen.md")))
