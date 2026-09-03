#lang racket/base

(require rackunit
         "../aloe/main.rkt")

(define mpl-source
  (string-append
   "(load \"examples/mpl/core.aloe\")\n"
   "(define x (Sym new \"x\"))\n"
   "(define x-plus-two (x + 2))\n"
   "(define combined (x-plus-two + 3))\n"
   "(define x-plus-zero (x + 0))"))

(define checker-environment (make-type-environment))
(void (typecheck-source mpl-source checker-environment))
(check-equal?
 (type->datum (typecheck-source "combined" checker-environment))
 '(Sum Sym Int))
(check-equal?
 (type->datum (typecheck-source "x-plus-zero" checker-environment))
 '(Sum Sym Int))

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-source runtime-environment))
(define x-value (eval-source "x" runtime-environment))

(check-eq? (eval-source "(combined left)" runtime-environment)
           x-value)
(check-equal? (eval-source "(combined right)" runtime-environment) 5)

;; Adding zero still allocates and returns a Sum, with x and 0 as fields.
(check-eq? (eval-source "(x-plus-zero left)" runtime-environment)
           x-value)
(check-equal? (eval-source "(x-plus-zero right)" runtime-environment) 0)

(check-exn
 exn:fail?
 (lambda () (eval-source "(2 + x)" runtime-environment)))
