;; Guix's isolated channel loader provides the channel bindings directly.
(list (channel
       (inherit (car %default-channels))
       (url "https://codeberg.org/guix/guix.git")
       (commit "fb556d47e9dfbd246d748f3fc6d7cf9edba6c656"))
      ;; Available to all hosts; hosts explicitly opt into its kernel/firmware.
      (channel
       (name 'nonguix)
       (url "https://gitlab.com/nonguix/nonguix")
       (commit "2a16e08d40b913e593c7c9ea29bc82b96f117e24")
       (introduction
        (make-channel-introduction
         "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
         (openpgp-fingerprint
          "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5")))))
