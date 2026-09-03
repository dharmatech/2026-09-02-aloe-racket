#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/main.rkt")

(define-runtime-path core-path "../examples/mpl/core.aloe")

(define mpl-setup
  (string-append
   (format "(load ~s)\n" (path->string core-path))
   "(define x (Sym new \"x\"))\n"
   "(define y (Sym new \"y\"))\n"))

(define checker-environment (make-type-environment))
(void (typecheck-source mpl-setup checker-environment))

(check-equal?
 (type->datum
  (typecheck-source "((x + 2) plus x)" checker-environment))
 '(Sum (Prod Sym Int) Int))
(check-equal?
 (type->datum
  (typecheck-source "((x + 2) + 3)" checker-environment))
 '(Sum Sym Int))
(check-equal?
 (type->datum (typecheck-source "(x + y)" checker-environment))
 '(Sum Sym Sym))
(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source "(2 + x)" checker-environment)))

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))

(define x-value (eval-source "x" runtime-environment))
(define y-value (eval-source "y" runtime-environment))

(check-true (eval-source "(x same? x)" runtime-environment))
(check-false (eval-source "(x same? y)" runtime-environment))

(check-equal?
 (eval-source "(((x + 2) + 3) right)" runtime-environment)
 5)

(check-eq?
 (eval-source "((((x + 2) plus x) left) left)" runtime-environment)
 x-value)
(check-equal?
 (eval-source "((((x + 2) plus x) left) right)" runtime-environment)
 2)
(check-equal?
 (eval-source "(((x + 2) plus x) right)" runtime-environment)
 2)

(check-eq? (eval-source "((x + y) left)" runtime-environment)
           x-value)
(check-eq? (eval-source "((x + y) right)" runtime-environment)
           y-value)
