#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/parse.rkt"
         "../aloe/main.rkt")

(define-runtime-path mpl-directory "../examples/mpl")
(define core-path (build-path mpl-directory "core.aloe"))

(define mpl-setup
  (string-append
   (format "(load ~s)\n" (path->string core-path))
   "(define x (Sym new \"x\"))\n"
   "(define y (Sym new \"y\"))\n"))

(define checker-environment (make-type-environment))
(void (typecheck-source mpl-setup checker-environment))

(for ([expression
       (in-list
        '("(x + 2)"
          "(x + y)"
          "((x + 2) + 3)"
          "((x + 2) + x)"
          "((x + 2) + y)"
          "(((x + 2) + x) + x)"))])
  (check-equal?
   (type->datum (typecheck-source expression checker-environment))
   'Sum))

(check-exn
 exn:fail:aloe-type?
 (lambda () (typecheck-source "(2 + x)" checker-environment)))

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))
(define x-value (eval-source "x" runtime-environment))
(define y-value (eval-source "y" runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

;; x + 2: one x term and constant 2.
(check-equal? (eval-source "(((x + 2) terms) len)" runtime-environment) 1)
(check-eq? (eval-source "(((x + 2) terms) first)" runtime-environment)
           x-value)
(check-equal? (eval-source "((x + 2) const)" runtime-environment) 2)

;; x + y: two symbolic terms and no constant.
(check-equal? (eval-source "(((x + y) terms) len)" runtime-environment) 2)
(check-eq? (eval-source "(((x + y) terms) first)" runtime-environment)
           x-value)
(check-eq? (eval-source "((((x + y) terms) rest) first)"
                        runtime-environment)
           y-value)
(check-equal? (eval-source "((x + y) const)" runtime-environment) 0)

;; Adding an Int changes only the constant.
(check-eq? (eval-source "((((x + 2) + 3) terms) first)"
                        runtime-environment)
           x-value)
(check-equal? (eval-source "(((x + 2) + 3) const)"
                           runtime-environment)
              5)

;; A matching x is collected into one Prod term.
(check-equal? (eval-source "((((x + 2) + x) terms) len)"
                           runtime-environment)
              1)
(check-eq? (inspect "((((((x + 2) + x) terms) first) factors) first)")
           x-value)
(check-equal? (inspect "(((((x + 2) + x) terms) first) coeff)")
              2)
(check-equal? (eval-source "(((x + 2) + x) const)"
                           runtime-environment)
              2)

;; A nonmatching y is retained as a separate term; it is never turned into 2x.
(check-equal? (eval-source "((((x + 2) + y) terms) len)"
                           runtime-environment)
              2)
(check-eq? (eval-source "((((x + 2) + y) terms) first)"
                        runtime-environment)
           y-value)
(check-eq? (eval-source "(((((x + 2) + y) terms) rest) first)"
                        runtime-environment)
           x-value)
(check-equal? (eval-source "(((x + 2) + y) const)"
                           runtime-environment)
              2)

;; Repeated matching increments the existing coefficient.
(check-equal?
 (inspect "((((((x + 2) + x) + x) terms) first) coeff)")
 3)
(check-equal?
 (eval-source "((((x + 2) + x) + x) const)" runtime-environment)
 2)

(for ([name (in-list '("core.aloe" "sym.aloe" "sum.aloe" "prod.aloe"))])
  (check-false
   (regexp-match?
    #px"\\(0[[:space:]]+/[[:space:]]+0\\)"
    (file->string (build-path mpl-directory name)))))
