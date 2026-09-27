(use-modules (gnu)
             ((nongnu packages linux) #:prefix nongnu:)
             (workstation system base)
             (workstation system desktop)
             (workstation system thinkpad))

(include "hardware.scm")

(operating-system
  (inherit base-operating-system)
  (host-name "t490")
  ;; Explicit host exception for the built-in Intel wireless adapter.
  (kernel nongnu:linux)
  (firmware (cons nongnu:iwlwifi-firmware %base-firmware))
  (kernel-loadable-modules '())
  (file-systems t490-file-systems)
  (swap-devices t490-swap-devices)
  (services
   (append (thinkpad-services 79)
           (desktop-services
            #:xorg-extra
            (list "Section \"InputClass\"
  Identifier \"T490 touchpad\"
  MatchIsTouchpad \"on\"
  MatchDriver \"libinput\"
  Option \"Tapping\" \"true\"
  Option \"NaturalScrolling\" \"true\"
  Option \"ClickMethod\" \"clickfinger\"
  Option \"DisableWhileTyping\" \"true\"
EndSection
Section \"InputClass\"
  Identifier \"T490 Logitech G502 HERO natural scrolling\"
  MatchIsPointer \"on\"
  MatchProduct \"Logitech G502 HERO Gaming Mouse\"
  MatchUSBID \"046d:c08b\"
  MatchDriver \"libinput\"
  Option \"NaturalScrolling\" \"true\"
EndSection
Section \"InputClass\"
  Identifier \"T490 built-in keyboard\"
  MatchIsKeyboard \"on\"
  MatchProduct \"AT Translated Set 2 keyboard\"
  Option \"XkbLayout\" \"us\"
  # Explicitly clear inherited options from the external keyboard.
  Option \"XkbOptions\" \"\"
EndSection
Section \"InputClass\"
  Identifier \"External Gaming Keyboard\"
  MatchIsKeyboard \"on\"
  MatchProduct \"Gaming Keyboard\"
  MatchUSBID \"1fc9:e8c7\"
  Option \"XkbOptions\" \"altwin:swap_alt_win\"
EndSection
Section \"ServerFlags\"
  Option \"DontVTSwitch\" \"true\"
  Option \"DontZap\" \"true\"
EndSection\n")))))
