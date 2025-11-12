;;; eglot-header-line.el --- Major mode for the Crow programming language.
;; -*- coding: utf-8; lexical-binding: t -*-

;; Copyright (C) 2025  soerlemans

;; Author: soerlemans <https://github.com/soerlemans>
;; Keywords: languages crow
;; URL: https://github.com/soerlemans/eglot-header-line
;;
;; This file is not part of GNU Emacs.

;; MIT License
;;
;; Copyright (c) 2025 soerlemans
;;
;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Commentary:

;; TODO: Write Commentary


;;; Code:
(dolist (pkg '(eglot jsonrpc cl-lib))
	(require pkg))

;;; Variables:
(defvar-local eglot-header-line--segment '(:eval (eglot-header-line--breadcrumb))
  "Eglot header-line segment.")

(defvar eglot-header-line--mode-separators
  '((c++-mode . "::")
    (rust-mode . "::")
    (go-mode . ".")
		(python-mode . "."))
  "Alist mapping major modes to header-line entity separators.")

;;; Functions:
;; Symbol kind specification as of writing.
;; See symbol kind at:
;; https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_documentSymbol).
;;
;; export namespace SymbolKind {
;;   export const File = 1;
;;	 export const Module = 2;
;;	 export const Namespace = 3;
;;	 export const Package = 4;
;;	 export const Class = 5;
;;	 export const Method = 6;
;;	 export const Property = 7;
;;	 export const Field = 8;
;;	 export const Constructor = 9;
;;	 export const Enum = 10;
;;	 export const Interface = 11;
;;	 export const Function = 12;
;;	 export const Variable = 13;
;;	 export const Constant = 14;
;;	 export const String = 15;
;;	 export const Number = 16;
;;	 export const Boolean = 17;
;;	 export const Array = 18;
;;	 export const Object = 19;
;;	 export const Key = 20;
;;	 export const Null = 21;
;;	 export const EnumMember = 22;
;;	 export const Struct = 23;
;;	 export const Event = 24;
;;	 export const Operator = 25;
;;	 export const TypeParameter = 26;|
;; }
(defun eglot-header-line--symbol-kind-to-face (kind)
	"Match a given symbol kind to a font lock face."
	(pcase kind
		(3  'font-lock-constant-face)
		(5  'font-lock-type-face)
		(6  'font-lock-function-name-face)
		(10 'font-lock-type-face)
		(11 'font-lock-type-face)
		(12 'font-lock-function-name-face)
		(23 'font-lock-type-face)

		;; (t 'font-lock-keyword-face) ; Default
		(_ 'default) ; Default
		))

(defun eglot-header-line--swap-face (face)
  "Return a face spec like FACE but with foreground and background swapped."
  (let ((fg (face-foreground face nil 'default))
        (bg (face-background face nil 'default))
				(bold (face-bold-p face)))
    `(:foreground ,bg :background ,fg, :weight ,bold)
		))

(defun eglot-header-line--propertize (str kind)
	"Utility function for fixing the FACE and properly propertizing a string."
	(let* ((face (eglot-header-line--symbol-kind-to-face kind))
				 (hl-face (eglot-header-line--swap-face face)))
		(propertize str 'face hl-face)
		))

(defun eglot-header-line--separator-for-current-mode ()
  "Return the separator string for the current major mode."
  (or (cdr (assoc major-mode eglot-header-line--mode-separators))
			"." ;; Default separator if not found.
			))

(defun eglot-header-line--documentSymbol ()
  "Return the list of symbols from the current buffer via Eglot."
	(let ((server (eglot--current-server-or-lose)))
		(eglot--request
		 server
		 "textDocument/documentSymbol"
		 `(:textDocument ,(eglot--TextDocumentIdentifier)))
		))


(defun eglot-header-line--symbol-at-point (symbols)
	"Return list of symbol names containing point, using SYMBOLS tree."
	(let (path '())
		(cl-labels
				((walk (symbols-inner)
					 (mapc (lambda (symbol)
									 (let* ((range (plist-get symbol :range))
													(start (eglot--lsp-position-to-point (plist-get range :start)))
													(end   (eglot--lsp-position-to-point (plist-get range :end)))
													(name (plist-get symbol :name))
													(children (plist-get symbol :children))
													(kind (plist-get symbol :kind)))
										 (when (and (>= (point) start) (<= (point) end))
											 ;; Add the symbols name if our point is between its start and end.
											 (let* ((face (eglot-header-line--symbol-kind-to-face kind))
															(name-prop (eglot-header-line--propertize name kind))
															(sep (eglot-header-line--separator-for-current-mode))
															(sep-prop (eglot-header-line--propertize sep t))
															(detail-spacer-prop (propertize " " 'display '(space :width 0.65))))

												 ;; Necessary to only separators spacers inbetween items.
												 (when path
													 (push sep-prop path))

												 (push name-prop path)
												 (if children
														 (walk children) ; True.
													 (when-let* ((detail (plist-get symbol :detail)) ; False.
																			 (detail-prop (eglot-header-line--propertize detail t)))
														 (push detail-spacer-prop path)
														 (push "|" path)
														 (push detail-spacer-prop path)
														 (push detail-prop path))
													 )))
										 ))
								 symbols-inner)))
			(walk symbols))
		(nreverse path)
		))

(defun eglot-header-line--breadcrumb ()
	"Compute the breadcrumb for the current context, of POINT."
	(when-let ((symbols (eglot-header-line--documentSymbol)))
		(let* ((path (eglot-header-line--symbol-at-point symbols))
					 (spacer-prop (propertize " " 'display '(space :width 1.3))))
			(list spacer-prop path spacer-prop) ;; We add spacers around it to make it look better.
			)))

(defun eglot-header-line--add-segment ()
  "Add eglot header-line segment if it's not already present."
  (unless (member eglot-header-line--segment header-line-format)
    (setq header-line-format
          (append (list eglot-header-line--segment)
                  (if (listp header-line-format)
                      header-line-format
                    (list header-line-format))))))

(defun eglot-header-line--remove-segment ()
  "Remove eglot header-line segment if present."
  (setq header-line-format
        (delq eglot-header-line--segment header-line-format)))

;;; Define minor mode:
(define-minor-mode eglot-header-line-mode
	"Toggle the highlighting of the current namespace/class/function in the headerline."
	:lighter "Toggle the highlighting of the current function in the header-line."
  :init-value nil
	(if eglot-header-line-mode
			(eglot-header-line-enable)
		(eglot-header-line-disable)
		))

(defun eglot-header-line-enable ()
	"Enable the eglot headerline."
	(interactive)
  (unless eglot-header-line-mode
		(eglot-header-line--add-segment)

		;; Invert default header-line look.
		;; Headerline foreground and background are default inverted.
		(let ((fg (face-foreground 'default))
					(bg (face-background 'default)))
			(set-face-attribute 'header-line nil
													:foreground bg
													:background fg
													:height 1.0
													:box  `(:line-width 1 :color ,fg :style nil)
													))

		(setq eglot-header-line-mode t)
		))

(defun eglot-header-line-disable ()
	"Disable the eglot headerline."
	(interactive)
  (when eglot-header-line-mode
		(eglot-header-line--remove-segment)

		;; Neatly reset the face.
		(set-face-attribute 'header-line nil
												:foreground 'unspecified
												:background 'unspecified
												:weight 'unspecified
												:box 'unspecified
												:underline 'unspecified
												:slant 'unspecified
												:height 'unspecified
												:font 'unspecified)

		(setq eglot-header-line-mode nil)
		))


(provide 'eglot-header-line-mode)
;;; eglot-header-line.el ends here
