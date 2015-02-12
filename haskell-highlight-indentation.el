;;; haskell-highlight-indentation.el --- haskell highlight indentation -*- lexical-binding: t -*-

;; Copyright (C) 2014  nilninull

;; Author: nilninull <nilninull@gmail.com>
;; Keywords:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package was inspired by Emacs highlight-indentation package,
;; but rewrote to more suitable for haskell languages.

;; Usage:
;; Write these codes to your Emacs init file.
;; (require 'haskell-highlight-indentation)
;; (add-hook 'haskell-mode-hook 'haskell-highlight-indentation-mode)
;;
;; Some configuratition variables exist.
;; Plesae enter
;; M-x customize-group RET haskell-highlight-indentation RET

;;; Code:
(require 'cl-lib)
(defvar haskell-literate)

(defgroup haskell-highlight-indentation nil
  "Highlight indentation by Emacs font-lock system."
  :prefix "haskell-highlight-indentation"
  :prefix "hhi"
  :group 'haskell)

(defvar haskell-highlight-indentation-face 'haskell-highlight-indentation-face)
(defface haskell-highlight-indentation-face
  '((t (:inherit fringe)))
  "Face for highlight indentations"
  :group 'haskell-highlight-indentation
  :group 'haskell-faces)

(defcustom haskell-highlight-indentation-style 'indent
  "Set the select indentation style.

There are 4 indentation styles.

* previous indentation

Recomended

* previous indentation (speed priority)

This mode does not exceed ride a comment.

* column count

Highlight each `haskell-highlight-indentation-column' columns

* column count (only last)

Like above column count style, but nearest one is highlighted."
  :type '(choice (const :tag "By previous indentation levels" indent)
                 (const :tag "By previous indentation levels (speed priority)" indent-fast)
                 (const :tag "By column count" column)
                 (const :tag "By column count (only last)" column-only-last))
  :group 'haskell-highlight-indentation)

(defcustom haskell-highlight-indentation-column 4
  "This value uses for `haskell-highlight-indentation-style' column count."
  :type 'integer
  :group 'haskell-highlight-indentation)

(defun hhi--by-column-count-only-last (offset &optional prefix max-column remove)
  "Insert indentation style to `font-lock-keywords' for column count only last.

OFFSET
PREFIX
MAX-COLUMN
REMOVE"
  (funcall (if remove
               #'font-lock-remove-keywords
             #'font-lock-add-keywords)
           nil
           `((,(concat (or prefix "^")
                       (regexp-opt (cl-loop for n from 0 to (or max-column 80) by offset
                                            collect (make-string n ?\ )))
                       "\\( \\)")
              (1 'haskell-highlight-indentation-face)))))

(defun hhi--by-column-count (offset &optional prefix max-column remove)
  "Insert indentation style to `font-lock-keywords' for column count.

OFFSET
PREFIX
MAX-COLUMN
REMOVE"
  (funcall (if remove
               #'font-lock-remove-keywords
             #'font-lock-add-keywords)
           nil
           (cl-loop for n from 0 to (or max-column 80) by offset
                    collect `(,(format "%s \\{%d\\}\\( \\)" (or prefix "^") n)
                              (1 'haskell-highlight-indentation-face)))))

(defun hhi--faster-highlight-column-p ()
  ""
  (save-excursion
    (let ((start-column (1- (current-column)))
          (col 0))
      (and (> start-column 1)
           (progn
             (skip-chars-backward " ")
             (bolp))
           (cl-loop until (or (/= 0 (forward-line -1))
                              (<= (setq col (skip-chars-forward " "))
                                  start-column))
                    finally return (= col start-column))))))

(defun hhi--highlight-column-p ()
  ""
  (save-excursion
    (let ((start-column (1- (current-column)))
          (max-comment (- (buffer-size)))
          (col 0))
      (and (> start-column 1)
           (progn
             (skip-chars-backward " ")
             (bolp))
           (cl-loop do (progn
                         (forward-comment max-comment)
                         (beginning-of-line))
                    until (or (bobp)
                              (<= (setq col (skip-chars-forward " "))
                                  start-column))
                    finally return (= col start-column))))))

(defun hhi--literate-highlight-column-p ()
  ""
  (save-excursion
    (let ((max-comment (- (buffer-size)))
          start-column
          col)
      (and (progn
             (setq start-column (1- (- (skip-chars-backward " "))))
             (= ?> (preceding-char)))
           (progn
             (backward-char)
             (bolp))
           (> start-column 2)
           (cl-loop do (progn
                         (beginning-of-line)
                         (forward-comment max-comment)
                         (beginning-of-line))
                    while (= ?> (following-char))
                    do (forward-char)
                    until (<= (setq col (skip-chars-forward " "))
                              start-column)
                    finally return (= col start-column))))))

(defun hhi--literate-haskell-bird-mode-p ()
  "Return nil when buffer is not literate-haskell bird mode."
  (and (eq major-mode 'literate-haskell-mode)
       (boundp 'haskell-literate)
       (eq haskell-literate 'bird)))

(defun hhi--by-indent-levels (&optional remove)
  ""
  (funcall (if remove
               #'font-lock-remove-keywords
             #'font-lock-add-keywords)
           nil
           `((" " 0 (if (,(if (hhi--literate-haskell-bird-mode-p)
                              'hhi--literate-highlight-column-p
                            'hhi--highlight-column-p))
                        'haskell-highlight-indentation-face)))))

(defun hhi--by-indent-levels-fast (&optional remove)
  ""
  (funcall (if remove
               #'font-lock-remove-keywords
             #'font-lock-add-keywords)
           nil
           `((" " 0 (if (,(if (hhi--literate-haskell-bird-mode-p)
                              'hhi--literate-highlight-column-p
                            'hhi--faster-highlight-column-p))
                        'haskell-highlight-indentation-face)))))


(defun haskell-highlight-indentation (&optional remove)
  "A highlight indentation keyword add to `font-lock-keywords'.

When REMOVE is t, remove the keyword from `font-lock-keywords'"
  (pcase haskell-highlight-indentation-style
    (`indent
     (hhi--by-indent-levels remove))
    (`indent-fast
     (hhi--by-indent-levels-fast remove))
    (`column
     (hhi--by-column-count haskell-highlight-indentation-column
                           (if (hhi--literate-haskell-bird-mode-p)
                               "^> "
                             (concat "^" (make-string haskell-highlight-indentation-column ?\ )))
                           nil
                           remove))
    (`column-only-last
     (hhi--by-column-count-only-last haskell-highlight-indentation-column
                                     (if (hhi--literate-haskell-bird-mode-p)
                                         "^> "
                                       "^")
                                     nil
                                     remove))))
;;;###autoload
(define-minor-mode haskell-highlight-indentation-mode
  "Indentation highlighting for haskell modes.

Some highlighting styles exist.
Please see the `haskell-highlight-indentation-style' document,
or via M-x customize-group RET haskell-highlight-indentation RET"
  nil nil nil
  (haskell-highlight-indentation (not haskell-highlight-indentation-mode))

  (if haskell-highlight-indentation-mode
      (set (make-local-variable 'haskell-highlight-indentation-style)
           haskell-highlight-indentation-style)
    (kill-local-variable 'haskell-highlight-indentation-style))

  (when (called-interactively-p 'interactive)
    (font-lock-fontify-buffer)))

;; (add-hook 'haskell-mode-hook 'haskell-highlight-indentation-mode)
;; (remove-hook 'haskell-mode-hook 'haskell-highlight-indentation-mode)

(provide 'haskell-highlight-indentation)
;;; haskell-highlight-indentation.el ends here
