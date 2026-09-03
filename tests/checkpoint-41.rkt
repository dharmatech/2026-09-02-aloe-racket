#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt"
         "../aloe/parse.rkt")

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
        '("(x * 2)"
          "((x * 2) * 3)"
          "((x * 2) * y)"))])
  (check-equal?
   (type->datum (typecheck-source expression checker-environment))
   'Prod))
(check-equal?
 (type->datum (typecheck-source "(x * y)" checker-environment))
 'Math)
(check-equal?
 (type->datum (typecheck-source "(x * x)" checker-environment))
 'Math)
(check-equal?
 (type->datum
  (typecheck-source "((x ^ 2) * (x ^ 3))" checker-environment))
 'Math)

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))
(define x-value (eval-source "x" runtime-environment))
(define y-value (eval-source "y" runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

;; x * 2: coefficient 2 and one symbolic factor.
(check-equal? (eval-source "((x * 2) coeff)" runtime-environment) 2)
(check-equal? (eval-source "(((x * 2) factors) len)"
                           runtime-environment)
              1)
(check-eq? (eval-source "(((x * 2) factors) first)"
                        runtime-environment)
           x-value)

;; Multiplying by another integer changes only the coefficient.
(check-equal? (eval-source "(((x * 2) * 3) coeff)"
                           runtime-environment)
              6)
(check-eq? (eval-source "((((x * 2) * 3) factors) first)"
                        runtime-environment)
           x-value)

;; A different symbolic factor is retained in the flat factor list.
(check-equal? (eval-source "(((x * 2) * y) coeff)"
                           runtime-environment)
              2)
(check-equal? (eval-source "((((x * 2) * y) factors) len)"
                           runtime-environment)
              2)
(check-eq? (eval-source "((((x * 2) * y) factors) first)"
                        runtime-environment)
           y-value)
(check-eq? (eval-source "(((((x * 2) * y) factors) rest) first)"
                        runtime-environment)
           x-value)

;; x * y has unit coefficient and two factors.
(check-equal? (inspect "((x * y) coeff)") 1)
(check-equal? (inspect "(((x * y) factors) len)") 2)
(check-eq? (inspect "(((x * y) factors) first)") x-value)
(check-eq? (inspect "((((x * y) factors) rest) first)") y-value)

;; A repeated factor is replaced by its square in the flat list.
(check-equal? (eval-source "((((x * 2) * x) factors) len)"
                           runtime-environment)
              1)
(check-eq? (inspect "(((((x * 2) * x) factors) first) base)") x-value)
(check-equal? (inspect "(((((x * 2) * x) factors) first) exp)") 2)

;; Direct equal-base products retain the checkpoint-40 Pow rules.
(check-eq? (inspect "((x * x) base)") x-value)
(check-equal? (inspect "((x * x) exp)") 2)
(check-eq? (inspect "(((x ^ 2) * (x ^ 3)) base)") x-value)
(check-equal? (inspect "(((x ^ 2) * (x ^ 3)) exp)") 5)

(define product-text
  (aloe-value->string
   (eval-source "((x * 2) * y)" runtime-environment)))
(check-regexp-match #px"^#<Prod coeff=2 factors=" product-text)
(check-regexp-match #px"x" product-text)
(check-regexp-match #px"y" product-text)

(for ([name
       (in-list '("core.aloe" "sym.aloe" "sum.aloe"
                  "prod.aloe" "pow.aloe"))])
  (check-false
   (regexp-match?
    #px"\\(0[[:space:]]+/[[:space:]]+0\\)"
    (file->string (build-path mpl-directory name)))))
