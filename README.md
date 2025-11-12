# eglot-header-line
Add on for Emacs eglot showing breadcrumb information in the header-line.

## Install
Install and hook into relevant modes using:
```emacs-lisp
(use-package eglot-header-line
	:ensure t
	:vc (:url "https://github.com/soerlemans/eglot-header-line")
	:hook
	(c++-mode . eglot-header-line-mode)
	(go-mode. eglot-header-line-mode)
	(python-mode. eglot-header-line-mode))
```

## Demo
![demo.gif](https://github.com/soerlemans/eglot-header-line/raw/refs/heads/main/assets/demo.gif)
