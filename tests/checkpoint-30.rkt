#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/main.rkt")

(define-runtime-path core-path "../examples/mpl/core.aloe")

(define mpl-setup
  (string-append
   (format "(load ~s)\n" (path->string core-path))
   "(define-class MathBox\n"
   "  (fields (value Math))\n"
   "  (methods))\n"
   "(define x (Sym new \"x\"))\n"
   "(define y (Sym new \"y\"))\n"))

(define checker-environment (make-type-environment))
(void (typecheck-source mpl-setup checker-environment))

(check-equal?
 (type->datum (typecheck-source "(x + 2)" checker-environment))
 'Sum)
(check-equal?
 (type->datum (typecheck-source "(x + y)" checker-environment))
 'Sum)
(check-equal?
 (type->datum
  (typecheck-source "((x + 2) + 3)" checker-environment))
 'Sum)

;; Sum conforms to Math in an expected-type position without erasing its
;; concrete result type at the + sends.
(check-equal?
 (type->datum
  (typecheck-source "(MathBox new (x + 2))" checker-environment))
 'MathBox)
(check-equal?
 (type->datum
  (typecheck-source "(MathBox new (x + y))" checker-environment))
 'MathBox)

(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source "(2 + x)" checker-environment)))

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))

(define x-value (eval-source "x" runtime-environment))
(check-eq?
 (eval-source "((((x + 2) + 3) terms) first)" runtime-environment)
 x-value)
(check-equal?
 (eval-source "(((x + 2) + 3) const)" runtime-environment)
 5)
