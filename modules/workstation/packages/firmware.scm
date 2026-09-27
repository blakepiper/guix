(define-module (workstation packages firmware)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (nongnu packages linux))

;; The pinned Nonguix i915-firmware recipe omits xe/.  Retain its source,
;; checksum, license and installer, selecting both Intel graphics directories.
;; This package is opt-in; it does not change the shared firmware defaults.
(define-public intel-graphics-firmware
  (package
    (inherit i915-firmware)
    (name "intel-graphics-firmware")
    (arguments
     (substitute-keyword-arguments (package-arguments i915-firmware)
       ((#:phases phases)
        #~(modify-phases #$phases
            (replace 'select-firmware
              (lambda _
                (use-modules (ice-9 regex))
                (define (intel? file)
                  (string-match "^(i915|xe)/" file))
                (substitute* "WHENCE"
                  (("^(File|RawFile): *([^ ]*)(.*)" _ type file rest)
                   (string-append (if (intel? file) type "Skip")
                                  ": " file rest))
                  (("^Link: *(.*) *-> *(.*)" _ file target)
                   (string-append (if (intel? target) "Link" "Skip")
                                  ": " file " -> " target)))))
            (add-after 'install 'check-intel-firmware
              (lambda* (#:key outputs #:allow-other-keys)
                (use-modules (ice-9 ftw))
                ;; Firmware licenses moved into LICENSES/ in this source;
                ;; the inherited install-license-files phase scans only '.'.
                (for-each
                 (lambda (name)
                   (install-file (string-append "LICENSES/" name)
                                 (string-append (assoc-ref outputs "out")
                                                "/share/doc/intel-graphics-firmware")))
                 '("LICENSE.i915" "LICENSE.xe"))
                (let ((firmware (string-append (assoc-ref outputs "out")
                                               "/lib/firmware/")))
                  (unless (equal? (scandir firmware
                                          (lambda (name)
                                            (not (member name '("." "..")))))
                                  '("i915" "xe"))
                    (error "Unexpected non-Intel graphics firmware installed"))
                  (for-each
                   (lambda (file)
                     (unless (file-exists? (string-append firmware file))
                       (error "Missing Lunar Lake firmware" file)))
                   '("xe/lnl_guc_70.bin.zst" "xe/lnl_huc.bin.zst"
                     "xe/lnl_gsc_1.bin.zst" "i915/xe2lpd_dmc.bin.zst")))))))))
    (synopsis "Intel i915 and Xe graphics firmware")
    (description "Intel graphics firmware, including Lunar Lake GuC, HuC and
DMC files.  Only the i915 and xe firmware directories are installed; AMD and
NVIDIA firmware are excluded.")))
