(define-module (workstation home editor)
  #:use-module (gnu services)
  #:use-module (gnu packages)
  #:use-module (gnu home services)
  #:use-module (gnu home services xdg)
  #:use-module (workstation files)
  #:use-module (workstation packages editor)
  #:export (editor-packages editor-services))

(define editor-packages
  (cons tree-sitter-cli-for-blix
        (specifications->packages
         '("neovim" "tree-sitter-bash" "lua-language-server" "node"
           "unzip" "fzf" "shfmt" "font-nerd-symbols"))))

;; Guix Neovim discovers grammars through TREE_SITTER_GRAMMAR_PATH, so Bash
;; needs a profile grammar even when nvim-treesitter has downloaded its parser.
;; Git, curl, GCC, make, ripgrep, fd and xclip come from the shared Home profile.
;; Parser/plugin builds go into Neovim's writable data directory, and Blix's
;; lazy.lua seeds a writable state lockfile from the checked-in lockfile.
(define editor-services
  (list
   (simple-service
    'editor-config home-xdg-configuration-files-service-type
    `(("nvim" ,(repository-file "home/przvl/config/nvim" #:recursive? #t))))
   (simple-service
    'editor-launcher home-files-service-type
    ;; Flat local-file imports strip the executable bit in the Guix store.
    `((".local/bin/nvimide" ,(repository-file "home/przvl/bin/nvimide"
                                             #:recursive? #t))))))
