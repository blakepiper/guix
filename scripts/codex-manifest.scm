;; Use package objects: this channel hides Rust 1.95 from name lookup.
(use-modules (guix profiles)
             (gnu packages rust)
             (gnu packages python)
             (gnu packages version-control)
             (gnu packages nss))

(packages->manifest
 (list python rust-1.95 (list rust-1.95 "cargo") git nss-certs))
