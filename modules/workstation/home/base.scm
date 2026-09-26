(define-module (workstation home base)
  #:use-module (gnu home)
  #:use-module (gnu home services)
  #:use-module (gnu home services shells)
  #:use-module (gnu home services xdg)
  #:use-module (gnu home services desktop)
  #:use-module (gnu home services sound)
  #:use-module (gnu services)
  #:use-module (gnu packages)
  #:use-module (guix gexp)
  #:use-module (workstation files)
  #:use-module (workstation home editor)
  #:use-module (workstation packages oxwm)
  #:use-module (workstation packages codex)
  #:use-module (workstation packages desktop)
  #:export (make-workstation-home))

(define* (make-workstation-home #:key (display-config ""))
  (home-environment
   (packages
    (append
     (list oxwm-source codex-source clipwatch)
     editor-packages
     (specifications->packages
      '("librewolf" "picom" "st" "dmenu" "xfe" "git" "curl"
        "ripgrep" "fd" "gcc-toolchain" "make" "pkg-config"
        "font-dejavu" "font-gnu-freefont" "mpv" "feh" "xdg-utils"
        "xrandr" "xset" "xsetroot" "xinput" "setxkbmap" "xdotool"
        "xclip" "scrot" "i3lock" "xss-lock" "brightnessctl" "playerctl"
        "eudev" "elogind"))))
   (services
    (append editor-services (list
     (service home-bash-service-type
              (home-bash-configuration
               (bashrc (list (plain-file "bashrc" "alias ll='ls -alF'\n")))))
     (service home-dbus-service-type)
     (service home-pipewire-service-type)
     (simple-service 'workstation-environment home-environment-variables-service-type
                     '(("EDITOR" . "nvim") ("VISUAL" . "nvim")
                       ("BROWSER" . "librewolf")
                       ("PATH" . "$HOME/.local/bin${PATH:+:}$PATH")))
     (simple-service
      'workstation-files home-files-service-type
      (cons
       `(".xinitrc" ,(repository-file "home/przvl/xinitrc"))
       (map (lambda (name)
              (list (string-append ".local/bin/" name)
                    (repository-file (string-append "home/przvl/bin/" name))))
            '("st-bash" "workstation-lock" "control-menu" "alpinews-monitors"
              "alpinews-hotplug" "alpinews-brightness" "oxwm-cpu" "oxwm-battery"
              "screenshot-region" "clipboard-history"))))
     (simple-service
      'workstation-config home-xdg-configuration-files-service-type
      `(("oxwm/config.lua" ,(repository-file "home/przvl/config/oxwm/config.lua"))
        ("alpinews/display.conf" ,(plain-file "display.conf" display-config))
        ("picom/picom.conf" ,(repository-file "home/przvl/config/picom.conf"))
        ("mimeapps.list"
         ,(plain-file "mimeapps.list"
                      "[Default Applications]\nx-scheme-handler/http=librewolf.desktop\nx-scheme-handler/https=librewolf.desktop\ntext/html=librewolf.desktop\n")))))))))
