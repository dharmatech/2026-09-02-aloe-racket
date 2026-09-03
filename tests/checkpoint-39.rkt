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
 '(Prod Sym Int))
(check-equal?
 (type->datum (typecheck-source "((x * 2) * 3)" checker-environment))
 '(Prod Sym Int))
(check-equal?
 (type->datum (typecheck-source "(x * y)" checker-environment))
 '(Prod Sym Sym))
(check-equal?
 (type->datum (typecheck-source "((x * 2) * y)" checker-environment))
 '(Prod (Prod Sym Int) Sym))
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

(check-eq? (eval-source "((x * 2) left)" runtime-environment)
           x-value)
(check-equal? (eval-source "((x * 2) right)" runtime-environment)
              2)

(check-eq? (eval-source "(((x * 2) * 3) left)" runtime-environment)
           x-value)
(check-equal? (eval-source "(((x * 2) * 3) right)" runtime-environment)
              6)

(check-eq? (eval-source "((x * y) left)" runtime-environment)
           x-value)
(check-eq? (eval-source "((x * y) right)" runtime-environment)
           y-value)

;; Non-Int multiplication uses the generic nested-product overload.
(check-equal?
 (aloe-value->string
  (eval-source "((x * 2) * y)" runtime-environment))
 "#<Prod left=#<Prod left=#<Sym \"x\"> right=2> right=#<Sym \"y\">>")

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

(check-equal? (eval-source "(((x + 2) + 3) const)"
                           runtime-environment)
              5)
(check-equal?
 (inspect "((((((x + 2) + x) + x) terms) first) right)")
 3)
(check-equal? (eval-source "((((x + 2) + y) terms) len)"
                           runtime-environment)
              2)
