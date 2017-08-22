;;; tuareg-opam.el --- Mode for editing opam files   -*- coding: utf-8 -*-

;; Copyright (C) 2017- Christophe Troestler

(defvar tuareg-opam-mode-hook nil)

(defvar tuareg-opam-indent-basic 2
  "The default amount of indentation.")


(defvar tuareg-opam-mode-map
  (let ((map (make-keymap)))
    (define-key map "\C-j" 'newline-and-indent)
    map)
  "Keymap for tuareg-opam mode")

(defvar tuareg-opam-skeleton
  "opam-version: \"1.2\"
maintainer: \"\"
authors: []
tags: []
build: [
  [ \"jbuilder\" \"subst\" ] {pinned}
  [ \"jbuilder\" \"build\" \"-p\" name \"-j\" jobs ]
]\n"
  "If not nil, propose to fill new files with this skeleton")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                       Syntax highlighting

(defconst tuareg-opam-keywords
  '("opam-version" "name" "version" "maintainer" "authors"
    "license" "homepage" "doc" "bug-reports" "dev-repo"
    "tags" "patches" "substs" "build" "install" "build-test"
    "build-doc" "remove" "depends" "depopts" "conflicts"
    "depexts" "messages" "post-messages" "available"
    "flags")
  "Kewords in OPAM files.")

(defconst tuareg-opam-keywords-regex
  (regexp-opt tuareg-opam-keywords 'symbols))

(defconst tuareg-opam-variables-regex
  (regexp-opt '("user" "group" "make" "os" "root" "prefix" "lib"
                "bin" "sbin" "doc" "stublibs" "toplevel" "man"
                "share" "etc"
                "name" "pinned"
                "ocaml-version" "opam-version" "compiler" "preinstalled"
                "switch" "jobs" "ocaml-native" "ocaml-native-tools"
                "ocaml-native-dynlink" "arch") 'symbols)
  "Variables declared in OPAM.")

(defconst tuareg-opam-pkg-variables-regex
  (regexp-opt '("name" "version" "depends" "installed" "enable" "pinned"
                "bin" "sbin" "lib" "man" "doc" "share" "etc" "build"
                "hash") 'symbols)
  "Package variables in OPAM.")

(defvar tuareg-opam-font-lock-keywords
  `((,(concat tuareg-opam-keywords-regex ":")
     1 font-lock-keyword-face)
    (,(regexp-opt '("build" "test" "doc" "pinned" "true" "false") 'words)
     . font-lock-constant-face)
    (,tuareg-opam-variables-regex . font-lock-variable-name-face)
    (,(concat "%{" tuareg-opam-variables-regex "}%")
     (1 font-lock-variable-name-face t))
    (,(concat "%{\\([a-zA-Z_][a-zA-Z0-9_+-]*\\):"
              tuareg-opam-pkg-variables-regex "}%")
     (1 font-lock-constant-face t)
     (2 font-lock-variable-name-face t)))
  "Highlighting for OPAM files")


(defvar tuareg-opam-prettify-symbols
  `(("&" . ,(decode-char 'ucs 8743)); 'LOGICAL AND' (U+2227)
    ("|" . ,(decode-char 'ucs 8744)); 'LOGICAL OR' (U+2228)
    ("<=" . ,(decode-char 'ucs 8804))
    (">=" . ,(decode-char 'ucs 8805))
    ("!=" . ,(decode-char 'ucs 8800)))
  "Alist of symbol prettifications for OPAM files.
See `prettify-symbols-alist' for more information.")

(defvar tuareg-opam-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?# "< b" table)
    (modify-syntax-entry ?\n "> b" table)
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    table)
  "Tuareg-opam syntax table.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                               SMIE

(require 'smie)

(setq tuareg-opam-smie-grammar
  (when (fboundp 'smie-prec2->grammar)
    (let* ((decl-of-kw (lambda(kw) `(decls ,kw ":" list)))
           (bnfprec2
            (smie-bnf->prec2
             `((decls . ,(mapcar decl-of-kw tuareg-opam-keywords) )
               (list ("[" list "]")
                     (value))
               (value (string "{" filter "}")
                      (string))
               (string)
               (filter)))))
      (smie-prec2->grammar
       (smie-merge-prec2s
        bnfprec2
        (smie-precs->prec2
         '((right "&" "|")
           (left "=" "!=" ">" ">=" "<" "<=")))
        )))))

(defun tuareg-opam-smie-rules (kind token)
  (cond
   ((and (eq kind :before) (member token tuareg-opam-keywords))
    0)
   ((and (eq kind :before) (equal token "[") (smie-rule-hanging-p))
    0)
   ((and (eq kind :before) (equal token "{"))
    0)
   (t tuareg-opam-indent-basic)))


(defvar tuareg-opam-smie-verbose-p t
  "Emit context information about the current syntax state.")

(defmacro tuareg-opam-smie-debug (message &rest format-args)
  `(progn
     (when tuareg-opam-smie-verbose-p
       (message (format ,message ,@format-args)))
     nil))

(defun verbose-tuareg-opam-smie-rules (kind token)
  (let ((value (tuareg-opam-smie-rules kind token)))
    (tuareg-opam-smie-debug
     "%s '%s'; sibling-p:%s parent:%s prev-is-[:%s hanging:%s = %s"
     kind token
     (ignore-errors (smie-rule-sibling-p))
     (ignore-errors smie--parent)
     (ignore-errors (smie-rule-prev-p "["))
     (ignore-errors (smie-rule-hanging-p))
     value)
    value))


;;;###autoload
(define-derived-mode tuareg-opam-mode prog-mode "Tuareg-opam"
  "Major mode to edit opam files."
  (setq font-lock-defaults '(tuareg-opam-font-lock-keywords))
  (set (make-local-variable 'comment-start) "#")
  (set (make-local-variable 'comment-end) "")
  (set (make-local-variable 'prettify-symbols-alist)
       tuareg-opam-prettify-symbols)
  (setq indent-tabs-mode nil)
  (set (make-local-variable 'require-final-newline) t)
  (smie-setup tuareg-opam-smie-grammar #'tuareg-opam-smie-rules)
  (let ((fname (buffer-file-name)))
    (when (and tuareg-opam-skeleton
               (not (and fname (file-exists-p fname)))
               (y-or-n-p "New file; fill with skeleton?"))
      (save-excursion (insert tuareg-opam-skeleton))))
  (run-mode-hooks 'tuareg-opam-mode-hook))


;;;###autoload
(add-to-list 'auto-mode-alist '("[./]opam\\'" . tuareg-opam-mode))


(provide 'tuareg-opam-mode)