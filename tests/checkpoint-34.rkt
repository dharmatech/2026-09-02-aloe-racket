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
   "(define x (Sym new \"x\"))\n"))

(define checker-environment (make-type-environment))
(void (typecheck-source mpl-setup checker-environment))

(for ([expression
       (in-list
        '("((x + 2) + x)"
          "(((x + 2) + x) + x)"
          "((((x + 2) + x) + x) + x)"))])
  (check-equal?
   (type->datum (typecheck-source expression checker-environment))
   'Sum))

(check-equal?
 (type->datum
  (typecheck-source "((x + 2) + 3)" checker-environment))
 'Sum)
(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source "(2 + x)" checker-environment)))

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))
(define x-value (eval-source "x" runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

(check-equal?
 (eval-source "(((x + 2) + 3) const)" runtime-environment)
 5)

(define (check-linear-sum expression coefficient)
  (check-eq?
   (inspect (format "((((~a terms) first) factors) first)" expression))
   x-value)
  (check-equal?
   (inspect (format "(((~a terms) first) coeff)" expression))
   coefficient)
  (check-equal?
   (eval-source
    (format "(~a const)" expression)
    runtime-environment)
   2))

(check-linear-sum "((x + 2) + x)" 2)
(check-linear-sum "(((x + 2) + x) + x)" 3)
(check-linear-sum "((((x + 2) + x) + x) + x)" 4)
