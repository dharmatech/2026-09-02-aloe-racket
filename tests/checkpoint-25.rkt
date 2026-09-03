#lang racket/base

(require rackunit
         "../aloe/main.rkt")

(define mpl-source
  (string-append
   "(load \"examples/mpl/core.aloe\")\n"
   "(define x (Sym new \"x\"))\n"
   "(define y (Sym new \"y\"))\n"
   "(define x-plus-two (x + 2))\n"
   "(define x-plus-y (x + y))"))

(define checker-environment (make-type-environment))
(void (typecheck-source mpl-source checker-environment))
(check-equal?
 (type->datum (typecheck-source "x-plus-two" checker-environment))
 '(Sum Sym Int))
(check-equal?
 (type->datum (typecheck-source "x-plus-y" checker-environment))
 '(Sum Sym Sym))

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-source runtime-environment))

(define x-value (eval-source "x" runtime-environment))
(define y-value (eval-source "y" runtime-environment))
(check-eq? (eval-source "(x-plus-two left)" runtime-environment)
           x-value)
(check-equal? (eval-source "(x-plus-two right)" runtime-environment) 2)
(check-eq? (eval-source "(x-plus-y left)" runtime-environment)
           x-value)
(check-eq? (eval-source "(x-plus-y right)" runtime-environment)
           y-value)
(check-equal? (eval-source "(x name)" runtime-environment) "x")

(check-exn
 exn:fail?
 (lambda () (eval-source "(2 + x)" runtime-environment)))
