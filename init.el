;;; ===========================
;;; Emacs init — AUCTeX-centric, safe & reproducible
;;; - Duplicates removed
;;; - Comments corrected
;;; - All (require …) → use-package (auto-install on fresh machines)
;;; - Load order made explicit and robust
;;; ===========================

;;; --- Package bootstrap (ELPA/MELPA + use-package) ---------------------------
;; Ensure we can auto-install packages you use (company, yasnippet, adaptive-wrap, etc.)
;; This keeps current installs working and makes fresh installs hands-off.
(require 'package)
(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/")))
(unless package--initialized
  (package-initialize))

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(eval-when-compile
  (require 'use-package))
(setq use-package-always-ensure t)  ; auto-install missing packages

;;; --- TeX Live / PATH --------------------------------------------------------
;; Prefer TeX Live 2024 over system TeX; idempotent & safe if the directory exists.
(let ((texbin "/usr/local/texlive/2024/bin/x86_64-linux"))
  (when (file-directory-p texbin)
    (setenv "PATH" (concat texbin ":" (getenv "PATH")))
    (add-to-list 'exec-path texbin)))

;; User TEXMF tree (where personal .sty/.cls live)
(setenv "TEXMFHOME" (expand-file-name "~/Desktop/texmf"))

;;; --- Core UI / editing conveniences ----------------------------------------
(setq inhibit-startup-screen t)                ; no splash
(global-visual-line-mode 1)                    ; soft-wrap by default
(global-tab-line-mode 1)                       ; tabs per-window
(global-set-key (kbd "<f9>") #'keyboard-escape-quit)         ; quick cancel
(global-set-key (kbd "C-c n") #'display-line-numbers-mode)   ; toggle line numbers
(electric-pair-mode 1)                         ; auto-close braces, etc.

;;; --- Session persistence (desktop) ------------------------------------------
(desktop-save-mode 1)
(setq desktop-path (list (concat "~/.config/emacs/desktop/" (system-name))))
(setq desktop-dirname (concat "~/.config/emacs/desktop/" (system-name)))
(setq desktop-restore-eager 5)                 ; restore first N buffers quickly
(setq desktop-auto-save-timeout 30)            ; save session every 30s
(setq desktop-save t)


;;; --- Project list file (project.el) -----------------------------------------
(setq project-list-file "~/.emacs.d/projects")

;;; --- Emacs server (needed for SyncTeX inverse search) -----------------------
(use-package server
  :ensure nil
  :config
  (unless (server-running-p) (server-start)))

;;; --- Helper: LaTeX RET behavior in lists ------------------------------------
;; Insert \item on RET inside itemized environments; otherwise newline+indent.
(defun my-latex-insert-item-or-newline ()
  "Insert \\item if on a list line, otherwise newline and indent."
  (interactive)
  (if (save-excursion
        (beginning-of-line)
        (looking-back "\\\\item.*" (line-beginning-position)))
      (progn
        (newline)
        (LaTeX-insert-item))
    (newline-and-indent)))

;;; --- AUCTeX & LaTeX setup ---------------------------------------------------
;; Use the system AUCTeX (Fedora RPM layout) if present; otherwise install from ELPA.
(if (file-directory-p "/usr/share/emacs/site-lisp/auctex")
    ;; System AUCTeX
    (use-package tex
      :ensure nil
      :load-path "/usr/share/emacs/site-lisp/auctex"
      :defer t
      :init
      ;; Sensible AUCTeX defaults (applied before load)
      (setq TeX-auto-save t
            TeX-parse-self t
            TeX-PDF-mode t
            TeX-save-query nil
            TeX-source-correlate-mode t
            TeX-source-correlate-start-server t
            ;; Indentation tuned to your preference
            LaTeX-indent-level 4
            LaTeX-item-indent 0
            TeX-brace-indent-level 4
            ;; Make previews blend with dark themes
            preview-transparent-color t)
      :config
      ;; PDF viewer: Okular with SyncTeX
      (setq TeX-view-program-list
            '(("Okular" "okular --unique %o#src:%n%b")))
      (setq TeX-view-program-selection
            '((output-pdf "Okular")))
      ;; One-touch build & view (match your existing keys, corrected comment)
      (add-hook 'LaTeX-mode-hook
                (lambda ()
                  (local-set-key (kbd "C-<return>") #'TeX-command-run-all)
                  (local-set-key (kbd "<f5>")       #'TeX-command-run-all)
                  (local-set-key (kbd "<f6>")       #'TeX-view)
                  (local-set-key (kbd "RET")        #'my-latex-insert-item-or-newline)
                  (visual-line-mode 1))))
  ;; ELPA AUCTeX
  (use-package tex
    :ensure auctex
    :defer t
    :init
    (setq TeX-auto-save t
          TeX-parse-self t
          TeX-PDF-mode t
          TeX-save-query nil
          TeX-source-correlate-mode t
          TeX-source-correlate-start-server t
          LaTeX-indent-level 4
          LaTeX-item-indent 0
          TeX-brace-indent-level 4
          preview-transparent-color t)
    :config
    (setq TeX-view-program-list
          '(("Okular" "okular --unique %o#src:%n%b")))
    (setq TeX-view-program-selection
          '((output-pdf "Okular")))
    (add-hook 'LaTeX-mode-hook
              (lambda ()
                (local-set-key (kbd "C-<return>") #'TeX-command-run-all)
                (local-set-key (kbd "<f5>")       #'TeX-command-run-all)
                (local-set-key (kbd "<f6>")       #'TeX-view)
                (local-set-key (kbd "RET")        #'my-latex-insert-item-or-newline)
                (visual-line-mode 1)))))

;;; --- Wrapping that respects indentation in LaTeX ----------------------------
(use-package adaptive-wrap
  :defer t
  :hook (LaTeX-mode . adaptive-wrap-prefix-mode))

;;; --- Completion (company) ----------------------------------------------------
(use-package company
  :defer t
  :hook (LaTeX-mode . company-mode)
  :custom
  (company-idle-delay 0.2))

;;; --- Snippets (yasnippet) ---------------------------------------------------
(use-package yasnippet
  :defer 1
  :config
  (yas-global-mode 1))

;; Optional community snippet collection (present in your package list)
(use-package yasnippet-snippets
  :after yasnippet
  :defer t)

;;; ===========================
;;; Custom (theme & selected packages)
;;; Kept as written by Customize; leave as the single instance.
;;; ===========================
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-enabled-themes '(modus-vivendi))
 '(package-selected-packages
   '(adaptive-wrap company magit pdf-tools yasnippet yasnippet-snippets)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
