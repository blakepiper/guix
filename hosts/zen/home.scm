(use-modules (workstation home base))

;; Discover dock connector names; MST suffixes can change on reconnect.
(make-workstation-home
 #:keyboard-config "ALPINEWS_SWAP_KEYBOARD_USB_ID='8137, 59591'
"
 #:display-config "ALPINEWS_DISPLAY_POLICY=mirror
ALPINEWS_INTERNAL_OUTPUT=auto
ALPINEWS_EXTERNAL_OUTPUT=auto
ALPINEWS_MIRROR_MODE=2560x1440
ALPINEWS_MIRROR_RATE=60
ALPINEWS_EXTERNAL_RATE=144
ALPINEWS_INTERNAL_MODE=2880x1800
ALPINEWS_INTERNAL_RATE=120
")
