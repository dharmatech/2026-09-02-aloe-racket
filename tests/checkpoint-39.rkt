#lang racket/base

(require racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt"
         "../aloe/parse.rkt")

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
 (type->datum (typecheck-source "((x * 2) * 3)" checker-environment))
 'Prod)
(check-equal?
 (type->datum (typecheck-source "(x * y)" checker-environment))
 'Math)
(check-equal?
 (type->datum (typecheck-source "((x * 2) * y)" checker-environment))
 'Prod)
(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source "(2 * x)" checker-environment)))

;; Sum behavior remains independent of product combination.
(for ([expression
       (in-list
        '("(x + 2)"
          "((x + 2) + 3)"
          "((x + 2) + x)"
          "(((x + 2) + x) + x)"
          "((x + 2) + y)"))])
  (check-equal?
   (type->datum (typecheck-source expression checker-environment))
   'Sum))

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))
(define x-value (eval-source "x" runtime-environment))
(define y-value (eval-source "y" runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

(check-equal? (eval-source "((x * 2) coeff)" runtime-environment)
              2)
(check-eq? (eval-source "(((x * 2) factors) first)" runtime-environment)
           x-value)

(check-equal? (eval-source "(((x * 2) * 3) coeff)" runtime-environment)
              6)
(check-eq? (eval-source "((((x * 2) * 3) factors) first)"
                        runtime-environment)
           x-value)

(check-equal? (inspect "((x * y) coeff)") 1)
(check-eq? (inspect "(((x * y) factors) first)")
           x-value)
(check-eq? (inspect "((((x * y) factors) rest) first)")
           y-value)

;; Nonmatching factors stay in the same flat product.
(check-equal?
 (aloe-value->string
  (eval-source "((x * 2) * y)" runtime-environment))
 "#<Prod coeff=2 factors=#<List #<Sym \"y\"> #<Sym \"x\">>>")

(check-equal? (eval-source "(((x + 2) + 3) const)"
                           runtime-environment)
              5)
(check-equal?
 (inspect "((((((x + 2) + x) + x) terms) first) coeff)")
 3)
(check-equal? (eval-source "((((x + 2) + y) terms) len)"
                           runtime-environment)
              2)
