(use-modules (workstation home base))

;; Discover the connected eDP panel. External 2560x1440 @ up to 144 Hz is
;; deferred until real connector names/modes are collected with xrandr.
(make-workstation-home
 #:display-config "ALPINEWS_DISPLAY_POLICY=native
ALPINEWS_INTERNAL_OUTPUT=auto
ALPINEWS_INTERNAL_MODE=2880x1800
ALPINEWS_INTERNAL_RATE=120
")
