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
 (type->datum (typecheck-source "(x * 2)" checker-environment))
 'Prod)
(check-equal?
 (type->datum (typecheck-source "(x * y)" checker-environment))
 'Math)
(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source "(2 * x)" checker-environment)))

;; Existing sum construction and overloaded collection remain unchanged.
(check-equal?
 (type->datum (typecheck-source "(x + 2)" checker-environment))
 'Sum)
(check-equal?
 (type->datum
  (typecheck-source "((x + 2) + x)" checker-environment))
 'Sum)

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))

(define x-value (eval-source "x" runtime-environment))
(define y-value (eval-source "y" runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

(check-equal? (eval-source "((x * 2) coeff)" runtime-environment)
              2)
(check-eq? (inspect "(((x * 2) factors) first)")
           x-value)
(check-equal? (inspect "(((x * 2) factors) len)") 1)
(check-equal? (inspect "((x * y) coeff)") 1)
(check-eq? (inspect "(((x * y) factors) first)")
           x-value)
(check-eq? (inspect "((((x * y) factors) rest) first)")
           y-value)

(check-equal?
 (eval-source "(((x + 2) + x) const)" runtime-environment)
 2)
