(include "hardware.scm")
(require-zen-storage!)

(include "config.scm")
(make-zen-operating-system zen-file-systems zen-swap-devices zen-mapped-devices)
