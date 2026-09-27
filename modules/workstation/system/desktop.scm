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
    (simple-service
     'nonguix-substitutes guix-service-type
     (guix-extension
      (substitute-urls '("https://substitutes.nonguix.org"))
      (authorized-keys (list (repository-file "sources/nonguix-signing-key.pub")))))
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
    ;; Our console desktop uses %base-services, not %desktop-services, so it
    ;; must explicitly create X's shared socket directory before a user Xorg.
    (service x11-socket-directory-service-type)
    ;; The standard service creates/chmods but does not repair ownership of
    ;; a directory previously created by rootless Xorg. Activation handles
    ;; existing installations immediately, without deleting live sockets.
    (simple-service
     'workstation-x11-socket-permissions activation-service-type
     #~(begin
         (use-modules (guix build utils))
         (let ((directory "/tmp/.X11-unix"))
           (mkdir-p directory)
           (unless (eq? 'directory (stat:type (lstat directory)))
             (error "X11 socket path must be a real directory" directory))
           (chown directory 0 0)
           (chmod directory #o1777))))
    (service screen-locker-service-type
             (screen-locker-configuration
              (name "i3lock")
              (program (file-append i3lock "/bin/i3lock"))))
    (udev-rules-service 'brightness brightnessctl))
   %base-services))
