(define-module (workstation packages desktop)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages xdisorg)
  #:use-module (workstation files))

(define-public scrot-mirrored
  (package
    (inherit scrot)
    (source
     (origin
       (inherit (package-source scrot))
       (patches
        (append (origin-patches (package-source scrot))
                (list (repository-file
                       "sources/scrot/0001-composited-selection-borders.patch"))))))))

(define-public clipwatch
  (package
    (name "workstation-clipwatch")
    (version "1")
    (source (repository-file "sources/clipwatch.c"))
    (build-system gnu-build-system)
    (arguments
     (list #:tests? #f ; no upstream test suite
           #:phases
           #~(modify-phases %standard-phases
               (replace 'unpack
                 (lambda* (#:key source #:allow-other-keys)
                   (copy-file source "clipwatch.c")))
               (delete 'configure)
               (replace 'build
                 (lambda _
                   (invoke "gcc" "-O2" "clipwatch.c" "-o" "workstation-clipwatch"
                           "-lX11" "-lXfixes")))
               (replace 'install
                 (lambda _
                   (install-file "workstation-clipwatch" (string-append #$output "/bin")))))))
    (inputs (list libx11 libxfixes))
    (home-page "https://github.com/blakepiper/guix")
    (synopsis "Event-driven X11 clipboard history listener")
    (description "Event-driven clipboard listener compiled against GNU libc.")
    (license license:expat)))
