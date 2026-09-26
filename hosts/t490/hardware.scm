(use-modules (gnu))

;; UUIDs from the current fresh Guix installation on the T490.
(define t490-file-systems
  (cons* (file-system
           (mount-point "/")
           (device (uuid "3cc4380e-2159-469a-9907-ce74d61e5e46" 'ext4))
           (type "ext4"))
         (file-system
           (mount-point "/boot/efi")
           (device (uuid "32D6-D463" 'fat32))
           (type "vfat"))
         %base-file-systems))

;; Existing swap partition on /dev/nvme0n1p2.
(define t490-swap-devices
  (list (swap-space
          (target (uuid "d6e7581e-4a75-4053-9654-da7ab483d88f")))))
