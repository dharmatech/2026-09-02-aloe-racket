#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/parse.rkt"
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
  (typecheck-source "((x + 2) + x)" checker-environment))
 'Math)
(check-equal?
 (type->datum
  (typecheck-source "((x + 2) + 3)" checker-environment))
 'Math)
(check-equal?
 (type->datum (typecheck-source "(x + y)" checker-environment))
 'Sum)
(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source "(2 + x)" checker-environment)))

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

(define x-value (eval-source "x" runtime-environment))
(define y-value (eval-source "y" runtime-environment))

(check-true (eval-source "(x same? x)" runtime-environment))
(check-false (eval-source "(x same? y)" runtime-environment))

(check-equal?
 (inspect "(((x + 2) + 3) const)")
 5)

(check-eq?
 (inspect "((((((x + 2) + x) terms) first) factors) first)")
 x-value)
(check-equal?
 (inspect "(((((x + 2) + x) terms) first) coeff)")
 2)
(check-equal?
 (inspect "(((x + 2) + x) const)")
 2)

(check-eq? (eval-source "(((x + y) terms) first)" runtime-environment)
           x-value)
(check-eq? (eval-source "((((x + y) terms) rest) first)"
                        runtime-environment)
           y-value)
