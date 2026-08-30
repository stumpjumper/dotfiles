;;; -*- lexical-binding: t -*-

;;; Package management
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)
(require 'use-package)  ; built-in since Emacs 29

;;; Completion UI
(if (string-match-p "^s[0-9]+" (system-name))
    ;; Work Mac: fido-vertical-mode is built-in, no MELPA needed
    (use-package icomplete
      :config (fido-vertical-mode 1))
  ;; Home Mac / Raspberry Pi: full vertico stack
  (use-package vertico
    :ensure t
    :config (vertico-mode 1))
  (use-package marginalia
    :ensure t
    :after vertico
    :config (marginalia-mode 1))
  (use-package which-key
    :ensure t
    :config (which-key-mode 1)))

;;; Permissions
(put 'downcase-region  'disabled nil)
(put 'upcase-region    'disabled nil)
(put 'narrow-to-region 'disabled nil)
(put 'eval-expression  'disabled nil)

;;; Flow control
;; These lines remap C-\ -> C-s and C-^ -> C-q.
;; They were a workaround for dumb terminals that used XON/XOFF flow control,
;; which intercepted C-s and C-q before Emacs could see them.
;; Uncomment to restore if your muscle memory needs them back.
;; (keyboard-translate ?\C-\\ ?\C-s)
;; (keyboard-translate ?\C-^ ?\C-q)

;;; Search
(global-set-key (kbd "M-q")   'query-replace-regexp)
(global-set-key (kbd "C-s")   'isearch-forward-regexp)
(global-set-key (kbd "C-r")   'isearch-backward-regexp)
(global-set-key (kbd "C-M-s") 'isearch-forward)
(global-set-key (kbd "C-M-r") 'isearch-backward)

;;; Keybindings
(global-set-key (kbd "C-m") 'newline-and-indent)
(global-set-key (kbd "C-j") 'newline)
(define-key global-map (kbd "C-t")
  (lambda () (interactive)
    (transpose-subr 'forward-char -1)
    (forward-char 1)))
(global-set-key (kbd "M-g")     'goto-line)
(global-set-key (kbd "C-x C-r") 'write-region)
(global-set-key (kbd "M-%")     'fill-paragraph)
(keyboard-translate ?\C-h ?\C-?)  ; C-h -> DEL
(global-set-key (kbd "C-M-y")   'insert-buffer)
(global-set-key (kbd "S-<f1>")  'call-last-kbd-macro)
(global-set-key (kbd "C-x x")   'copy-to-register)
(global-set-key (kbd "C-x g")   'insert-register)
(global-set-key (kbd "<f12>")   'undo)
(global-set-key (kbd "C-x p")   'find-file-pair)
(global-set-key (kbd "C-x c")   'compile)

;;; Align equals -- built-in align-regexp, no external file needed
(defun align-equals (start end)
  "Align assignment operators in region."
  (interactive "r")
  (align-regexp start end "\\(\\s-*\\)[+*/-]?=" 1 1))
(global-set-key (kbd "C-c =") 'align-equals)

;;; Variables
(setq-default indent-tabs-mode nil)
(setq-default tab-width 8)
(setq inhibit-startup-message t)
(setq default-case-fold-search t)
(line-number-mode   t)
(column-number-mode t)
(transient-mark-mode 1)
(show-paren-mode     1)

;;; Compilation
(setq compile-command
      "cd ..; make test; if [ $? == '0' ]; then echo ':-) :-) :-) Success :-) :-) :-) '; else echo '!!!! Failure !!!!'; fi")

;;; Grep
(setq grep-command "grep -n ")

;;; Functions

(defun rb ()
  "Revert buffer without asking."
  (interactive)
  (revert-buffer t t))

(defun my-exit-from-emacs (arg)
  "Confirm before exiting Emacs.
With C-u prefix, force exit even when multiple frames are open;
otherwise offer to delete only the current frame."
  (interactive "p")
  (if (or (= (length (frame-list)) 1) (= arg 4))
      (when (yes-or-no-p "Do you want to exit? ")
        (save-buffers-kill-emacs))
    (when (yes-or-no-p "Do you want to delete this frame (C-u C-x C-c to exit)? ")
      (delete-frame))))

(global-set-key (kbd "C-x C-c") 'my-exit-from-emacs)

(defun find-file-pair ()
  "Toggle between a .cpp file and its .h counterpart."
  (interactive)
  (let ((file-name (buffer-file-name)))
    (cond ((string-match "\\(.*\\)\\.cpp$" file-name)
           (find-file (concat (match-string 1 file-name) ".h")))
          ((string-match "\\(.*\\)\\.h$" file-name)
           (find-file (concat (match-string 1 file-name) ".cpp"))))))

(defun bot ()
  "Switch to the other window and move to end of buffer."
  (interactive)
  (other-window 1)
  (goto-char (point-max)))
