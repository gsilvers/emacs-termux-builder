;;; site-start.el --- Site setup for emacs-termux-builder  -*- lexical-binding: t; no-byte-compile: t -*-

;;; Commentary:

;; build-emacs.sh installs this file into the APK's Lisp directory,
;; with @GHOSTEL_VERSION@ replaced by the version of the Ghostel
;; (https://github.com/dakra/ghostel) that comes with this build.
;;
;; Ghostel's Lisp, and the files its shells read (the xterm-ghostty
;; terminfo entry and the shell integration scripts), are packed in
;; etc/ghostel.tar.  Nothing but Emacs can read files inside the APK,
;; so the first start of each Ghostel and Emacs version unpacks them
;; to ~/.emacs.d/ghostel-bundled/GHOSTEL-EMACS/ and loads them from
;; there.  (The .elc files were compiled by this Emacs version.)
;;
;; Ghostel's native module is lib/arm64-v8a/libghostel-module.so in
;; the APK, which Android installs into `exec-directory'.
;;
;; A Ghostel installed with package.el comes earlier in `load-path',
;; replaces this one and manages its own module.

;;; Code:

(defconst site-ghostel-version "@GHOSTEL_VERSION@"
  "Version of the Ghostel that comes with this Emacs.")

(defvar site-ghostel-directory nil
  "Directory the bundled Ghostel was unpacked into, or nil.")

(with-demoted-errors "Setting up the bundled Ghostel: %S"
  (let* ((tarball (expand-file-name "ghostel.tar" data-directory))
         (parent (expand-file-name
                  (locate-user-emacs-file "ghostel-bundled/")))
         (dir (expand-file-name
               (concat site-ghostel-version "-" emacs-version) parent)))
    (when (file-exists-p tarball)
      (unless (file-directory-p dir)
        (require 'tar-mode)
        (make-directory parent t)
        ;; Unpack next to DIR and rename, so an interrupted unpack
        ;; isn't taken for a finished one.
        (let ((tmp (make-temp-file (expand-file-name "tmp-" parent) t)))
          (let ((default-directory (file-name-as-directory tmp)))
            (with-temp-buffer
              (set-buffer-multibyte nil)
              (insert-file-contents-literally tarball)
              (tar-mode)
              (tar-untar-buffer)))
          (rename-file tmp dir))
        ;; Remove older versions and leftovers of interrupted unpacks.
        (dolist (old (directory-files parent t "\\`[^.]"))
          (unless (string= old dir)
            (delete-directory old t))))
      (add-to-list 'load-path dir)
      (load (expand-file-name "ghostel-autoloads" dir) nil t)
      (setq site-ghostel-directory dir))))

;; Load the bundled Ghostel's module from the APK.  This has to happen
;; after `ghostel-module-install' is loaded and before ghostel.el looks
;; for a module in its own directory (and, finding none, offers to
;; download one).
(with-eval-after-load 'ghostel-module-install
  (with-demoted-errors "Loading the bundled Ghostel module: %S"
    (let ((module (expand-file-name "libghostel-module.so" exec-directory))
          (lisp (locate-library "ghostel")))
      (when (and site-ghostel-directory
                 lisp
                 (file-in-directory-p lisp site-ghostel-directory)
                 (not ghostel-module-directory)
                 (not (featurep 'ghostel-module))
                 (file-exists-p module))
        (module-load module)))))

;; Android 10 and later don't let apps run programs that are stored in
;; app data directories, Termux's included.  Emacs gets around that
;; with an exec loader (`android-use-exec-loader'), but Ghostel's
;; native PTY code calls execve itself and skips the loader.  So by
;; default Ghostel starts shells through Emacs's process code here.
;; Set this to t in your init file to try the native PTY anyway.
(defvar ghostel-use-native-pty nil)

;;; site-start.el ends here
