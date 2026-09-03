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

(check-equal?
 (type->datum (typecheck-source "(x ^ 2)" checker-environment))
 'Pow)
(check-equal?
 (type->datum (typecheck-source "(x * x)" checker-environment))
 'Math)
(check-equal?
 (type->datum
  (typecheck-source "((x ^ 2) * (x ^ 3))" checker-environment))
 'Math)
(check-equal?
 (type->datum (typecheck-source "(x ^ 0)" checker-environment))
 'Pow)
(check-equal?
 (type->datum (typecheck-source "(x * 2)" checker-environment))
 'Prod)
(check-equal?
 (type->datum (typecheck-source "((x + 2) + x)" checker-environment))
 'Sum)

(define runtime-environment (make-top-level-env))
(void (eval-source mpl-setup runtime-environment))
(define x-value (eval-source "x" runtime-environment))

(define (inspect source)
  (eval-expr (car (read-program source)) runtime-environment))

(check-eq? (eval-source "((x ^ 2) base)" runtime-environment) x-value)
(check-equal? (eval-source "((x ^ 2) exp)" runtime-environment) 2)

(check-eq? (inspect "((x * x) base)") x-value)
(check-equal? (inspect "((x * x) exp)") 2)

(check-eq? (inspect "(((x ^ 2) * (x ^ 3)) base)") x-value)
(check-equal? (inspect "(((x ^ 2) * (x ^ 3)) exp)") 5)

;; Exponent zero remains represented, not collapsed through an untyped 1.
(check-eq? (eval-source "((x ^ 0) base)" runtime-environment) x-value)
(check-equal? (eval-source "((x ^ 0) exp)" runtime-environment) 0)

;; Different bases remain a nested product rather than being flattened.
(check-regexp-match
 #px"^#<Prod coeff=1 factors=#<List #<Pow "
 (aloe-value->string
  (eval-source "((x ^ 2) * (y ^ 3))" runtime-environment)))

(check-equal? (eval-source "((x * 2) coeff)" runtime-environment) 2)
(check-eq? (eval-source "(((x * 2) factors) first)"
                        runtime-environment)
           x-value)
(check-equal? (eval-source "(((x + 2) + x) const)"
                           runtime-environment)
              2)

(for ([name
       (in-list '("core.aloe" "sym.aloe" "sum.aloe"
                  "prod.aloe" "pow.aloe"))])
  (check-false
   (regexp-match?
    #px"\\(0[[:space:]]+/[[:space:]]+0\\)"
    (file->string (build-path mpl-directory name)))))
