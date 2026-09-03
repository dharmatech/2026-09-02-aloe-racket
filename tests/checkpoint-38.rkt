#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt")

(define simple-list
  (aloe-value->string (eval-source "(List of 1 2 3)")))
(check-regexp-match #px"1[[:space:]]+2[[:space:]]+3" simple-list)
(check-false (regexp-match? #rx"\n" simple-list))

(define long-list
  (aloe-value->string
   (eval-source "(List of 1 2 3 4 5 6 7 8 9 10)")))
(check-equal? long-list "#<List 1 2 3 4 5 6 7 8 ...>")

(define-runtime-path core-path "../examples/mpl/core.aloe")
(define runtime-environment (make-top-level-env))
(void
 (eval-source
  (string-append
   (format "(load ~s)\n" (path->string core-path))
   "(define x (Sym new \"x\"))\n"
   "(define y (Sym new \"y\"))\n")
  runtime-environment))

(define sum-text
  (aloe-value->string
   (eval-source "((x + 2) + y)" runtime-environment)))
(check-regexp-match #px"^#<Sum terms=" sum-text)
(check-regexp-match #px"x" sum-text)
(check-regexp-match #px"y" sum-text)
(check-regexp-match #px"const=2>$" sum-text)
(check-false (regexp-match? #rx"\n" sum-text))

(define product-text
  (aloe-value->string
   (eval-source "(x * 2)" runtime-environment)))
(check-regexp-match #px"^#<Prod left=" product-text)
(check-regexp-match #px"x" product-text)
(check-regexp-match #px"right=2>$" product-text)
