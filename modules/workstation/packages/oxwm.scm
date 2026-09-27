(define-module (workstation packages oxwm)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages zig)
  #:use-module (gnu packages lua)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages fontutils)
  #:use-module (workstation files))

(define-public oxwm-source
  (package
    (name "oxwm-source")
    (version "0.13.0")
    (source (origin
              (method url-fetch)
              (uri "https://codeload.github.com/tonybanters/oxwm/tar.gz/refs/tags/v0.13.0")
              (file-name (string-append "oxwm-" version ".tar.gz"))
              (sha256 (base16-string->bytevector "6d0f6fbb438f21b79e6ffd77122085c18c528c4b4a90437b901d8cc3c62ab639"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:substitutable? #f
      #:phases
      #~(modify-phases %standard-phases
          (replace 'configure
            (lambda* (#:key inputs #:allow-other-keys)
              (setenv "HOME" (getcwd))
              (setenv "ZIG_GLOBAL_CACHE_DIR" (string-append (getcwd) "/.zig-cache-global"))
              ;; Upstream builds Lua as C source. Supply it without Zig fetching
              ;; anything from the network inside the build sandbox.
              (mkdir "lua-source")
              (invoke "tar" "xf" (assoc-ref inputs "lua-source")
                      "-C" "lua-source" "--strip-components=1")
              (substitute* "build.zig.zon"
                (("\\.url = .*lua-.*") ".path = \"lua-source\",\n")
                (("[[:space:]]*\\.hash = .*\n") "\n"))
              (invoke "patch" "-p1" "-i"
                      #$(repository-file "sources/oxwm/0001-microphone-keysym.patch"))
              (invoke "patch" "-p1" "-i"
                      #$(repository-file "sources/oxwm/0002-unique-mirrored-screens.patch"))
              (invoke "patch" "-p1" "-i"
                      #$(repository-file "sources/oxwm/0003-equal-split.patch"))))
          (replace 'build
            (lambda _
              (invoke "zig" "build" "-j2" "-Doptimize=ReleaseSmall"
                      "-Dcpu=baseline" "--prefix" #$output)))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests? (invoke "zig" "build" "test" "-j2"))))
          (replace 'install
            (lambda _
              (install-file "LICENSE" (string-append #$output "/share/licenses/oxwm")))))))
    (native-inputs (list zig-0.16 pkg-config))
    (inputs `(("libx11" ,libx11) ("libxinerama" ,libxinerama)
              ("libxft" ,libxft) ("fontconfig" ,fontconfig)
              ("lua-source" ,(package-source lua-5.4))))
    (home-page "https://github.com/tonybanters/oxwm")
    (synopsis "Source-built OXWM with the AlpineWS desktop fixes")
    (description "Dynamic X11 window manager configured in Lua, built from the
pinned upstream release with microphone-key and mirrored-monitor fixes from Blix.")
    (license license:expat)))
