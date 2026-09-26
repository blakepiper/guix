;; Guix's isolated channel loader provides the channel bindings directly.
(list (channel
       (inherit (car %default-channels))
       (url "https://codeberg.org/guix/guix.git")
       (commit "fb556d47e9dfbd246d748f3fc6d7cf9edba6c656")))
