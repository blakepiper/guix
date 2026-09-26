(define-module (workstation system desktop)
  #:use-module (gnu)
  #:use-module (gnu services desktop)
  #:use-module (gnu services networking)
  #:use-module (gnu services dbus)
  #:use-module (gnu services xorg)
  #:use-module (gnu services pm)
  #:use-module (gnu packages window-management)
  #:use-module (gnu packages linux)
  #:use-module (workstation files)
  #:export (desktop-services))

(define* (desktop-services #:key (xorg-extra '()))
  (append
   (list
    (service dbus-root-service-type)
    (service polkit-service-type)
    (service elogind-service-type
             (elogind-configuration
              (handle-lid-switch 'suspend)
              (handle-lid-switch-docked 'ignore)))
    (service network-manager-service-type)
    (service wpa-supplicant-service-type)
    (service ntp-service-type)
    (service startx-command-service-type
             (xorg-configuration
              (keyboard-layout (keyboard-layout "us"))
              (extra-config xorg-extra)))
    (service screen-locker-service-type
             (screen-locker-configuration
              (name "i3lock")
              (program (file-append i3lock "/bin/i3lock"))))
    (udev-rules-service 'brightness brightnessctl))
   %base-services))
