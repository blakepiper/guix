(define-module (workstation packages firmware)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((nonguix licenses) #:prefix nonguix:)
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

;; Exact WHENCE subset for Zen's CS42L43 and subsystem 1043:1e13 amps.
;; Keep the pinned source, checksum and upstream compressed installer.
(define-public zen-audio-firmware
  (package
    (inherit linux-firmware)
    (name "zen-audio-firmware")
    (arguments
     (substitute-keyword-arguments (package-arguments linux-firmware)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'select-zen-audio
              (lambda _
                (define files
                  '("cs42l43.bin"
                    "cirrus/cs35l56/CS35L56_Rev3.11.16.wmfw"
                    "cirrus/cs35l56-b0-dsp1-misc-10431e13-amp1.bin"
                    "cirrus/cs35l56-b0-dsp1-misc-10431e13-amp2.bin"
                    "cirrus/cs35l56-b0-dsp1-misc-10431e13-amp3.bin"
                    "cirrus/cs35l56-b0-dsp1-misc-10431e13-amp4.bin"))
                (substitute* "WHENCE"
                  (("^(File|RawFile): *([^ ]*)(.*)" _ type file rest)
                   (string-append (if (member (string-trim-right file) files)
                                      type "Skip")
                                  ": " file rest))
                  (("^Link: *(.*) *-> *(.*)" _ file target)
                   (string-append
                    (if (string=? (string-trim-right file)
                                  "cirrus/cs35l56-b0-dsp1-misc-10431e13.wmfw")
                        "Link" "Skip")
                    ": " file " -> " target)))))
            (add-after 'install 'check-zen-audio
              (lambda* (#:key outputs #:allow-other-keys)
                (let* ((out (assoc-ref outputs "out"))
                       (firmware (string-append out "/lib/firmware/")))
                  (install-file "LICENSES/LICENSE.cirrus"
                                (string-append out "/share/doc/zen-audio-firmware"))
                  (for-each
                   (lambda (file)
                     (unless (file-exists? (string-append firmware file))
                       (error "Missing Zen audio firmware" file)))
                   '("cs42l43.bin.zst"
                     "cirrus/cs35l56/CS35L56_Rev3.11.16.wmfw.zst"
                     "cirrus/cs35l56-b0-dsp1-misc-10431e13.wmfw.zst"
                     "cirrus/cs35l56-b0-dsp1-misc-10431e13-amp1.bin.zst"
                     "cirrus/cs35l56-b0-dsp1-misc-10431e13-amp2.bin.zst"
                     "cirrus/cs35l56-b0-dsp1-misc-10431e13-amp3.bin.zst"
                     "cirrus/cs35l56-b0-dsp1-misc-10431e13-amp4.bin.zst")))))))))
    (synopsis "Cirrus audio firmware for ASUS Zenbook S 14 UX5406SA")
    (description "Firmware for Zen's CS42L43 codec and four CS35L56 amplifiers.
Only the amplifier tuning for PCI subsystem 1043:1e13 and its matching DSP
image are included, with the upstream firmware symlink preserved.")
    (license (nonguix:nonfree
              "https://gitlab.com/kernel-firmware/linux-firmware/-/blob/20260916/LICENSES/LICENSE.cirrus"))))
